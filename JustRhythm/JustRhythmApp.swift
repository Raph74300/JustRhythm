import SwiftUI
import UIKit

@main
struct JustRhythmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

/// Seul rôle : répondre à iOS sur les orientations acceptées. (EX-136)
///
/// SwiftUI n'expose rien d'équivalent, et le réglage du projet ne sait dire
/// qu'une chose valable pour toute la durée de vie de l'application. Or ici
/// l'orientation dépend du mode d'affichage.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Orientation.allowed
    }
}

/// Portrait par défaut, paysage en plein écran seulement. (EX-136)
///
/// La disposition standard ne peut pas être couchée : un graphe de 300 points,
/// la rangée de statistiques et tout le transport ne tiennent pas dans les
/// 390 à 430 points de hauteur d'un écran en travers. Le mode plein écran,
/// lui, n'affiche que le graphe — et c'est justement celui qu'on veut poser en
/// largeur sur le pupitre. Le `Canvas` se dessine à partir de la taille qu'on
/// lui donne : la vue de mesure n'a rien à changer pour l'occuper. (EX-072)
@MainActor
enum Orientation {

    /// Lue par `AppDelegate` à chaque fois qu'iOS redemande ce qui est permis.
    fileprivate(set) static var allowed: UIInterfaceOrientationMask = .portrait

    /// Rend la main à l'accéléromètre, dans les limites données.
    static func allow(_ mask: UIInterfaceOrientationMask) {
        allowed = mask
        scene?.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    /// Impose une orientation et l'y maintient.
    ///
    /// Le verrouillage n'est pas une précaution : sans lui la demande ne
    /// tiendrait pas, iOS réévaluant l'orientation au premier mouvement du
    /// téléphone pour revenir à celle du boîtier. C'est aussi le seul chemin
    /// qui fonctionne quand le verrou de rotation du système est actif — un
    /// état très courant, et qui rendrait autrement le paysage inatteignable
    /// quoi qu'on déclare dans le projet.
    static func pin(_ mask: UIInterfaceOrientationMask) {
        allow(mask)
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    }

    private static var scene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}
