import Foundation

/// Les cinq timbres de clic, inspirés du kit de percussions General MIDI. (EX-051)
///
/// Ils ne rejouent pas d'échantillons : chacun est synthétisé, ce qui évite
/// d'embarquer des fichiers et garantit une attaque exacte à l'échantillon près.
enum ClickVoice: Int, CaseIterable, Identifiable {
    case claves    = 0     // GM 75 — Claves
    case woodblock = 1     // GM 77 — Low Wood Block
    case click     = 2     // GM 33 — Metronome Click
    case hihat     = 3     // GM 42 — Closed Hi-Hat
    case kick      = 4     // GM 36 — Bass Drum 1

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .claves:    return String(localized: "Claves")
        case .woodblock: return String(localized: "Woodblock")
        case .click:     return String(localized: "Click")
        case .hihat:     return String(localized: "Hi-hat")
        case .kick:      return String(localized: "Kick drum")
        }
    }

    var hint: String {
        switch self {
        case .claves:    return String(localized: "The sharpest attack of the five. The best choice for fine work and for setting the alignment.")
        case .woodblock: return String(localized: "Deeper wood tone than the claves, less aggressive over time.")
        case .click:     return String(localized: "The classic metronome click. Neutral, gets a bit lost under a loudly played piano.")
        case .hihat:     return String(localized: "Unpitched noise: it never blends with any piano note.")
        case .kick:      return String(localized: "Felt more than heard. Its attack is perceived later than it actually occurs, so don't use it to set the alignment. Barely audible on the iPhone speaker, which doesn't reach low frequencies.")
        }
    }

    /// Durée du son, en secondes.
    var duration: Double {
        switch self {
        case .claves:    return 0.035
        case .woodblock: return 0.055
        case .click:     return 0.045
        case .hihat:     return 0.045
        case .kick:      return 0.180
        }
    }

    // =====================================================================

    /// Synthétise le timbre.
    func samples(rate: Double) -> [Float] {
        let count = max(1, Int(rate * duration))
        var out = [Float](repeating: 0, count: count)
        var noise = Noise(seed: 0x85EB_CA6B)

        switch self {

        case .claves:
            // Une sinusoïde fortement amortie : c'est physiquement ce qu'est
            // une paire de claves. Une pointe de bruit donne le « tock ».
            let frequency = 2500.0
            for i in 0..<count {
                let t = Double(i) / rate
                out[i] = Float(sin(2 * .pi * frequency * t) * exp(-95 * t)
                             + noise.next() * exp(-900 * t) * 0.5)
            }

        case .woodblock:
            let f1 = 900.0
            for i in 0..<count {
                let t = Double(i) / rate
                let body = (sin(2 * .pi * f1 * t) + 0.5 * sin(2 * .pi * f1 * 1.5 * t)) * exp(-62 * t)
                out[i] = Float(body + noise.next() * exp(-600 * t) * 0.4)
            }

        case .click:
            let frequency = 1050.0
            for i in 0..<count {
                let t = Double(i) / rate
                let square = sin(2 * .pi * frequency * t) >= 0 ? 1.0 : -1.0
                out[i] = Float(square * exp(-55 * t))
            }

        case .hihat:
            // Bruit passé en dérivée première : filtre passe-haut du pauvre,
            // largement suffisant pour un charleston fermé.
            var previous = 0.0
            for i in 0..<count {
                let t = Double(i) / rate
                let sample = noise.next()
                out[i] = Float((sample - previous) * exp(-115 * t))
                previous = sample
            }

        case .kick:
            // Balayage de hauteur : la fréquence descend vite vers le grave.
            // La phase doit être accumulée, pas recalculée à chaque échantillon.
            let start = 140.0
            var phase = 0.0
            for i in 0..<count {
                let t = Double(i) / rate
                phase += 2 * .pi * (45 + (start - 45) * exp(-38 * t)) / rate
                out[i] = Float(sin(phase) * exp(-17 * t) + noise.next() * exp(-1400 * t) * 0.25)
            }
        }

        // Sans cette normalisation, changer de timbre changerait le volume.
        var peak: Float = 0
        for value in out { peak = max(peak, abs(value)) }
        guard peak > 0.0001 else { return out }
        let factor = Float(0.72) / peak
        return out.map { $0 * factor }
    }
}

/// Générateur pseudo-aléatoire déterministe : deux lancements produisent
/// exactement le même clic.
private struct Noise {
    private var state: UInt32
    init(seed: UInt32) { state = seed | 1 }
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        return Double(state) / Double(UInt32.max) * 2 - 1
    }
}
