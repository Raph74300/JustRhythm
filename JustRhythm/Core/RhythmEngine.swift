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
    /// 24 impulsions par noire, c'est la définition du MIDI Clock.
    private static let clocksPerBeat = 24
    /// Au-delà de cet écart relatif, un intervalle n'est plus de la gigue mais
    /// un tempo qu'on vient de changer sur le clavier. Le seuil laisse passer
    /// largement la gigue du transport — de l'ordre du pour cent — et la perte
    /// d'une impulsion d'horloge, qui allonge un temps de 1/24, soit 4,2 %.
    private static let tempoJumpRatio = 0.08
    private var clockCount = 0
    private var lastBeatTime: Double?
    private var smoothedBeat: Double?
    private let queue = DispatchQueue(label: "fr.justrhythm.scheduler", qos: .userInteractive)

    init() {
        midi.onNote = { [weak self] time, note, velocity, channel in
            self?.handle(time: time, note: note, velocity: velocity, channel: channel)
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
        clockCount = 0; lastBeatTime = nil; smoothedBeat = nil; clockBpm = nil
        timer?.cancel(); timer = nil
        metronome.stop()
        UIApplication.shared.isIdleTimerDisabled = false
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
            clockCount = 0; lastBeatTime = nil; smoothedBeat = nil; clockBpm = nil
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
        clockCount += 1
        guard clockCount % Self.clocksPerBeat == 0 else { return }

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

    private func handle(time: Double, note: UInt8, velocity: UInt8, channel: UInt8) {
        guard Int(velocity) >= settings.minVelocity else { return }                  // (EX-018)
        guard settings.midiChannels.isEmpty || settings.midiChannels.contains(Int(channel) + 1)  // (EX-017)
        else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
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

            let corrected = time + self.settings.manualAlignmentMs / 1000
            let delta = corrected - self.nearestStep(corrected)

            self.hits.append(Hit(time: corrected, delta: delta, notes: [note], spread: 0))
            if self.hits.count > 400 { self.hits.removeFirst(self.hits.count - 400) }
            self.openGroup = (index: self.hits.count - 1, start: time)

            if self.settings.feedbackEnabled, abs(delta) <= self.tolerance {
                switch self.settings.feedbackMode {
                case .octave:
                    let shifted = UInt8(min(127, Int(note) + 12))
                    self.midi.playNote(shifted, velocity: velocity, channel: channel)
                case .mute:
                    self.midi.playNote(note, velocity: velocity, channel: channel)
                }
            }

            self.deltas.append(delta)
            self.notesPlayed += 1
            // Fenêtre glissante : les premières notes de la séance ne doivent
            // pas plomber le bilan indéfiniment. (EX-084)
            let cap = max(self.settings.statsWindow, 10)
            if self.deltas.count > cap { self.deltas.removeFirst(self.deltas.count - cap) }

            self.lastDelta = delta
            self.recomputeStats()
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
