import Foundation

/// Synthèse additive polyphonique des notes reçues. (EX-133)
///
/// Tout ce qui suit s'exécute sur le thread audio, à une exception près
/// signalée nommément (`stage`). Aucune allocation, aucun verrou, aucun appel
/// susceptible de bloquer : l'état est préalloué une fois pour toutes, et les
/// tableaux sont des pointeurs bruts plutôt que des `Array` pour que le
/// vérificateur de bornes ne s'invite pas dans la boucle la plus chaude.
///
/// Le modèle est le même pour les cinq timbres — une somme de partiels qui
/// décroissent chacun à son rythme — et c'est délibéré : un modèle par
/// instrument aurait donné cinq chemins de code à maintenir et à déboguer
/// dans un contexte où l'on ne peut ni poser un point d'arrêt ni journaliser.
final class InstrumentSynth {

    /// Au-delà, on vole la voix la plus ancienne. Dix doigts et une pédale
    /// n'iront pas plus loin en pratique.
    static let maxVoices = 24
    private static let partials = InstrumentVoice.partialCount

    /// Table d'onde plutôt que `sin()` par échantillon : à 24 voix et 8
    /// partiels, l'appel trigonométrique coûterait plusieurs millions
    /// d'évaluations par seconde pour une précision dont personne n'a besoin.
    private static let tableSize = 4096

    // — État par partiel, aplati en `voix * partials + partiel` —
    private let phase: UnsafeMutablePointer<Double>
    private let increment: UnsafeMutablePointer<Double>
    private let amplitude: UnsafeMutablePointer<Double>
    private let decayCoef: UnsafeMutablePointer<Double>

    // — État par voix —
    private let noteOf: UnsafeMutablePointer<Int32>       // -1 = voix libre
    private let keyHeld: UnsafeMutablePointer<Bool>
    private let gain: UnsafeMutablePointer<Double>
    private let attack: UnsafeMutablePointer<Double>
    private let attackStep: UnsafeMutablePointer<Double>
    private let releaseGain: UnsafeMutablePointer<Double>
    private let releaseCoef: UnsafeMutablePointer<Double>
    private let startedAt: UnsafeMutablePointer<UInt64>

    private let table: UnsafeMutablePointer<Double>

    /// Timbre en vigueur, recopié depuis `staged` quand le rendu l'adopte.
    private let ratio: UnsafeMutablePointer<Double>
    private let baseAmp: UnsafeMutablePointer<Double>
    private let baseDecay: UnsafeMutablePointer<Double>
    private var releaseTime: Double = 0.08
    private var velocitySensitivity: Double = 1.0

    /// Timbre préparé sur la queue principale, en attente d'adoption.
    private let stagedRatio: UnsafeMutablePointer<Double>
    private let stagedAmp: UnsafeMutablePointer<Double>
    private let stagedDecay: UnsafeMutablePointer<Double>
    private var stagedRelease: Double = 0.08
    private var stagedSensitivity: Double = 1.0

    private var sampleRate: Double = 48_000
    private var sustainDown = false
    private var counter: UInt64 = 0

    // =====================================================================

    init() {
        let slots = Self.maxVoices * Self.partials
        func doubles(_ n: Int, _ value: Double = 0) -> UnsafeMutablePointer<Double> {
            let p = UnsafeMutablePointer<Double>.allocate(capacity: n)
            p.initialize(repeating: value, count: n)
            return p
        }
        phase      = doubles(slots)
        increment  = doubles(slots)
        amplitude  = doubles(slots)
        decayCoef  = doubles(slots, 1)

        noteOf      = .allocate(capacity: Self.maxVoices)
        noteOf.initialize(repeating: -1, count: Self.maxVoices)
        keyHeld     = .allocate(capacity: Self.maxVoices)
        keyHeld.initialize(repeating: false, count: Self.maxVoices)
        startedAt   = .allocate(capacity: Self.maxVoices)
        startedAt.initialize(repeating: 0, count: Self.maxVoices)
        gain        = doubles(Self.maxVoices)
        attack      = doubles(Self.maxVoices)
        attackStep  = doubles(Self.maxVoices, 1)
        releaseGain = doubles(Self.maxVoices, 1)
        releaseCoef = doubles(Self.maxVoices, 1)

        ratio       = doubles(Self.partials)
        baseAmp     = doubles(Self.partials)
        baseDecay   = doubles(Self.partials, 1)
        stagedRatio = doubles(Self.partials)
        stagedAmp   = doubles(Self.partials)
        stagedDecay = doubles(Self.partials, 1)

        table = doubles(Self.tableSize + 1)
        for i in 0...Self.tableSize {
            table[i] = sin(2 * .pi * Double(i) / Double(Self.tableSize))
        }
    }

    deinit {
        for p in [phase, increment, amplitude, decayCoef, gain, attack, attackStep,
                  releaseGain, releaseCoef, ratio, baseAmp, baseDecay,
                  stagedRatio, stagedAmp, stagedDecay, table] {
            p.deallocate()
        }
        noteOf.deallocate(); keyHeld.deallocate(); startedAt.deallocate()
    }

    // =====================================================================

    /// **Queue principale.** Prépare un timbre sans le mettre en service.
    ///
    /// Le seul point d'entrée hors thread audio, et il ne touche que la zone
    /// `staged`. Les recettes de `InstrumentVoice` sont des `Array` construits
    /// à la demande : les lire ici, une fois, plutôt que dans le rendu, est
    /// précisément ce qui garde le callback exempt d'allocation.
    /// L'appelant sérialise avec le rendu par son propre verrou.
    func stage(_ voice: InstrumentVoice) {
        let ratios = voice.ratios, amps = voice.amplitudes, decays = voice.decays

        // Normalisation : sans elle, le clavecin — huit partiels bien nourris —
        // sortirait trois fois plus fort que le marimba, qui n'en a que trois.
        // Le niveau doit dépendre du volume réglé, pas du timbre choisi.
        let total = amps.reduce(0, +)
        let scale = total > 0 ? 1 / total : 0

        for k in 0..<Self.partials {
            stagedRatio[k] = ratios[k]
            stagedAmp[k]   = amps[k] * scale
            stagedDecay[k] = max(decays[k], 0.01)
        }
        stagedRelease     = voice.release
        stagedSensitivity = voice.velocitySensitivity
    }

    /// **Thread audio.** Met en service le timbre préparé.
    func adoptStagedTimbre() {
        for k in 0..<Self.partials {
            ratio[k]     = stagedRatio[k]
            baseAmp[k]   = stagedAmp[k]
            baseDecay[k] = stagedDecay[k]
        }
        releaseTime         = stagedRelease
        velocitySensitivity = stagedSensitivity
    }

    func prepare(sampleRate rate: Double) {
        sampleRate = rate
        silence()
    }

    // =====================================================================

    func noteOn(_ note: UInt8, velocity: UInt8) {
        let slot = freeSlot()
        let base = slot * Self.partials
        let frequency = 440 * pow(2, (Double(note) - 69) / 12)

        // Les aigus s'éteignent plus vite que les graves sur tout instrument à
        // cordes ou à lames : sans cette pente, le haut du clavier traîne et
        // sonne artificiel.
        let pitchFactor = min(2.0, max(0.25, pow(261.63 / frequency, 0.5)))

        for k in 0..<Self.partials {
            let f = frequency * ratio[k]
            // Repliement : un partiel au-dessus de Nyquist ne produirait qu'une
            // fréquence fantôme, plus basse et fausse. On l'éteint.
            if baseAmp[k] <= 0 || f >= sampleRate * 0.45 {
                amplitude[base + k] = 0
                increment[base + k] = 0
                decayCoef[base + k] = 1
                phase[base + k] = 0
                continue
            }
            amplitude[base + k] = baseAmp[k]
            increment[base + k] = f / sampleRate * Double(Self.tableSize)
            phase[base + k] = 0
            let seconds = max(baseDecay[k] * pitchFactor, 0.01)
            decayCoef[base + k] = exp(-6.9078 / (seconds * sampleRate))
        }

        let normalized = pow(Double(velocity) / 127, 1.5)
        gain[slot] = 0.75 + velocitySensitivity * (normalized - 0.75)

        // Rampe de deux millisecondes : la percussion reste franche, mais le
        // saut de zéro à pleine amplitude en un échantillon — qui s'entendrait
        // comme un claquement large bande — disparaît.
        attack[slot] = 0
        attackStep[slot] = 1 / (0.002 * sampleRate)

        releaseGain[slot] = 1
        releaseCoef[slot] = 1
        keyHeld[slot] = true
        counter &+= 1
        startedAt[slot] = counter
        noteOf[slot] = Int32(note)
    }

    func noteOff(_ note: UInt8) {
        for v in 0..<Self.maxVoices where noteOf[v] == Int32(note) && keyHeld[v] {
            keyHeld[v] = false
            if !sustainDown { beginRelease(v) }
        }
    }

    func sustain(_ down: Bool) {
        sustainDown = down
        guard !down else { return }
        for v in 0..<Self.maxVoices where noteOf[v] >= 0 && !keyHeld[v] {
            beginRelease(v)
        }
    }

    func silence() {
        sustainDown = false
        for v in 0..<Self.maxVoices {
            noteOf[v] = -1
            keyHeld[v] = false
            releaseGain[v] = 1
            releaseCoef[v] = 1
        }
    }

    // =====================================================================

    /// **Thread audio.** Ajoute la synthèse dans un tampon mono.
    func render(into out: UnsafeMutablePointer<Double>, frames: Int) -> Bool {
        var sounded = false

        for v in 0..<Self.maxVoices where noteOf[v] >= 0 {
            sounded = true
            let base = v * Self.partials
            var a = attack[v], r = releaseGain[v]
            let step = attackStep[v], rc = releaseCoef[v], g = gain[v]

            for f in 0..<frames {
                if a < 1 { a = min(1, a + step) }
                r *= rc

                var sample = 0.0
                for k in 0..<Self.partials {
                    let level = amplitude[base + k]
                    guard level > 1e-6 else { continue }
                    amplitude[base + k] = level * decayCoef[base + k]

                    var p = phase[base + k] + increment[base + k]
                    if p >= Double(Self.tableSize) { p -= Double(Self.tableSize) }
                    phase[base + k] = p

                    let index = Int(p)
                    let fraction = p - Double(index)
                    sample += level * (table[index]
                                       + (table[index + 1] - table[index]) * fraction)
                }
                out[f] += sample * g * a * r
            }

            attack[v] = a
            releaseGain[v] = r

            // Voix éteinte : soit le relâchement l'a ramenée sous le seuil
            // d'audibilité, soit tous ses partiels se sont tus d'eux-mêmes.
            if r < 1e-4 || isSpent(base) { noteOf[v] = -1 }
        }
        return sounded
    }

    // =====================================================================

    private func beginRelease(_ v: Int) {
        releaseCoef[v] = exp(-6.9078 / (max(releaseTime, 0.005) * sampleRate))
    }

    private func isSpent(_ base: Int) -> Bool {
        for k in 0..<Self.partials where amplitude[base + k] > 1e-6 { return false }
        return true
    }

    /// Voix libre, sinon la plus ancienne. Voler la plus ancienne plutôt que
    /// la plus faible évite de couper une note qu'on vient de jouer fort.
    private func freeSlot() -> Int {
        var oldest = 0, oldestAge = UInt64.max
        for v in 0..<Self.maxVoices {
            if noteOf[v] < 0 { return v }
            if startedAt[v] < oldestAge { oldestAge = startedAt[v]; oldest = v }
        }
        return oldest
    }
}
