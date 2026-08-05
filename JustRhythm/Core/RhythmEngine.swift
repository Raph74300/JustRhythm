import Foundation
import Observation
import UIKit

struct Hit: Identifiable {
    let id = UUID()
    let time: Double        // instant retenu, en secondes host
    let delta: Double       // écart signé : < 0 en avance, > 0 en retard
}

struct Beat: Identifiable {
    let id = UUID()
    let time: Double
    let isMain: Bool        // sur le temps, par opposition à une subdivision
}

/// Où tombent réellement les dernières notes : un centre et une largeur.
///
/// Les deux ensemble, jamais le centre seul. Des écarts en avance et en
/// retard s'annulent dans une moyenne : un jeu dispersé mais centré affiche
/// la même moyenne qu'un jeu propre. Seule la dispersion les distingue.
/// (EX-066 / EX-089)
struct Placement: Equatable {
    /// Centre de la fourchette, en secondes. Négatif en avance.
    let mean: Double
    /// Demi-largeur de la fourchette, en secondes.
    let deviation: Double

    /// Vrai quand toute la fourchette tient dans la zone juste — et pas
    /// seulement son centre.
    func isWithin(_ tolerance: Double) -> Bool {
        abs(mean) + deviation <= tolerance
    }
}

struct Stats {
    /// Notes jouées depuis le début de la séance. (EX-080)
    ///
    /// Distincte de `count` : les trois indicateurs qui suivent ne portent que
    /// sur la fenêtre glissante (EX-084), alors que ce total, lui, ne cesse de
    /// monter. Les confondre bloquait le compteur dès la fenêtre atteinte.
    var played = 0
    /// Notes réellement retenues pour le bilan, plafonnées à la fenêtre.
    var count = 0
    var mean = 0.0          // secondes
    var sd = 0.0            // secondes
    var inZone = 0.0        // pourcentage
}

/// Ce que l'application a à dire pendant qu'on joue. (EX-135)
///
/// Deux niveaux de lecture, et c'est tout l'intérêt : le résumé tient sur une
/// ligne et se lit sans quitter le clavier des yeux, le paragraphe attend
/// derrière un appui. Les explications d'origine étaient écrites longues à
/// dessein — celle de l'horloge manquante désigne un réglage qui se trouve sur
/// l'instrument, pas dans l'application, et la phrase entière est ce qui évite
/// une demi-heure de recherche au mauvais endroit. Affichées d'un bloc en bas
/// de l'écran de mesure, elles se faisaient couper à la première ligne : tout
/// ce qui justifiait leur longueur disparaissait, et il ne restait qu'un début
/// de phrase suivi de points de suspension.
struct EngineMessage: Equatable {

    /// Deux niveaux suffisent. La distinction est portée par la forme de
    /// l'icône, jamais par sa seule couleur. (EX-117)
    enum Severity {
        case info
        case warning

        var icon: String {
            switch self {
            case .info: "info.circle"
            case .warning: "exclamationmark.triangle"
            }
        }
    }

    let severity: Severity
    /// Une ligne. Doit se suffire à lui-même : c'est le seul état visible tant
    /// qu'on ne déplie pas.
    let summary: String
    /// Ce qu'il faut faire, ou pourquoi c'est arrivé. `nil` quand le résumé dit
    /// déjà tout — on n'affiche alors aucun chevron.
    var detail: String? = nil

    static func info(_ summary: String, detail: String? = nil) -> EngineMessage {
        EngineMessage(severity: .info, summary: summary, detail: detail)
    }

    static func warning(_ summary: String, detail: String? = nil) -> EngineMessage {
        EngineMessage(severity: .warning, summary: summary, detail: detail)
    }
}

@Observable
final class RhythmEngine {

    let settings = Settings()
    let midi = MIDIManager()
    private let metronome = MetronomeEngine()

    // — État observable —
    private(set) var running = false
    private(set) var hits: [Hit] = []
    private(set) var beats: [Beat] = []
    private(set) var stats = Stats()
    private(set) var lastDelta: Double?
    private(set) var outputLatency: Double = 0
    var message: EngineMessage?

    /// Vrai quand le métronome a été déclenché par le clavier. (EX-053)
    private(set) var externallyTriggered = false
    /// Tempo lu sur l'horloge MIDI, nil tant qu'elle n'est pas exploitable.
    private(set) var clockBpm: Double?

    // — Grille —
    // anchor/period/stepIndex/nextStep sont écrits depuis `queue` (schedule,
    // followClock) et lus depuis la queue principale (nearestStep, appelée
    // par handle() à chaque note) : sans ce verrou, les deux se recouvrent et
    // nearestStep peut lire un anchor déjà à jour avec un period encore
    // ancien, ce qui produit un écart incohérent, différent à chaque fois.
    private let gridLock = NSLock()
    private var anchor: Double = 0
    private var period: Double = 0.75
    private var stepIndex = 0
    private var nextStep: Double = 0

    /// Numéro de pas de grille auquel correspond `anchor`, compté depuis le
    /// départ de la séance. (EX-042)
    ///
    /// `stepIndex` ne peut pas porter la position musicale : le suivi d'horloge
    /// le remet à zéro à chaque noire reçue, pour que le bruit de mesure ne soit
    /// pas amplifié par sa croissance. Il mesure donc un écart à l'ancre, pas un
    /// rang dans la mesure. Les confondre faisait disparaître les temps forts
    /// dès que la synchro était active : `stepIndex` ne dépassait jamais deux ou
    /// trois entre deux corrections, et ne tombait donc jamais sur un multiple
    /// du nombre de pas par mesure.
    private var anchorStep = 0
    /// Position absolue dans la grille : c'est elle qui dit le temps fort.
    private var gridPosition: Int { anchorStep + stepIndex }

    /// Instant du dernier pas réellement émis, pour ne pas le réémettre.
    ///
    /// Le planificateur travaille 200 ms d'avance. Un recalage d'horloge qui
    /// repartirait du seul instant courant réémettrait donc tout ce que ces
    /// 200 ms contenaient déjà — c'est le doublon.
    private var scheduledThrough: Double = -1

    /// Noires reçues depuis le message Start, pour situer l'ancre dans la
    /// mesure. Le Start signifie « depuis le début » : il donne donc le premier
    /// temps, et tout se compte à partir de là.
    private var beatsSinceStart = 0

    private var deltas: [Double] = []
    /// Compté à part : `deltas` est plafonné par la fenêtre glissante et ne
    /// peut donc pas servir à savoir combien de notes ont été jouées.
    private var notesPlayed = 0
    private var timer: DispatchSourceTimer?

    // — Suivi de l'horloge MIDI (EX-054) —
    /// Au-delà de cet écart relatif, un intervalle n'est plus de la gigue mais
    /// un tempo qu'on vient de changer sur le clavier. Le seuil laisse passer
    /// largement la gigue du transport — de l'ordre du pour cent — et la perte
    /// d'une impulsion d'horloge, qui allonge un temps de 1/24, soit 4,2 %.
    private static let tempoJumpRatio = 0.08
    /// Distingue deux départs successifs, pour qu'une vérification d'horloge
    /// lancée par le premier ne parle pas au nom du second.
    private var clockWatchToken: UInt64 = 0
    private var lastBeatTime: Double?
    private var smoothedBeat: Double?
    private let queue = DispatchQueue(label: "fr.justrhythm.scheduler", qos: .userInteractive)

    init() {
        midi.onNote = { [weak self] time, note, velocity, channel in
            self?.handle(time: time, note: note, velocity: velocity, channel: channel)
        }
        // Relâchement et pédale ne concernent que le module sonore : ils ne
        // touchent ni les statistiques ni le graphe. (EX-133)
        midi.onNoteOff = { [weak self] note, channel in
            guard let self, self.listens(to: channel) else { return }
            DispatchQueue.main.async {
                // Sans condition sur les réglages, des deux côtés : une note
                // lancée doit être relâchée même si l'on coupe entre l'appui et
                // le lever. (EX-130 / EX-131 / EX-134)
                self.releaseVoicedNote(note)
            }
        }
        midi.onController = { [weak self] controller, value, channel in
            guard let self, controller == 64, self.listens(to: channel) else { return }
            DispatchQueue.main.async {
                guard self.settings.instrumentEnabled else { return }
                self.metronome.instrumentSustain(value >= 64)
            }
        }
        midi.onSourceLost = { [weak self] _ in
            guard let self else { return }
            self.stop()
            self.resetStats()
            self.beats.removeAll()
            self.message = nil
        }
        midi.onTransport = { [weak self] time, message in
            DispatchQueue.main.async { self?.handleTransport(time: time, message: message) }
        }
        metronome.onInterruption = { [weak self] resumed in
            guard let self else { return }
            if resumed {
                self.message = .info(String(localized: "Session resumed after an interruption."))
            } else {
                // Après `stop()`, qui efface : sinon le message serait emporté
                // par la remise à zéro qu'il est justement là pour expliquer.
                self.stop()
                self.message = .warning(String(localized: "Session interrupted by the system."))
            }
        }
        // Posée avant l'ouverture du client : le premier balayage retrouve
        // ainsi le clavier directement, sans repli transitoire. (EX-013)
        midi.preferredID = settings.lastSourceID
        midi.start()
        // Le niveau vit dans l'état partagé du moteur audio, qui survit aux
        // démarrages et aux arrêts : le poser une fois ici suffit. (EX-137)
        instrumentVolumeChanged()
    }

    /// Période réelle de la grille, en secondes.
    ///
    /// Tant que l'horloge du clavier est reçue, c'est elle qui fait foi —
    /// `settings.bpm` la recopie (voir `adoptClockTempo`) mais arrondie, donc
    /// on part de la valeur non arrondie. Tout ce qui s'exprime « par rapport
    /// à la subdivision » passe par ici, pour que la zone juste et l'échelle
    /// du graphe suivent la grille réellement en vigueur.
    var gridPeriod: Double {
        if let clockBpm { return 60.0 / clockBpm / Double(settings.subdivision.rawValue) }
        return settings.stepPeriod
    }

    var tolerance: Double {
        Tolerance.limit(percent: settings.tolerancePercent, step: gridPeriod)
    }

    /// Durée d'un temps, en secondes. C'est la largeur du graphe. (EX-067)
    ///
    /// Passe par `gridPeriod`, donc suit l'horloge du clavier quand elle est
    /// reçue — et reste identique quelle que soit la subdivision, puisque
    /// celle-ci divise le temps sans le changer.
    var beatPeriod: Double { gridPeriod * Double(settings.subdivision.rawValue) }

    /// Correction d'entrée réellement appliquée. (EX-035)
    ///
    /// Deux valeurs, choisies par l'application et non par l'utilisateur. Quand
    /// l'instrument transmet son horloge, ses messages temps réel passent devant
    /// les notes dans sa file de sortie : les frappes sortent plus tard, et la
    /// chaîne d'entrée est réellement plus longue. Sur un CVP-303 l'écart mesuré
    /// est d'une quinzaine de millisecondes — assez pour fausser un bilan, et
    /// bien trop pour qu'on demande à quelqu'un d'y penser à chaque bascule.
    var activeAlignmentMs: Double {
        clockBpm != nil ? settings.syncAlignmentMs : settings.manualAlignmentMs
    }

    /// Laquelle des deux corrections est concernée, pour l'affichage.
    ///
    /// En séance, c'est l'horloge réellement reçue qui décide — comme pour la
    /// correction elle-même. À l'arrêt il n'en arrive aucune, et la condition
    /// resterait donc figée sur « iPhone » alors même qu'on bascule le réglage
    /// de synchro sous ses yeux : on montre alors ce qui *s'appliquera*, à
    /// défaut de ce qui s'applique.
    var alignmentFollowsClock: Bool {
        running ? clockBpm != nil : settings.syncStart
    }


    /// Une surcharge ne se signale qu'une fois par séance : la répéter
    /// noierait le message utile sous sa propre répétition.
    private var overloadReported = false

    /// Au-delà de ce retard entre l'horodatage d'une note et son traitement,
    /// la queue principale n'absorbe plus le flux. (EX-100)
    ///
    /// C'est la sonde qui manquait : une note traitée trop tard garde son
    /// horodatage — la mesure reste juste — mais elle est dessinée à la place
    /// que cet instant lui donne, déjà sortie par le bas du graphe. D'où le
    /// symptôme « le clic continue, le graphe n'affiche plus rien, tout repart
    /// après une pause » : un embouteillage, pas une fuite.
    ///
    /// Le seuil est large : la fenêtre visible la plus courte fait quelques
    /// dixièmes de seconde, et un retard sous 250 ms ne se voit pas.
    private static let lateThreshold = 0.250

    /// Nombre de notes derrière la lecture instantanée. Assez pour que la
    /// variabilité d'une frappe isolée se noie, assez peu pour qu'une
    /// correction du jeu se voie en une ou deux mesures.
    static let readoutWindow = 16

    /// Fourchette glissante des derniers écarts.
    ///
    /// C'est elle qu'on lit en jouant, et non l'écart de la dernière note :
    /// celui-ci saute d'une frappe à l'autre, au point qu'on ne peut rien en
    /// tirer sans s'arrêter de jouer. (EX-066 / EX-089)
    var recentPlacement: Placement? {
        let recent = hits.suffix(Self.readoutWindow).map(\.delta)
        guard !recent.isEmpty else { return nil }
        let mean = recent.reduce(0, +) / Double(recent.count)
        let variance = recent.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(recent.count)
        return Placement(mean: mean, deviation: variance.squareRoot())
    }

    // =====================================================================

    func toggle() { running ? stop() : start() }

    func start() { start(anchoredAt: nil) }

    /// `anchoredAt` cale le premier temps sur un instant imposé de l'extérieur.
    /// C'est tout l'intérêt de la synchronisation : la grille ne démarre pas
    /// « maintenant + un délai de confort » mais exactement sur le départ de
    /// la boîte à rythmes. (EX-053)
    func start(anchoredAt externalStart: Double?) {
        guard !running else { return }
        do {
            try metronome.start()
        } catch {
            message = .warning(String(localized: "Audio unavailable"),
                               detail: error.localizedDescription)
            return
        }
        outputLatency = metronome.outputLatency
        message = outputLatency > 0.060
            ? .warning(String(format: NSLocalizedString("Audio output delayed by %d ms", comment: ""),
                              Int(outputLatency * 1000)),
                       detail: String(localized: "Likely a wireless output, which will skew the average."))
            : nil

        hits.removeAll(); beats.removeAll(); deltas.removeAll()
        lastDelta = nil; stats = Stats(); notesPlayed = 0
        overloadReported = false

        externallyTriggered = externalStart != nil
        gridLock.withLock {
            period = settings.stepPeriod
            anchor = externalStart ?? (HostClock.now + 0.25)
            anchorStep = 0
            stepIndex = 0
            nextStep = anchor
            // Aucun pas émis pour cette séance : la valeur d'avant ne dit plus
            // rien de cette grille-ci.
            scheduledThrough = -1

            // Un départ externe est déjà passé de quelques millisecondes quand on
            // le traite : on avance jusqu'au premier pas encore programmable,
            // sinon le premier clic partirait dans le passé et serait perdu.
            while nextStep < HostClock.now + 0.02 {
                stepIndex += 1
                nextStep = anchor + Double(stepIndex) * period
            }
        }

        running = true
        UIApplication.shared.isIdleTimerDisabled = true    // (EX-090)

        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(20))
        t.setEventHandler { [weak self] in self?.schedule() }
        t.resume()
        timer = t
    }

    func stop() {
        guard running else { return }
        running = false
        externallyTriggered = false
        // Un message décrit la séance en cours et meurt avec elle. (EX-135)
        //
        // Sans cela, l'avertissement d'horloge manquante restait affiché après
        // l'arrêt, puis pendant tout le temps où l'on ne jouait pas, jusqu'au
        // départ suivant : il finissait par décrire une situation révolue, sans
        // que rien ne permette de s'en débarrasser. Les messages posés *après*
        // un arrêt — l'interruption système — ne sont pas concernés, ils sont
        // écrits une fois cette ligne passée.
        message = nil
        lastBeatTime = nil; smoothedBeat = nil; clockBpm = nil
        timer?.cancel(); timer = nil

        // Le moteur audio ne s'arrête que si plus personne n'en a besoin :
        // couper le métronome ne doit pas rendre le clavier muet chez qui
        // joue Local Control désactivé. (EX-133)
        if settings.instrumentEnabled {
            metronome.flushPending()
        } else {
            metronome.stop()
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// Prépare le moteur audio et charge le timbre choisi. (EX-133)
    ///
    /// Appelée au premier besoin plutôt qu'au lancement : ouvrir la session
    /// audio coûte, et l'immense majorité des séances n'active pas le module.
    ///
    /// Elle est donc sur le chemin de **chaque note**, et doit y être quasi
    /// gratuite : les deux appels qu'elle fait ressortent immédiatement quand
    /// l'état est déjà le bon. Le cas courant se réduit à deux comparaisons.
    func prepareInstrument() {
        guard settings.instrumentEnabled else { return }
        if metronome.isRunning {
            metronome.loadInstrument(settings.instrumentVoice)
            return
        }
        do {
            try metronome.start()
            outputLatency = metronome.outputLatency
            metronome.loadInstrument(settings.instrumentVoice)
        } catch {
            message = .warning(String(localized: "Instrument unavailable"),
                               detail: error.localizedDescription)
            settings.instrumentEnabled = false
        }
    }

    /// Reporte le niveau du module sonore sur le moteur audio. (EX-137)
    ///
    /// Un curseur, donc appelée en rafale : elle ne fait qu'écrire un flottant
    /// derrière le verrou de l'état partagé, sans passer par la file
    /// d'événements du synthé, dimensionnée pour des notes.
    func instrumentVolumeChanged() {
        metronome.setInstrumentVolume(Float(settings.instrumentVolume))
    }

    /// Suit la bascule du module sonore depuis les Réglages.
    func instrumentSettingChanged() {
        if settings.instrumentEnabled {
            prepareInstrument()
        } else {
            metronome.instrumentSilence()
            octaveCompanions.removeAll()
            if !running { metronome.stop() }
        }
    }

    /// Note d'essai, pour vérifier le module sans lancer de séance ni jouer.
    /// Un bouton de test par sous-système : c'est ce qui évite les pannes
    /// muettes. (EX-052)
    func testInstrument() {
        prepareInstrument()
        guard settings.instrumentEnabled else { return }
        metronome.instrumentNoteOn(60, velocity: 90)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.metronome.instrumentNoteOff(60)
        }
    }

    /// Réancrage propre au changement de tempo. (EX-048)
    func reanchor() {
        guard running else { return }
        queue.async { [weak self] in
            guard let self else { return }
            self.gridLock.withLock {
                let t = max(HostClock.now + 0.10, self.nextStep)
                self.period = self.settings.stepPeriod
                self.anchor = t
                // Un changement de tempo à la main relance la mesure : sans
                // référence extérieure, aucune raison de préserver un rang.
                self.anchorStep = 0
                self.stepIndex = 0
                self.nextStep = t
            }
        }
    }

    /// Clic isolé, sans démarrer la séance. (EX-052)
    func testClick() {
        do {
            if !metronome.isRunning { try metronome.start() }
            outputLatency = metronome.outputLatency
            message = nil
        } catch {
            message = .warning(String(localized: "Audio unavailable"),
                               detail: error.localizedDescription)
            return
        }
        metronome.playTestClick(voice: settings.clickVoice, volume: Float(settings.clickVolume))
    }

    // =====================================================================

    private func schedule() {
        guard running else { return }
        let horizon = HostClock.now + 0.20
        var scheduled: [Beat] = []

        gridLock.withLock {
            while nextStep < horizon {
                let subdiv = settings.subdivision.rawValue
                let isMain = gridPosition % subdiv == 0

                // Le clic ne sonne que sur les temps : cliquer les subdivisions
                // est en phase 3 (EX-044). La grille, elle, est déjà fine.
                if settings.clickEnabled && isMain {
                    metronome.schedule(at: nextStep,
                                       voice: settings.clickVoice,
                                       volume: Float(settings.clickVolume))
                }
                scheduled.append(Beat(time: nextStep, isMain: isMain))
                scheduledThrough = nextStep
                stepIndex += 1
                nextStep = anchor + Double(stepIndex) * period
            }
        }

        guard !scheduled.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.beats.append(contentsOf: scheduled)
            if self.beats.count > 400 { self.beats.removeFirst(self.beats.count - 400) }
        }
    }

    // =====================================================================
    // Synchronisation sur le clavier
    // =====================================================================

    private func handleTransport(time: Double, message: MIDITransport) {
        switch message {

        case .start, .cont:
            guard settings.syncStart, !running else { return }
            lastBeatTime = nil; smoothedBeat = nil; clockBpm = nil
            start(anchoredAt: time)
            watchForMissingClock()

        case .stop:
            guard settings.syncStart, running, externallyTriggered else { return }
            stop()

        case .clock:
            guard settings.syncStart, running else { return }
            followClock(at: time)
        }
    }

    /// Suivi de l'horloge MIDI.
    ///
    /// On ne recale pas la grille à chaque noire : cela ferait sauter un clic
    /// ou en doublerait un. On corrige deux choses séparément — la période,
    /// lissée pour absorber la gigue du transport, et la phase, par un
    /// décalage borné de l'ancrage. Les deux corrections restent petites tant
    /// que le clavier est stable, et la grille ne subit jamais de rupture.
    private func followClock(at time: Double) {
        // Plus de division ici : `MIDIManager` ne remonte qu'une impulsion sur
        // vingt-quatre, sur son propre thread. Chaque appel est donc déjà une
        // noire — ce qui a supprimé trente-deux traversées par seconde de la
        // queue principale, dont vingt-trois sur vingt-quatre ne servaient qu'à
        // incrémenter un compteur.
        defer { lastBeatTime = time }
        guard let previous = lastBeatTime else { return }

        let interval = time - previous
        // Garde-fou : hors de 20 à 300 bpm, c'est une impulsion perdue ou un
        // sursaut, pas un tempo. On l'ignore plutôt que de suivre du bruit.
        guard interval > 0.2, interval < 3.0 else { return }

        // Un lissage assez fort pour absorber la gigue met une dizaine de temps
        // à rejoindre un tempo qu'on vient de changer au clavier — sept
        // secondes de flottement, période et phase en retard ensemble. Plutôt
        // que d'affaiblir le lissage, ce qui coûterait de la gigue en
        // permanence pour un gain ponctuel, on reconnaît le changement franc et
        // on l'adopte d'un coup.
        let smoothed: Double
        if let previous = smoothedBeat,
           abs(interval - previous) / previous > Self.tempoJumpRatio {
            smoothed = interval
        } else {
            smoothed = smoothedBeat.map { $0 * 0.8 + interval * 0.2 } ?? interval
        }
        smoothedBeat = smoothed
        clockBpm = 60.0 / smoothed
        adoptClockTempo()

        let subdiv = Double(settings.subdivision.rawValue)
        let newPeriod = smoothed / subdiv

        queue.async { [weak self] in
            guard let self, self.running else { return }
            self.gridLock.withLock {
                self.period = newPeriod

                // Correction de phase : écart entre la noire reçue et le point de
                // grille le plus proche, borné à 20 ms.
                let steps = Int(((time - self.anchor) / newPeriod).rounded())
                let expected = self.anchor + Double(steps) * newPeriod
                let error = max(-0.020, min(0.020, time - expected))

                // Réancrage local, stepIndex remis à 0, plutôt que recalculer
                // nextStep = anchor + stepIndex * newPeriod : cette formule
                // multiplie le moindre bruit de mesure par stepIndex, qui ne
                // fait que grandir tout au long de la séance — quelques
                // dixièmes de ms de bruit deviennent un saut énorme après
                // quelques dizaines de secondes. En repartant d'ici à chaque
                // correction, l'erreur ne peut plus être amplifiée par la
                // durée de la séance, seulement par l'écart borné ci-dessus.
                self.anchor = expected + error
                // Le rang du nouvel ancrage suit son déplacement. Sans cette
                // ligne, `anchorStep` restait à zéro toute la séance et
                // `gridPosition` se réduisait à `stepIndex`, remis à zéro à
                // chaque noire reçue — exactement le défaut que ce champ avait
                // été introduit pour corriger, à ceci près qu'il n'était pas
                // tenu. Invisible en régime établi, où l'ancre avance
                // d'exactement une subdivision et où le compte reste un multiple
                // de la subdivision par accident. Il se voit dès que ce n'est
                // plus le cas : un tempo changé au clavier fait sauter l'ancre
                // d'un nombre quelconque de pas, et le temps fort — donc aussi
                // le clic, qui ne sonne que sur lui — tombe alors à côté.
                self.anchorStep += steps
                self.stepIndex = 0
                self.nextStep = self.anchor

                // Le rattrapage repart de ce qui a déjà été émis, et non du seul
                // instant courant.
                //
                // C'était le doublon : le planificateur programme 200 ms
                // d'avance, ne remonter que jusqu'à « maintenant + 20 ms »
                // réémettait donc tout ce que ces 180 ms contenaient — un pas
                // par noire reçue, mesuré à sept doublons en six secondes. À
                // l'écran, deux lignes de subdivision à quelques millisecondes
                // l'une de l'autre ; à l'oreille, un clic double sur les temps
                // forts, qui passe inaperçu quand le clic est coupé.
                //
                // La demi-période de marge absorbe la correction de phase,
                // bornée à 20 ms : un pas replacé de quelques millisecondes
                // reste le même pas, pas un nouveau.
                let dejaEmis = self.scheduledThrough + newPeriod / 2
                let plancher = max(HostClock.now + 0.02, dejaEmis)
                while self.nextStep < plancher {
                    self.stepIndex += 1
                    self.nextStep = self.anchor + Double(self.stepIndex) * newPeriod
                }
            }
        }
    }

    /// Vérifie qu'une horloge suit bien le message Start. (EX-053 / EX-054)
    ///
    /// Le Start donne l'instant du départ, jamais le tempo — c'est écrit dans
    /// le protocole et tranché de longue date ici. Reste que sans horloge
    /// derrière, l'application part pile au bon moment puis continue **à son
    /// propre tempo**, et dérive aussitôt de la boîte à rythmes. Vu de
    /// l'instrumentiste, elle « ne se synchronise pas » : rien ne distingue ce
    /// cas d'une panne, puisque le départ, lui, a bien fonctionné.
    ///
    /// Beaucoup de claviers ne transmettent l'horloge que si on le leur demande,
    /// et le réglage ne porte pas le même nom d'une marque à l'autre. Le dire au
    /// bout de deux temps coûte une phrase et évite de chercher du côté de
    /// l'application un réglage qui est sur l'instrument.
    private func watchForMissingClock() {
        clockWatchToken &+= 1
        let token = clockWatchToken
        let delay = min(max(2 * 60 / settings.bpm, 1.5), 5)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.clockWatchToken == token,
                  self.running, self.externallyTriggered, self.clockBpm == nil
            else { return }
            self.message = .warning(
                String(localized: "No MIDI clock is arriving"),
                detail: String(localized: "The session started on the keyboard's Start message, but no clock follows it. The tempo stays the one set here and will drift apart from your drum machine — enable clock transmission on the instrument."))
        }
    }

    /// Le tempo reçu du clavier devient celui de l'application.
    ///
    /// Sans cela, la valeur ne vivrait que le temps de la séance : à l'arrêt,
    /// l'horloge cesse d'être reçue et tout ce qui en dépend — zone juste,
    /// échelle du graphe, tempo affiché — retomberait sur le réglage manuel
    /// devenu obsolète. L'adopter le rend persistant (EX-093) et cohérent
    /// d'une séance à l'autre.
    ///
    /// La zone morte évite de réécrire le réglage à chaque battement quand
    /// l'estimation oscille autour d'une valeur entière.
    private func adoptClockTempo() {
        guard let clockBpm, abs(clockBpm - settings.bpm) > 0.75 else { return }
        settings.bpm = min(max(clockBpm.rounded(), 30), 240)
    }

    /// Point de grille le plus proche. L'écart ne peut donc jamais dépasser
    /// une demi-période. (EX-032)
    private func nearestStep(_ t: Double) -> Double {
        gridLock.withLock {
            guard period > 0 else { return t }
            return anchor + ((t - anchor) / period).rounded() * period
        }
    }

    /// Le filtre de canal dit quelle partie du clavier nous intéresse : il vaut
    /// donc pour la mesure comme pour le module sonore. (EX-017)
    private func listens(to channel: UInt8) -> Bool {
        settings.midiChannels.isEmpty || settings.midiChannels.contains(Int(channel) + 1)
    }

    private func handle(time: Double, note: UInt8, velocity: UInt8, channel: UInt8) {
        guard listens(to: channel) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }


            // L'écart est calculé d'entrée, avant toute sonorisation : c'est lui
            // qui décide si l'iPhone ajoute une octave ou étouffe la note
            // (EX-134). Le reporter obligerait à traiter séparément chacune des
            // sorties anticipées qui suivent — seuil de vélocité, séance à
            // l'arrêt, regroupement d'accord — et une seule oubliée rendrait
            // des notes muettes.
            let corrected = time + self.activeAlignmentMs / 1000
            let delta = corrected - self.nearestStep(corrected)

            // Le module sonore répond à toutes les frappes, y compris sous le
            // seuil de vélocité : celui-ci écarte du bruit de mesure (EX-018),
            // pas des notes qu'on vient bel et bien de jouer. Il passe donc
            // avant le filtre, et avant même que la séance soit lancée — sinon
            // arrêter le métronome rendrait le clavier muet. (EX-133)
            if self.settings.instrumentEnabled {
                self.prepareInstrument()
                self.voiceNote(note, velocity: velocity,
                               accurate: abs(delta) <= self.tolerance)
            }

            guard Int(velocity) >= self.settings.minVelocity else { return }         // (EX-018)
            self.midi.lastNote = NoteName.of(note)
            guard self.running else { return }


            self.hits.append(Hit(time: corrected, delta: delta))
            if self.hits.count > 400 { self.hits.removeFirst(self.hits.count - 400) }


            self.deltas.append(delta)
            self.notesPlayed += 1
            // Fenêtre glissante : les premières notes de la séance ne doivent
            // pas plomber le bilan indéfiniment. (EX-084)
            let cap = max(self.settings.statsWindow, 10)
            if self.deltas.count > cap { self.deltas.removeFirst(self.deltas.count - cap) }

            self.lastDelta = delta
            self.recomputeStats()
            self.reportOverloadIfAny(lag: HostClock.now - time)
        }
    }

    // =====================================================================
    // Sonorisation par l'iPhone (EX-133 / EX-134)
    // =====================================================================

    /// Touches dont la frappe juste a fait ajouter une octave, pour savoir
    /// laquelle relâcher au lever.
    private var octaveCompanions: Set<UInt8> = []

    private static func companion(of note: UInt8) -> UInt8 {
        UInt8(min(127, Int(note) + 12))
    }

    private func voiceNote(_ note: UInt8, velocity: UInt8, accurate: Bool) {
        // Sans grille en marche il n'y a pas de justesse à évaluer : tout sonne.
        // Sinon « Étouffer les autres » rendrait le clavier entièrement muet dès
        // qu'on arrête le métronome — l'alarme immédiate, pour un réglage qui
        // n'a de sens que pendant une séance.
        guard running else {
            metronome.instrumentNoteOn(note, velocity: velocity)
            return
        }

        switch settings.accuracyVoicing {
        case .none:
            metronome.instrumentNoteOn(note, velocity: velocity)

        case .octave:
            metronome.instrumentNoteOn(note, velocity: velocity)
            guard accurate else { return }
            octaveCompanions.insert(note)
            metronome.instrumentNoteOn(Self.companion(of: note), velocity: velocity)

        case .accurateOnly:
            if accurate { metronome.instrumentNoteOn(note, velocity: velocity) }
        }
    }

    /// Relâche la note et, le cas échéant, l'octave qui l'accompagnait.
    ///
    /// Sans condition sur le réglage : une note lancée doit être relâchée même
    /// si l'on coupe le module entre l'appui et le lever.
    private func releaseVoicedNote(_ note: UInt8) {
        metronome.instrumentNoteOff(note)
        if octaveCompanions.remove(note) != nil {
            metronome.instrumentNoteOff(Self.companion(of: note))
        }
    }

    /// Signale une seule fois par séance que le rendu audio a décroché.
    ///
    /// Sans ce message, une surcharge ne se manifeste que par « l'application
    /// sature au bout de quelques minutes » — un symptôme qui ne dit ni où ni
    /// quand, et qu'on ne peut pas reproduire au simulateur puisqu'il n'y reçoit
    /// aucune note. Le compteur, lui, désigne le sous-système fautif.
    private func reportOverloadIfAny(lag: Double) {
        guard !overloadReported else { return }

        if lag > Self.lateThreshold {
            overloadReported = true
            message = .warning(
                String(format: NSLocalizedString("Notes are being handled %d ms late", comment: ""),
                       Int(lag * 1000)),
                detail: String(localized: "The app is not keeping up with the incoming stream. Their measured timing stays correct, but they may scroll off the graph before they are drawn."))
            return
        }
        if metronome.overloadCount > 0 {
            overloadReported = true
            message = .warning(
                String(localized: "Some sound was dropped"),
                detail: String(localized: "The audio engine fell behind. Timing measurements are unaffected."))
        }
    }

    private func recomputeStats() {
        let n = deltas.count
        guard n > 0 else { stats = Stats(); return }
        let mean = deltas.reduce(0, +) / Double(n)
        let variance = deltas.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(n)
        let inZone = Double(deltas.filter { abs($0) <= tolerance }.count) / Double(n) * 100
        stats = Stats(played: notesPlayed, count: n, mean: mean,
                      sd: variance.squareRoot(), inZone: inZone)
    }

    func resetStats() {                                    // (EX-085)
        hits.removeAll(); deltas.removeAll()
        lastDelta = nil
        notesPlayed = 0
        stats = Stats()
    }

#if DEBUG
    /// Données plausibles pour les aperçus Xcode. Doit rester dans ce fichier :
    /// les propriétés sont en `private(set)`.
    func seedPreviewData() {
        let now = HostClock.now
        let samples: [Double] = [-0.031, 0.012, -0.008, 0.024, -0.017,
                                  0.005, 0.038, -0.002, 0.019, -0.011]
        hits = samples.enumerated().map { i, d in
            Hit(time: now - Double(samples.count - i) * 0.45, delta: d)
        }
        beats = (0..<8).map { Beat(time: now - Double($0) * 0.75, isMain: true) }
        deltas = samples
        lastDelta = samples.last
        recomputeStats()
    }
#endif
}
