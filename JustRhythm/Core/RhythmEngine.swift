import Foundation
import Observation
import UIKit

struct Hit: Identifiable {
    let id = UUID()
    let time: Double        // instant retenu, en secondes host
    let delta: Double       // écart signé : < 0 en avance, > 0 en retard
    var notes: [UInt8]      // toutes les notes du groupe (EX-036)
    var spread: Double      // étalement du groupe, en secondes (EX-037)
}

struct Beat: Identifiable {
    let id = UUID()
    let time: Double
    let isMain: Bool        // sur le temps, par opposition à une subdivision
    let isAccent: Bool      // premier temps de la mesure (EX-042)
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
    var message: String?

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

    private var deltas: [Double] = []
    /// Compté à part : `deltas` est plafonné par la fenêtre glissante et ne
    /// peut donc pas servir à savoir combien de notes ont été jouées.
    private var notesPlayed = 0
    private var openGroup: (index: Int, start: Double)?
    private var timer: DispatchSourceTimer?

    // — Suivi de l'horloge MIDI (EX-054) —
    /// Au-delà de cet écart relatif, un intervalle n'est plus de la gigue mais
    /// un tempo qu'on vient de changer sur le clavier. Le seuil laisse passer
    /// largement la gigue du transport — de l'ordre du pour cent — et la perte
    /// d'une impulsion d'horloge, qui allonge un temps de 1/24, soit 4,2 %.
    private static let tempoJumpRatio = 0.08
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
                self.stopReward(note, channel: channel)
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
            self.releaseAllRewards()
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
                self.message = String(localized: "Session resumed after an interruption.")
            } else {
                self.stop()
                self.message = String(localized: "Session interrupted by the system.")
            }
        }
        // Posée avant l'ouverture du client : le premier balayage retrouve
        // ainsi le clavier directement, sans repli transitoire. (EX-013)
        midi.preferredID = settings.lastSourceID
        midi.start()
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

    /// Durée d'une mesure, en secondes.
    ///
    /// Passe par `gridPeriod`, donc suit l'horloge du clavier quand elle est
    /// reçue. Sans accent réglé, `beatsPerBar` vaut 0 et il n'y a pas de mesure
    /// à proprement parler : on retient quatre temps, faute de mieux, plutôt
    /// que de rendre zéro.
    var barDuration: Double {
        let beat = gridPeriod * Double(settings.subdivision.rawValue)
        return beat * Double(settings.beatsPerBar > 0 ? settings.beatsPerBar : 4)
    }

    /// Au-delà, une note de retour est relâchée d'office. (EX-130 / EX-131)
    ///
    /// Le retour suit le lever de touche, ce qui suppose de recevoir le Note
    /// Off correspondant. S'il se perd — message manqué, clavier débranché,
    /// canal écouté modifié en cours de séance — la note resterait accrochée
    /// indéfiniment. Ce filet lui rend le seul mérite de la durée fixe,
    /// l'extinction garantie, sans revenir à son défaut.
    ///
    /// Une mesure, exactement : dix secondes fixes ne voulaient pas dire la
    /// même chose à 40 et à 200 bpm, une mesure si.
    ///
    /// Conséquence assumée : une note tenue au-delà d'une mesure est relâchée
    /// d'office, y compris à la pédale par-dessus une barre de mesure. Le filet
    /// est serré exprès — il vaut mieux écourter une tenue que laisser une note
    /// fantôme s'installer. Aucune borne : le tempo est déjà limité à 30-240 bpm
    /// et les temps par mesure à 12, la valeur reste donc toujours finie.
    private var rewardSafetyRelease: Double { barDuration }

    /// Touche jouée → note renvoyée, pour savoir quoi relâcher au lever.
    ///
    /// Mémorisée plutôt que recalculée : changer de mode entre l'appui et le
    /// lever ferait sinon relâcher une note qu'on n'a jamais envoyée, et
    /// laisserait sonner celle qu'on avait envoyée.
    ///
    /// Le jeton distingue deux appuis successifs de la même touche. Sans lui,
    /// le minuteur de sécurité du premier appui verrait la même note à la même
    /// place et couperait celle du second, qui n'a pourtant pas encore vécu
    /// son délai.
    private var rewardNotes: [UInt16: (note: UInt8, token: UInt64)] = [:]
    private var rewardToken: UInt64 = 0

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
            message = String(format: NSLocalizedString("Audio unavailable: %@", comment: ""), error.localizedDescription)
            return
        }
        outputLatency = metronome.outputLatency
        message = outputLatency > 0.060
            ? String(format: NSLocalizedString("Audio output delayed by %d ms — likely a wireless output, which will skew the average.", comment: ""), Int(outputLatency * 1000))
            : nil

        hits.removeAll(); beats.removeAll(); deltas.removeAll()
        lastDelta = nil; stats = Stats(); openGroup = nil; notesPlayed = 0
        overloadReported = false

        externallyTriggered = externalStart != nil
        gridLock.withLock {
            period = settings.stepPeriod
            anchor = externalStart ?? (HostClock.now + 0.25)
            stepIndex = 0
            nextStep = anchor

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
        lastBeatTime = nil; smoothedBeat = nil; clockBpm = nil
        timer?.cancel(); timer = nil
        releaseAllRewards()

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
            message = String(format: NSLocalizedString("Instrument unavailable: %@", comment: ""),
                             error.localizedDescription)
            settings.instrumentEnabled = false
        }
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
            message = String(format: NSLocalizedString("Audio unavailable: %@", comment: ""), error.localizedDescription)
            return
        }
        metronome.playTestClick(voice: settings.clickVoice, volume: Float(settings.volume))
    }

    // =====================================================================

    private func schedule() {
        guard running else { return }
        let horizon = HostClock.now + 0.20
        var scheduled: [Beat] = []

        gridLock.withLock {
            while nextStep < horizon {
                let subdiv = settings.subdivision.rawValue
                let perBar = settings.stepsPerBar
                let isMain = stepIndex % subdiv == 0
                let isAccent = perBar > 0 && stepIndex % perBar == 0

                // Le clic ne sonne que sur les temps : cliquer les subdivisions
                // est en phase 3 (EX-044). La grille, elle, est déjà fine.
                if settings.clickEnabled && isMain {
                    metronome.schedule(at: nextStep,
                                       voice: settings.clickVoice,
                                       accent: isAccent,
                                       volume: Float(settings.volume))
                }
                scheduled.append(Beat(time: nextStep, isMain: isMain, isAccent: isAccent))
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
                let expected = self.anchor + ((time - self.anchor) / newPeriod).rounded() * newPeriod
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
                self.stepIndex = 0
                self.nextStep = self.anchor
                while self.nextStep < HostClock.now + 0.02 {
                    self.stepIndex += 1
                    self.nextStep = self.anchor + Double(self.stepIndex) * newPeriod
                }
            }
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
            let corrected = time + self.settings.manualAlignmentMs / 1000
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

            // Regroupement d'accord : les notes reçues dans une fenêtre courte
            // comptent pour un seul événement, daté sur la première. (EX-036)
            let window = self.settings.chordWindowMs / 1000
            if window > 0, let group = self.openGroup,
               time - group.start < window, group.index < self.hits.count {
                self.hits[group.index].notes.append(note)
                self.hits[group.index].spread = time - group.start   // (EX-037)
                return
            }

            self.hits.append(Hit(time: corrected, delta: delta, notes: [note], spread: 0))
            if self.hits.count > 400 { self.hits.removeFirst(self.hits.count - 400) }
            self.openGroup = (index: self.hits.count - 1, start: time)

            if self.settings.feedbackEnabled, abs(delta) <= self.tolerance {
                let reward: UInt8
                switch self.settings.feedbackMode {
                case .octave: reward = UInt8(min(127, Int(note) + 12))  // (EX-130)
                case .mute:   reward = note                            // (EX-131)
                }
                self.startReward(reward, for: note, velocity: velocity, channel: channel)
            }

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

    // =====================================================================
    // Retour clavier (EX-130 / EX-131)
    //
    // La note de retour part à l'appui et s'éteint au lever de la touche qui
    // l'a déclenchée. Elle dure donc exactement ce que dure le geste, ce
    // qu'aucune durée calculée d'avance ne savait faire : fixe, elle traînait
    // sur les valeurs brèves ; rapportée à la subdivision, elle polluait dès
    // qu'on jouait vraiment un morceau, où les durées ne suivent pas la grille.
    // =====================================================================

    private func startReward(_ reward: UInt8, for played: UInt8,
                             velocity: UInt8, channel: UInt8) {
        let key = Self.rewardKey(played, channel)
        // Réappui sans lever perçu : on éteint l'ancienne avant d'en lancer une
        // nouvelle, sinon la première ne serait plus jamais relâchée.
        if let previous = rewardNotes[key] { midi.stopNote(previous.note, channel: channel) }

        rewardToken &+= 1
        let token = rewardToken
        rewardNotes[key] = (note: reward, token: token)
        midi.startNote(reward, velocity: velocity, channel: channel)

        // Le délai est figé au moment de l'appui : c'est le tempo en vigueur
        // quand la note part qui décide, pas celui qu'on aura plus tard.
        DispatchQueue.main.asyncAfter(deadline: .now() + rewardSafetyRelease) { [weak self] in
            guard let self, self.rewardNotes[key]?.token == token else { return }
            self.stopReward(played, channel: channel)
        }
    }

    private func stopReward(_ played: UInt8, channel: UInt8) {
        let key = Self.rewardKey(played, channel)
        guard let reward = rewardNotes.removeValue(forKey: key) else { return }
        midi.stopNote(reward.note, channel: channel)
    }

    /// Éteint tout retour en cours. À l'arrêt, à la coupure du réglage et à la
    /// perte de la source : rien ne doit survivre à ce qui l'a déclenché.
    private func releaseAllRewards() {
        rewardNotes.removeAll()
        midi.releaseAllSentNotes()
    }

    /// Suit la bascule du retour clavier depuis les Réglages.
    func feedbackSettingChanged() {
        if !settings.feedbackEnabled { releaseAllRewards() }
    }

    private static func rewardKey(_ note: UInt8, _ channel: UInt8) -> UInt16 {
        UInt16(channel & 0x0F) << 8 | UInt16(note)
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
            message = String(format: NSLocalizedString(
                "Notes are being handled %d ms late — the app is not keeping up with the incoming stream. Their measured timing stays correct, but they may scroll off the graph before they are drawn.",
                comment: ""), Int(lag * 1000))
            return
        }
        if metronome.overloadCount > 0 {
            overloadReported = true
            message = String(localized: "The audio engine fell behind and some sound was dropped. Timing measurements are unaffected.")
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
        hits.removeAll(); deltas.removeAll(); openGroup = nil
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
            Hit(time: now - Double(samples.count - i) * 0.45, delta: d,
                notes: [UInt8(60 + i)], spread: 0)
        }
        beats = (0..<8).map { Beat(time: now - Double($0) * 0.75, isMain: true,
                                   isAccent: $0 % 4 == 0) }
        deltas = samples
        lastDelta = samples.last
        recomputeStats()
    }
#endif
}
