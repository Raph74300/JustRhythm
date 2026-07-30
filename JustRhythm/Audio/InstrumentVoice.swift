import Foundation

/// Le timbre avec lequel le téléphone sonorise les notes reçues. (EX-133)
///
/// Synthétisés, comme les clics, et pour une raison de plateforme : iOS ne
/// livre aucune banque sonore accessible à une application. Le fichier
/// `gs_instruments.dls` qu'on trouve partout cité est celui de macOS — au
/// simulateur il se charge, parce qu'une application du simulateur lit le
/// disque du Mac, et sur l'iPhone il n'existe pas. Embarquer une SoundFont
/// aurait coûté plusieurs mégaoctets et une licence à vérifier.
///
/// Chaque timbre est décrit par une poignée de partiels : un rapport de
/// fréquence à la fondamentale, une amplitude, un temps de décroissance. C'est
/// une description grossière d'un instrument réel, mais elle suffit ici — ce
/// qu'on écoute, c'est un placement d'attaque, pas une sonorité de concert.
enum InstrumentVoice: Int, CaseIterable, Identifiable {
    case piano         = 0
    case electricPiano = 1
    case harpsichord   = 2
    case guitar        = 3
    case marimba       = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .piano:         return String(localized: "Piano")
        case .electricPiano: return String(localized: "Electric piano")
        case .harpsichord:   return String(localized: "Harpsichord")
        case .guitar:        return String(localized: "Acoustic guitar")
        case .marimba:       return String(localized: "Marimba")
        }
    }

    // =====================================================================

    /// Nombre de partiels par voix. Fixe, parce que le rendu tourne sur le
    /// thread audio : aucune allocation n'y est permise.
    static let partialCount = 8

    /// Rapport de fréquence de chaque partiel à la fondamentale.
    ///
    /// Les cordes frappées ou pincées sont légèrement inharmoniques — la
    /// raideur de la corde pousse les partiels au-dessus des multiples
    /// exacts. Sans ce décalage le son est vitreux, avec il « sonne corde ».
    /// Les lames de marimba, elles, sont accordées exprès sur 4 et 9,2 :
    /// c'est ce rapport, et non la décroissance, qui fait le marimba.
    var ratios: [Double] {
        switch self {
        case .piano:
            return [1, 2.001, 3.005, 4.010, 5.017, 6.026, 7.036, 8.049]
        case .electricPiano:
            return [1, 2, 3, 4, 6, 8, 10, 14]
        case .harpsichord:
            return [1, 2, 3, 4, 5, 6, 7, 8]
        case .guitar:
            return [1, 2.001, 3.003, 4.006, 5.010, 6.015, 7.021, 8.028]
        case .marimba:
            return [1, 3.93, 9.20, 15.0, 0, 0, 0, 0]
        }
    }

    /// Amplitude de départ de chaque partiel. Un zéro éteint le partiel.
    var amplitudes: [Double] {
        switch self {
        case .piano:
            return [1.00, 0.55, 0.32, 0.18, 0.10, 0.060, 0.035, 0.020]
        case .electricPiano:
            // Le quatrième et le huitième portent la « tine » : c'est eux qui
            // font entendre un Rhodes plutôt qu'un orgue.
            return [1.00, 0.25, 0.08, 0.45, 0.12, 0.300, 0.050, 0.150]
        case .harpsichord:
            return [1.00, 0.80, 0.65, 0.50, 0.40, 0.300, 0.220, 0.160]
        case .guitar:
            return [1.00, 0.60, 0.40, 0.22, 0.14, 0.090, 0.050, 0.030]
        case .marimba:
            return [1.00, 0.35, 0.10, 0.03, 0, 0, 0, 0]
        }
    }

    /// Temps de décroissance de chaque partiel, en secondes, à la hauteur de
    /// référence. Les partiels aigus s'éteignent plus vite que la fondamentale
    /// dans tous les instruments réels : c'est ce qui fait qu'un son « se
    /// referme » au lieu de rester figé.
    var decays: [Double] {
        switch self {
        case .piano:
            return [3.0, 2.2, 1.7, 1.3, 1.0, 0.80, 0.60, 0.50]
        case .electricPiano:
            return [2.5, 1.5, 1.0, 0.7, 0.5, 0.25, 0.20, 0.12]
        case .harpsichord:
            return [1.2, 1.1, 1.0, 0.9, 0.8, 0.70, 0.60, 0.50]
        case .guitar:
            return [2.2, 1.6, 1.2, 0.9, 0.7, 0.55, 0.45, 0.35]
        case .marimba:
            return [0.55, 0.28, 0.15, 0.10, 0.1, 0.1, 0.1, 0.1]
        }
    }

    /// Ce que la vélocité change au niveau. Le clavecin pince la corde par un
    /// bec : la force de la frappe n'y fait presque rien, et le reproduire
    /// n'est pas une approximation mais une fidélité.
    var velocitySensitivity: Double {
        self == .harpsichord ? 0.15 : 1.0
    }

    /// Durée du relâchement après le lever de touche, en secondes. Le marimba
    /// n'a pas d'étouffoir : la lame finit sa course quoi qu'on fasse.
    var release: Double {
        switch self {
        case .marimba: return 0.40
        case .guitar:  return 0.12
        default:       return 0.08
        }
    }
}
