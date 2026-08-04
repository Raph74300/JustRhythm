import SwiftUI

/// Application couchée, toujours. (EX-138)
///
/// Plus d'`AppDelegate` ni de masque d'orientation variable : la version
/// précédente n'ouvrait le paysage qu'au mode plein écran et devait donc en
/// changer à l'exécution, ce que ni le réglage du projet ni SwiftUI ne savent
/// faire. Une application entièrement en paysage se déclare dans le projet, en
/// une ligne, et tout le mécanisme tombe.
@main
struct JustRhythmApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
