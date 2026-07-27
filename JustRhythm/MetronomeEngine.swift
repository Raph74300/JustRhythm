import Foundation
import AVFoundation
import os

/// Métronome rendu par un `AVAudioSourceNode`.
///
/// Le callback de rendu tourne en permanence : il tient un compteur
/// d'échantillons absolu et mélange les clics à la position exacte demandée.
/// Aucune dérive, aucun décrochage entre deux temps. (EX-047)
///
/// `AVAudioPlayerNode.scheduleBuffer(at:)` a été écarté : son horloge
/// `lastRenderTime` n'existe qu'une fois le nœud en train de rendre, et il ne
/// rend que si un buffer lui a été programmé — blocage circulaire.
final class MetronomeEngine {

    /// Une occurrence de clic. Elle porte ses propres échantillons : changer
    /// de timbre en pleine séance ne demande donc aucune synchronisation avec
    /// le thread audio.
    private struct Voice {
        let startFrame: Int64
        let samples: [Float]
        let gain: Float
    }

    private final class Shared {
        var frames: Int64 = 0
        var anchorHost: Double = 0
        var anchorFrame: Int64 = 0
        var pending: [Voice] = []
    }

    private let engine = AVAudioEngine()
    private let shared = Shared()
    private let lock: UnsafeMutablePointer<os_unfair_lock> = {
        let p = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        p.initialize(to: os_unfair_lock())
        return p
    }()

    private var source: AVAudioSourceNode?
    private var sampleRate: Double = 48_000
    private var started = false

    /// Les cinq timbres dans leurs deux variantes, synthétisés une fois au
    /// démarrage. Une cinquantaine de kilo-octets : autant tout précalculer.
    private var banks: [ClickVoice: (normal: [Float], accent: [Float])] = [:]

    /// Prévenu quand la session audio est interrompue puis rétablie. (EX-050)
    var onInterruption: ((Bool) -> Void)?

    private var interruptionToken: NSObjectProtocol?

    /// Retard entre la programmation et la sortie réelle du son. (EX-034)
    private(set) var outputLatency: Double = 0

    var isRunning: Bool { started }

    // =====================================================================

    func start() throws {
        guard !started else { return }

        let session = AVAudioSession.sharedInstance()
        // .playback : le clic passe malgré l'interrupteur silence.
        // .mixWithOthers : on ne coupe pas une autre source. (EX-050)
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)

        sampleRate = session.sampleRate > 0 ? session.sampleRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw NSError(domain: "JustRhythm", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Format audio indisponible"])
        }

        banks = [:]
        for voice in ClickVoice.allCases {
            banks[voice] = (normal: voice.samples(rate: sampleRate, accent: false),
                            accent: voice.samples(rate: sampleRate, accent: true))
        }
        observeInterruptions()

        let shared = self.shared
        let lock = self.lock
        var voices: [Voice] = []      // exclusif au thread audio

        let node = AVAudioSourceNode(format: format) { isSilence, timestamp, frameCount, ablPointer in
            let frames = Int(frameCount)
            let buffers = UnsafeMutableAudioBufferListPointer(ablPointer)

            os_unfair_lock_lock(lock)
            let hostTime = timestamp.pointee.mHostTime
            if hostTime != 0 {
                shared.anchorHost = HostClock.seconds(hostTime)
                shared.anchorFrame = shared.frames
            }
            if !shared.pending.isEmpty {
                voices.append(contentsOf: shared.pending)
                shared.pending.removeAll(keepingCapacity: true)
            }
            let base = shared.frames
            shared.frames += Int64(frames)
            os_unfair_lock_unlock(lock)

            for buffer in buffers {
                memset(buffer.mData, 0, Int(buffer.mDataByteSize))
            }
            if voices.isEmpty {
                isSilence.pointee = true
                return noErr
            }

            for buffer in buffers {
                guard let out = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for voice in voices {
                    let count = voice.samples.count
                    for frame in 0..<frames {
                        let index = Int(base &+ Int64(frame) &- voice.startFrame)
                        guard index >= 0, index < count else { continue }
                        out[frame] += voice.samples[index] * voice.gain
                    }
                }
            }

            let horizon = base &+ Int64(frames)
            voices.removeAll { horizon &- $0.startFrame >= Int64($0.samples.count) }

            isSilence.pointee = false
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()

        source = node
        started = true
        outputLatency = session.outputLatency + session.ioBufferDuration
    }

    func stop() {
        guard started else { return }
        started = false
        if let interruptionToken {
            NotificationCenter.default.removeObserver(interruptionToken)
            self.interruptionToken = nil
        }
        engine.stop()
        if let node = source {
            engine.detach(node)
            source = nil
        }
        os_unfair_lock_lock(lock)
        shared.pending.removeAll()
        shared.anchorHost = 0
        os_unfair_lock_unlock(lock)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Programme un clic pour qu'il soit **entendu** à `hostSeconds`.
    ///
    /// On retire `outputLatency` : c'est le son perçu qui doit tomber sur le
    /// temps, pas l'ordre donné au moteur. (EX-034)
    func schedule(at hostSeconds: Double, voice: ClickVoice, accent: Bool, volume: Float) {
        guard started, let bank = banks[voice] else { return }

        os_unfair_lock_lock(lock)
        let anchorHost = shared.anchorHost
        let anchorFrame = shared.anchorFrame
        os_unfair_lock_unlock(lock)

        guard anchorHost > 0 else { return }

        let target = hostSeconds - outputLatency
        let frame = anchorFrame + Int64((target - anchorHost) * sampleRate)

        os_unfair_lock_lock(lock)
        shared.pending.append(Voice(startFrame: frame,
                                    samples: accent ? bank.accent : bank.normal,
                                    gain: max(0, min(1, volume))))
        os_unfair_lock_unlock(lock)
    }

    /// Clic isolé, pour vérifier la chaîne audio sans lancer de séance. (EX-052)
    func playTestClick(voice: ClickVoice, volume: Float) {
        schedule(at: HostClock.now + 0.08, voice: voice, accent: true, volume: volume)
    }

    // =====================================================================

    /// Un appel ou une notification suspend la session audio. Sans cette
    /// écoute, le métronome s'arrêterait sans que rien ne le signale. (EX-050)
    private func observeInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            onInterruption?(false)
        case .ended:
            let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map { AVAudioSession.InterruptionOptions(rawValue: $0) } ?? []
            let resumed = options.contains(.shouldResume) && (try? resumeAfterInterruption()) != nil
            onInterruption?(resumed)
        @unknown default:
            break
        }
    }

    private func observeInterruptions() {
        if let interruptionToken {
            NotificationCenter.default.removeObserver(interruptionToken)
        }
        interruptionToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main) { [weak self] note in
                self?.observeInterruption(note)
            }
    }

    private func resumeAfterInterruption() throws {
        guard started else { return }
        try AVAudioSession.sharedInstance().setActive(true)
        if !engine.isRunning { try engine.start() }
    }
}
