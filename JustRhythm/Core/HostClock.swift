import Foundation

/// Base de temps unique de l'application.
///
/// CoreMIDI horodate ses paquets en `mach_absolute_time`, et AVAudioEngine
/// expose lui aussi un `hostTime` dans la même base. Tout ce qui touche à la
/// mesure passe donc par ici, converti en secondes, pour qu'aucune conversion
/// implicite ne s'installe entre les deux mondes. (EX-030)
enum HostClock {

    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Convertit des ticks host en secondes.
    static func seconds(_ ticks: UInt64) -> Double {
        Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }

    /// Convertit des secondes en ticks host.
    static func ticks(_ seconds: Double) -> UInt64 {
        UInt64(max(0, seconds) * 1_000_000_000 * Double(timebase.denom) / Double(timebase.numer))
    }

    /// Instant courant, en secondes.
    static var now: Double {
        seconds(mach_absolute_time())
    }

    /// Ancrage entre l'horloge murale — celle que fournit `TimelineView` —
    /// et l'horloge host. Établi une seule fois, au premier accès.
    private static let bridge: (date: Date, host: Double) = (Date(), now)

    /// Convertit une date de `TimelineView` en temps host.
    ///
    /// Utiliser la date de présentation de l'image plutôt que l'heure courante
    /// donne un défilement parfaitement régulier : c'est l'instant où l'image
    /// sera réellement affichée, pas celui où on la calcule.
    static func hostTime(for date: Date) -> Double {
        let projected = bridge.host + date.timeIntervalSince(bridge.date)
        let actual = now
        // Garde-fou : si l'horloge murale saute (ajustement réseau), on
        // retombe sur l'horloge host plutôt que d'afficher un bond.
        return abs(projected - actual) < 0.5 ? projected : actual
    }
}
