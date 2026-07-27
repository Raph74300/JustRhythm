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
        case .claves:    return "Claves"
        case .woodblock: return "Woodblock"
        case .click:     return "Clic"
        case .hihat:     return "Charleston"
        case .kick:      return "Grosse caisse"
        }
    }

    var hint: String {
        switch self {
        case .claves:    return "L'attaque la plus nette des cinq. Le meilleur choix pour du travail fin et pour régler l'alignement."
        case .woodblock: return "Bois plus grave que les claves, moins agressif sur la durée."
        case .click:     return "Le clic de métronome classique. Neutre, se perd un peu dans un piano joué fort."
        case .hihat:     return "Bruit non accordé : ne se mélange à aucune note du piano."
        case .kick:      return "Se sent plus qu'il ne s'entend. Son attaque est perçue plus tard qu'elle ne survient : ne t'en sers pas pour régler l'alignement. Peu audible sur le haut-parleur de l'iPhone, qui ne descend pas dans le grave."
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

    /// Synthétise le timbre. `accent` monte la hauteur et le niveau. (EX-042)
    func samples(rate: Double, accent: Bool) -> [Float] {
        let count = max(1, Int(rate * duration))
        var out = [Float](repeating: 0, count: count)
        var noise = Noise(seed: accent ? 0x9E37_79B9 : 0x85EB_CA6B)

        switch self {

        case .claves:
            // Une sinusoïde fortement amortie : c'est physiquement ce qu'est
            // une paire de claves. Une pointe de bruit donne le « tock ».
            let frequency = accent ? 2800.0 : 2500.0
            for i in 0..<count {
                let t = Double(i) / rate
                out[i] = Float(sin(2 * .pi * frequency * t) * exp(-95 * t)
                             + noise.next() * exp(-900 * t) * 0.5)
            }

        case .woodblock:
            let f1 = accent ? 1200.0 : 900.0
            for i in 0..<count {
                let t = Double(i) / rate
                let body = (sin(2 * .pi * f1 * t) + 0.5 * sin(2 * .pi * f1 * 1.5 * t)) * exp(-62 * t)
                out[i] = Float(body + noise.next() * exp(-600 * t) * 0.4)
            }

        case .click:
            let frequency = accent ? 1600.0 : 1050.0
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
            let start = accent ? 170.0 : 140.0
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
        let factor = (accent ? Float(0.95) : Float(0.72)) / peak
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
