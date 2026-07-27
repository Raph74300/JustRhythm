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

struct Stats {
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
    private var anchor: Double = 0
    private var period: Double = 0.75
    private var stepIndex = 0
    private var nextStep: Double = 0

    private var deltas: [Double] = []
    private var openGroup: (index: Int, start: Double)?
    private var timer: DispatchSourceTimer?

    // — Suivi de l'horloge MIDI (EX-054) —
    /// 24 impulsions par noire, c'est la définition du MIDI Clock.
    private static let clocksPerBeat = 24
    private var clockCount = 0
    private var lastBeatTime: Double?
    private var smoothedBeat: Double?
    private let queue = DispatchQueue(label: "fr.justrhythm.scheduler", qos: .userInteractive)

    init() {
        midi.onNote = { [weak self] time, note, velocity, channel in
            self?.handle(time: time, note: note, velocity: velocity, channel: channel)
        }
        midi.onSourceLost = { [weak self] name in
            guard let self, self.running else { return }
            self.message = "« \(name) » s'est déconnecté."
        }
        midi.onTransport = { [weak self] time, message in
            DispatchQueue.main.async { self?.handleTransport(time: time, message: message) }
        }
        metronome.onInterruption = { [weak self] resumed in
            guard let self else { return }
            if resumed {
                self.message = "Séance reprise après une interruption."
            } else {
                self.stop()
                self.message = "Séance interrompue par le système."
            }
        }
        midi.start()
        if settings.lastSourceID != 0 {
            midi.connect(uniqueID: settings.lastSourceID)
        }
    }

    var tolerance: Double { settings.toleranceMs / 1000 }

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
            message = "Audio indisponible : \(error.localizedDescription)"
            return
        }
        outputLatency = metronome.outputLatency
        message = outputLatency > 0.060
            ? "Sortie audio en retard de \(Int(outputLatency * 1000)) ms — sortie sans fil probable, la moyenne sera faussée."
            : nil

        hits.removeAll(); beats.removeAll(); deltas.removeAll()
        lastDelta = nil; stats = Stats(); openGroup = nil
        stepIndex = 0

        period = settings.stepPeriod
        anchor = externalStart ?? (HostClock.now + 0.25)
        externallyTriggered = externalStart != nil
        stepIndex = 0
        nextStep = anchor

        // Un départ externe est déjà passé de quelques millisecondes quand on
        // le traite : on avance jusqu'au premier pas encore programmable,
        // sinon le premier clic partirait dans le passé et serait perdu.
        while nextStep < HostClock.now + 0.02 {
            stepIndex += 1
            nextStep = anchor + Double(stepIndex) * period
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
            let t = max(HostClock.now + 0.10, self.nextStep)
            self.period = self.settings.stepPeriod
            self.anchor = t
            self.stepIndex = 0
            self.nextStep = t
        }
    }

    /// Clic isolé, sans démarrer la séance. (EX-052)
    func testClick() {
        do {
            if !metronome.isRunning { try metronome.start() }
            outputLatency = metronome.outputLatency
            message = nil
        } catch {
            message = "Audio indisponible : \(error.localizedDescription)"
            return
        }
        metronome.playTestClick(voice: settings.clickVoice, volume: Float(settings.volume))
    }

    // =====================================================================

    private func schedule() {
        guard running else { return }
        let horizon = HostClock.now + 0.20
        var scheduled: [Beat] = []

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
            guard settings.followClock, running else { return }
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

        let smoothed = smoothedBeat.map { $0 * 0.8 + interval * 0.2 } ?? interval
        smoothedBeat = smoothed
        clockBpm = 60.0 / smoothed

        let subdiv = Double(settings.subdivision.rawValue)
        let newPeriod = smoothed / subdiv

        queue.async { [weak self] in
            guard let self, self.running else { return }
            self.period = newPeriod

            // Correction de phase : écart entre la noire reçue et le point de
            // grille le plus proche, appliqué à l'ancrage et borné à 20 ms.
            let expected = self.anchor + ((time - self.anchor) / newPeriod).rounded() * newPeriod
            let error = max(-0.020, min(0.020, time - expected))
            self.anchor += error
            self.nextStep = self.anchor + Double(self.stepIndex) * newPeriod
        }
    }

    /// Point de grille le plus proche. L'écart ne peut donc jamais dépasser
    /// une demi-période. (EX-032)
    private func nearestStep(_ t: Double) -> Double {
        guard period > 0 else { return t }
        return anchor + ((t - anchor) / period).rounded() * period
    }

    private func handle(time: Double, note: UInt8, velocity: UInt8, channel: UInt8) {
        guard Int(velocity) >= settings.minVelocity else { return }                  // (EX-018)
        guard settings.midiChannel == 0 || Int(channel) + 1 == settings.midiChannel  // (EX-017)
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

            self.deltas.append(delta)
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
        stats = Stats(count: n, mean: mean, sd: variance.squareRoot(), inZone: inZone)
    }

    func resetStats() {                                    // (EX-085)
        hits.removeAll(); deltas.removeAll(); openGroup = nil
        lastDelta = nil
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
