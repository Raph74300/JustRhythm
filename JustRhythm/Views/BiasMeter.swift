import SwiftUI

/// Lecture instantanée du placement, façon accordeur. (EX-066 / EX-089)
///
/// Trois voyants seulement : un triangle de chaque côté et une barre centrale.
/// La barre ne s'allume que lorsque la fourchette des dernières notes tient
/// entière dans la zone juste — c'est ce qui fait la lisibilité d'un
/// accordeur, où le centre récompense la cible atteinte plutôt que de rester
/// allumé en permanence.
///
/// Les deux triangles s'allument indépendamment, et c'est tout l'intérêt : un
/// décalage systématique n'en allume qu'un, un jeu irrégulier les allume tous
/// les deux. La moyenne seule ne les distinguerait pas — les avances y
/// annulent les retards.
///
/// Une version à neuf barres, graduées par tranches d'une zone juste, a été
/// essayée puis abandonnée : la largeur d'une tranche valant deux fois la
/// tolérance, un réglage généreux rendait six barres inatteignables.
struct BiasMeter: View {

    /// Fourchette des derniers écarts. `nil` tant qu'aucune note n'a été
    /// mesurée.
    let placement: Placement?
    /// Demi-largeur de la zone juste, en secondes.
    let tolerance: Double

    private static let height: CGFloat = 36

    var body: some View {
        HStack(spacing: 16) {
            triangle("arrowtriangle.left.fill", lit: isEarly)

            Capsule()
                .fill(Palette.onTime.opacity(isOnTime ? 1 : Self.dimmed))
                .frame(width: 10, height: Self.height)

            triangle("arrowtriangle.right.fill", lit: isLate)
        }
        .frame(height: Self.height)
        .animation(.easeOut(duration: 0.25), value: placement)
        // Le verdict et les valeurs chiffrées, juste en dessous, disent déjà
        // tout ce que ces voyants montrent.
        .accessibilityHidden(true)
    }

    // =====================================================================

    /// Les voyants éteints restent visibles : sans eux, on ne saurait pas où
    /// se trouve la cible tant qu'aucune note n'a été jouée.
    private static let dimmed: Double = 0.22

    private func triangle(_ symbol: String, lit: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 22))
            .foregroundStyle(Palette.offTime.opacity(lit ? 1 : Self.dimmed))
    }

    /// Les trois états s'excluent proprement : si la fourchette tient dans la
    /// zone, aucun triangle ne s'allume ; sinon, au moins un s'allume
    /// nécessairement. Aucun cas ne laisse les trois voyants éteints une fois
    /// la première note jouée.
    private var isOnTime: Bool {
        guard let placement else { return false }
        return placement.isWithin(tolerance)
    }

    private var isEarly: Bool {
        guard let placement else { return false }
        return placement.mean - placement.deviation < -tolerance
    }

    private var isLate: Bool {
        guard let placement else { return false }
        return placement.mean + placement.deviation > tolerance
    }
}

#Preview {
    VStack(spacing: 28) {
        // Aucune note.
        BiasMeter(placement: nil, tolerance: 0.020)
        // Jeu juste : le centre seul.
        BiasMeter(placement: Placement(mean: 0.003, deviation: 0.008), tolerance: 0.020)
        // Retard systématique : le triangle droit.
        BiasMeter(placement: Placement(mean: 0.055, deviation: 0.010), tolerance: 0.020)
        // Avance systématique : le triangle gauche.
        BiasMeter(placement: Placement(mean: -0.055, deviation: 0.010), tolerance: 0.020)
        // Irrégulier mais centré : les deux triangles.
        BiasMeter(placement: Placement(mean: -0.005, deviation: 0.060), tolerance: 0.020)
    }
    .padding()
}
