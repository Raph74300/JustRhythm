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
        var synthEvents: [SynthEvent] = []
        /// Niveau du module sonore, indépendant de celui du clic. (EX-137)
        ///
        /// Ici plutôt que dans `SynthEvent` : c'est une valeur, pas un
        /// événement, et un curseur qu'on fait glisser en produirait des
        /// centaines à la seconde dans une file dimensionnée pour des notes.
        var synthGain: Float = 1
        /// Nombre de fois qu'un garde-fou a dû jeter du travail en retard.
        /// Sert à transformer une panne silencieuse en symptôme lisible.
        var overloads = 0
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

    // — Module sonore (EX-133) —
    /// Rendu par *le même* callback que le clic, et c'est tout l'intérêt : les
    /// notes et le métronome sortent par le même haut-parleur, au terme du
    /// même chemin, donc avec la même latence. Rien à corriger entre les deux,
    /// contrairement à un retour renvoyé sur l'instrument.
    private let synth = InstrumentSynth()

    /// Timbre déjà en service, pour ne pas le recharger à chaque note.
    /// Écrit et lu depuis la queue principale uniquement.
    private var loadedVoice: InstrumentVoice?

    /// Ce que le thread audio doit appliquer au synthé au prochain bloc.
    /// Les événements ne peuvent pas être joués depuis la queue principale :
    /// l'état des voix appartient au rendu, et rien ne doit s'y écrire pendant
    /// qu'il le lit.
    private enum SynthEvent {
        case noteOn(UInt8, UInt8)
        case noteOff(UInt8)
        case sustain(Bool)
        case timbre
        case silence
    }

    /// Tampon mono du synthé, alloué une fois : le rendu ne doit rien allouer.
    private var scratch: UnsafeMutablePointer<Double>?
    private var scratchCapacity = 0

    /// Les cinq timbres, synthétisés une fois au démarrage. Quelques dizaines
    /// de kilo-octets : autant tout précalculer.
    private var banks: [ClickVoice: [Float]] = [:]

    /// Prévenu quand la session audio est interrompue puis rétablie. (EX-050)
    var onInterruption: ((Bool) -> Void)?

    private var interruptionToken: NSObjectProtocol?

    /// Retard entre la programmation et la sortie réelle du son. (EX-034)
    private(set) var outputLatency: Double = 0

    var isRunning: Bool { started }

    /// Nombre de fois qu'un garde-fou a jeté du travail en retard depuis le
    /// démarrage. Toute valeur non nulle signale que le rendu n'a pas suivi :
    /// c'est exactement le genre de panne qui, sans compteur, ne se manifeste
    /// que par « l'application a l'air de saturer ».
    var overloadCount: Int {
        os_unfair_lock_lock(lock)
        let n = shared.overloads
        os_unfair_lock_unlock(lock)
        return n
    }

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
                          userInfo: [NSLocalizedDescriptionKey: String(localized: "Audio format unavailable")])
        }

        banks = [:]
        for voice in ClickVoice.allCases {
            banks[voice] = voice.samples(rate: sampleRate)
        }
        observeInterruptions()

        synth.prepare(sampleRate: sampleRate)
        loadedVoice = nil
        allocateScratch(4096)

        // Capacité réservée d'avance : sans cela, le premier `append` qui
        // dépasse le tampon le réalloue — donc alloue — en tenant le verrou que
        // le thread audio réclame. C'est le même piège que `stage`, et il se
        // referme d'autant plus que l'on joue vite.
        shared.pending.reserveCapacity(64)
        shared.synthEvents.reserveCapacity(256)

        let shared = self.shared
        let lock = self.lock
        let synth = self.synth
        var voices: [Voice] = []      // exclusif au thread audio

        let node = AVAudioSourceNode(format: format) { [weak self] isSilence, timestamp, frameCount, ablPointer in
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
            // Garde-fou sur les clics en vol. En régime normal il y en a deux ou
            // trois : ils sont programmés 200 ms d'avance et retirés dès qu'ils
            // sont joués. Mais un clic dont l'instant de départ tomberait loin
            // dans l'avenir ne serait jamais retiré, et la boucle de mélange —
            // en O(voix × échantillons) — ralentirait un peu plus à chaque
            // seconde. Symptôme : une dégradation qui n'apparaît qu'au bout de
            // plusieurs minutes, jamais lors d'un essai court.
            if voices.count > 32 {
                voices.removeFirst(voices.count - 32)
                shared.overloads += 1
            }
            // Les événements du synthé s'appliquent ici, et nulle part ailleurs :
            // l'état des voix appartient au rendu.
            for event in shared.synthEvents {
                switch event {
                case .noteOn(let note, let velocity): synth.noteOn(note, velocity: velocity)
                case .noteOff(let note):              synth.noteOff(note)
                case .sustain(let down):              synth.sustain(down)
                case .timbre:                         synth.adoptStagedTimbre()
                case .silence:                        synth.silence()
                }
            }
            shared.synthEvents.removeAll(keepingCapacity: true)
            let synthGain = shared.synthGain
            let base = shared.frames
            shared.frames += Int64(frames)
            os_unfair_lock_unlock(lock)

            for buffer in buffers {
                memset(buffer.mData, 0, Int(buffer.mDataByteSize))
            }

            var sounded = false
            if let scratch = self?.scratch, frames <= self?.scratchCapacity ?? 0 {
                scratch.update(repeating: 0, count: frames)
                // Le rendu a lieu même à volume nul : les enveloppes doivent
                // continuer de descendre, sinon une note coupée au curseur
                // repartirait à son niveau d'attaque en le remontant.
                sounded = synth.render(into: scratch, frames: frames)
                if sounded && synthGain > 0 {
                    for buffer in buffers {
                        guard let out = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                        for frame in 0..<frames {
                            // Le gain s'applique **après** la saturation douce,
                            // et non avant : appliqué avant, il déplacerait le
                            // seuil d'écrêtage et le timbre changerait avec le
                            // niveau. (EX-137)
                            out[frame] += Float(Self.softClip(scratch[frame])) * synthGain
                        }
                    }
                }
            }

            if voices.isEmpty && !sounded {
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
        synth.silence()
        os_unfair_lock_lock(lock)
        shared.pending.removeAll()
        shared.synthEvents.removeAll()
        shared.anchorHost = 0
        os_unfair_lock_unlock(lock)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Programme un clic pour qu'il soit **entendu** à `hostSeconds`.
    ///
    /// On retire `outputLatency` : c'est le son perçu qui doit tomber sur le
    /// temps, pas l'ordre donné au moteur. (EX-034)
    func schedule(at hostSeconds: Double, voice: ClickVoice, volume: Float) {
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
                                    samples: bank,
                                    gain: max(0, min(1, volume))))
        os_unfair_lock_unlock(lock)
    }

    /// Clic isolé, pour vérifier la chaîne audio sans lancer de séance. (EX-052)
    func playTestClick(voice: ClickVoice, volume: Float) {
        schedule(at: HostClock.now + 0.08, voice: voice, volume: volume)
    }

    // =====================================================================
    // Module sonore (EX-133)
    // =====================================================================

    /// Met un timbre en service. La recette est lue ici, sur la queue
    /// principale ; le rendu se contente ensuite de l'adopter.
    ///
    /// Deux précautions, et ce ne sont pas des raffinements. **Sortie immédiate
    /// si le timbre ne change pas** : cette méthode est sur le chemin de chaque
    /// note, et sans ce garde-fou elle refaisait tout le travail à chaque
    /// frappe. **`stage` hors du verrou** : il construit trois tableaux, donc il
    /// alloue, et allouer en tenant un verrou que le thread audio réclame
    /// toutes les dix millisecondes est une inversion de priorité — le rendu
    /// attend le malloc de la queue principale et manque son échéance. L'ordre
    /// reste correct : la préparation est achevée avant que l'événement qui la
    /// signale ne devienne visible.
    func loadInstrument(_ voice: InstrumentVoice) {
        guard loadedVoice != voice else { return }
        loadedVoice = voice

        synth.stage(voice)
        os_unfair_lock_lock(lock)
        shared.synthEvents.append(.timbre)
        os_unfair_lock_unlock(lock)
    }

    /// Niveau du module sonore, indépendant de celui du clic. (EX-137)
    ///
    /// Appelable moteur arrêté : la valeur vit dans l'état partagé et attend le
    /// prochain démarrage, ce qui évite de la reposer à chaque `start()`.
    func setInstrumentVolume(_ volume: Float) {
        os_unfair_lock_lock(lock)
        shared.synthGain = max(0, min(1, volume))
        os_unfair_lock_unlock(lock)
    }

    func instrumentNoteOn(_ note: UInt8, velocity: UInt8) { post(.noteOn(note, velocity)) }
    func instrumentNoteOff(_ note: UInt8)                 { post(.noteOff(note)) }

    /// Pédale forte. Ignorée par la mesure, qui ne compte que des frappes
    /// (EX-016), mais indispensable dès que le téléphone tient le son : sans
    /// elle, il n'y a tout simplement pas de jeu lié au piano.
    func instrumentSustain(_ down: Bool) { post(.sustain(down)) }

    /// Coupe tout ce qui sonne encore. Sans cela, une note tenue au moment où
    /// l'on coupe le module resterait accrochée jusqu'à l'arrêt du moteur.
    func instrumentSilence() { post(.silence) }

    /// Saturation douce du bus du synthé.
    ///
    /// Une note isolée culmine vers 0,5, mais dix notes tenues à la pédale se
    /// somment jusqu'à 2,3 quand leurs attaques coïncident. Il faut donc
    /// comprimer, et la cubique classique `x - x³/3` **ne suffit pas seule** :
    /// elle n'est monotone que sur [-1, 1]. Au-delà elle se retourne et
    /// replie l'onde, ce qui s'entend bien plus mal qu'un écrêtage franc, puis
    /// diverge carrément. Le rabattement préalable dans [-1, 1] n'est donc pas
    /// une précaution mais la condition de validité de la formule.
    ///
    /// Le facteur 1,5 ramène la sortie de la cubique — bornée à 2/3 — à
    /// l'unité, et le niveau final laisse la place au clic dans le mélange.
    private static func softClip(_ sample: Double) -> Double {
        let x = max(-1, min(1, sample * 0.6))
        return (x - x * x * x / 3) * 1.5 * 0.5
    }

    private func post(_ event: SynthEvent) {
        guard started else { return }
        os_unfair_lock_lock(lock)
        // Une file qui gonfle signifie que le rendu ne la vide plus — moteur
        // suspendu, surcharge, interruption. La laisser croître ferait grossir
        // la mémoire sans fin et rejouerait, au retour, des minutes d'événements
        // périmés d'un coup. On repart donc de zéro, en éteignant ce qui sonne
        // pour ne pas laisser de note accrochée.
        if shared.synthEvents.count > 512 {
            shared.synthEvents.removeAll(keepingCapacity: true)
            shared.synthEvents.append(.silence)
            shared.overloads += 1
        }
        shared.synthEvents.append(event)
        os_unfair_lock_unlock(lock)
    }

    private func allocateScratch(_ capacity: Int) {
        scratch?.deallocate()
        let p = UnsafeMutablePointer<Double>.allocate(capacity: capacity)
        p.initialize(repeating: 0, count: capacity)
        scratch = p
        scratchCapacity = capacity
    }

    /// Oublie les clics déjà programmés sans arrêter le moteur.
    ///
    /// À l'arrêt d'une séance, le moteur doit rester en marche tant que le
    /// module sonore est actif (EX-133) : sinon, couper le métronome rendrait
    /// le clavier muet chez qui joue Local Control désactivé. On se contente
    /// donc de vider la file, faute de quoi les clics déjà programmés dans les
    /// 200 ms à venir sonneraient après l'arrêt.
    func flushPending() {
        os_unfair_lock_lock(lock)
        shared.pending.removeAll(keepingCapacity: true)
        os_unfair_lock_unlock(lock)
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
