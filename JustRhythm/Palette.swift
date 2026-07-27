import SwiftUI

/// Aucune couleur inventée.
///
/// Tout vient des couleurs sémantiques d'Apple, qui s'adaptent seules au thème
/// clair et sombre, au contraste renforcé et au daltonisme réglé dans iOS.
/// C'est ce qui fait qu'une application « a l'air d'iOS » plutôt que d'avoir
/// une identité graphique plaquée par-dessus.
enum Palette {

    /// Dans la tolérance.
    static let onTime = Color.green
    /// Hors tolérance. La *direction* est donnée par la position sur le graphe,
    /// jamais par la couleur seule : un seul ton suffit donc, et l'affichage
    /// reste lisible en cas de daltonisme. (EX-064)
    static let offTime = Color.orange

    static func tint(for delta: Double, tolerance: Double) -> Color {
        abs(delta) <= tolerance ? onTime : offTime
    }

    /// Grille et repères secondaires du graphe.
    static let grid = Color(uiColor: .separator)
    static let beatLine = Color(uiColor: .tertiaryLabel)
    static let plumb = Color(uiColor: .label)
}
