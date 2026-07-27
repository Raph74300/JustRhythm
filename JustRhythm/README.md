# JustRhythm — application iPhone

Entraînement à la précision rythmique au piano. Mesure l'écart, en
millisecondes, entre chaque note MIDI jouée et le battement du métronome.

Interface en style système, sans identité graphique propre.
Périmètre : **phases 1 et 2** du cahier des charges.

## Créer le projet

1. Xcode → **File › New › Project… › iOS › App**
2. Product Name : `JustRhythm` · Interface : **SwiftUI** · Language : **Swift**
3. Cible `JustRhythm` → onglet **General** :
   - Minimum Deployments : **iOS 17.0**
   - iPhone Orientation : **Portrait** seul
4. Supprimer le `ContentView.swift` créé par Xcode.
5. Glisser `Core`, `MIDI`, `Audio`, `Views` et `JustRhythmApp.swift`, en cochant
   **Copy items if needed**.
6. **Signing & Capabilities** → ajouter **Background Modes**, cocher
   *Audio, AirPlay, and Picture in Picture*.

Aucune clé de permission n'est requise : ni micro, ni Bluetooth, ni réseau.

## Les quatre noms à ne pas confondre

Renommer une application iOS touche des choses de nature différente. Elles sont
indépendantes, et il est normal qu'elles ne soient pas toutes identiques.

| Ce que c'est | Où ça se change | Qui le voit |
|---|---|---|
| Nom du projet et de la cible | Xcode, à la création | personne |
| `CFBundleName` | Info de la cible | personne |
| `CFBundleDisplayName` | Info de la cible | **l'utilisateur, sous l'icône** |
| Bundle Identifier | Signing & Capabilities | Apple, de façon définitive |

Le nom sous l'icône est `CFBundleDisplayName`. C'est le seul qui compte pour
l'utilisateur, et le seul qui peut contenir des espaces et des accents.

Le Bundle Identifier — de la forme `fr.monnom.justrhythm` — **ne se change plus**
une fois l'application publiée : c'est l'identité de l'app pour Apple. Choisis-le
bien avant la première soumission.

Le nom affiché sur l'App Store est encore autre chose : il se saisit dans App
Store Connect et peut différer du nom sous l'icône.

## Ce qui a été renommé dans le code

| Élément | Nature |
|---|---|
| `JustRhythmApp` | le type `@main` |
| `JustRhythmApp.swift` | le fichier correspondant |
| `"JustRhythm"` (client CoreMIDI) | visible dans les outils MIDI du système |
| `fr.justrhythm.scheduler` | file d'attente, visible au profilage |
| `domain: "JustRhythm"` | domaine des erreurs internes |
| Titre de la barre de navigation | visible par l'utilisateur |

## Note sur l'orthographe

« Rythm » n'existe ni en anglais (*rhythm*) ni en français (*rythme*). Pour une
publication sur l'App Store, cela nuit au référencement — personne ne cherche ce
mot — et donne une impression de négligence. Alternatives : **JustRhythm**,
**JustRhythme**, ou **Justesse**.

Le nom se change en quelques minutes tant que l'application n'est pas publiée.
Après, le Bundle Identifier est figé.

## Synchronisation sur le clavier (EX-053 / EX-054)

Deux interrupteurs, dans la section « Synchronisation » des réglages.

**Démarrage synchronisé** — le métronome part sur le message MIDI Start de la
boîte à rythmes du clavier, et la grille est ancrée exactement sur cet instant,
pas sur « maintenant plus un délai de confort ». Stop arrête, Continue relance.

**Suivre l'horloge** — le tempo se cale sur les 24 impulsions par noire du MIDI
Clock. Sans lui, le Start donne le départ mais pas le tempo : deux horloges à
80,0 et 80,3 bpm dérivent d'une seconde en trois minutes. La correction agit
séparément sur la période, lissée pour absorber la gigue, et sur la phase, par
un décalage d'ancrage borné à 20 ms — jamais de rupture de grille.

Quand l'horloge est suivie, l'écran affiche « bpm reçu » : c'est elle qui fait
foi, et non le tempo réglé dans l'application.

### Pourquoi c'est le meilleur moyen de régler l'alignement

Le son de la boîte à rythmes et celui des notes jouées sortent du **même
appareil, par le même chemin**, donc avec la même latence. Aligner à l'oreille
le clic de l'application sur celui de la boîte à rythmes annule la différence
entre les deux chaînes audio — ce que le curseur réglé à l'aveugle ne fait que
deviner.

Reste un résidu hors de portée : le temps de balayage du clavier entre
l'enfoncement de la touche et l'émission du note-on, de l'ordre de 3 à 10 ms.

## Ce qu'apporte la phase 2

| Exigence | Ce qui a été fait |
|---|---|
| EX-013 | La source enregistrée est privilégiée au démarrage : le clavier est retrouvé sans intervention. |
| EX-014 | La liste se met à jour à chaud. La disparition de la source active est signalée pendant une séance. |
| EX-017 | Canal MIDI écouté : tous, ou 1 à 16. |
| EX-018 | Seuil de vélocité minimale, pour ignorer les effleurements. |
| EX-036 | Regroupement d'accord dans une fenêtre réglable, daté sur la première note. Un accord apparaît plus haut sur le graphe. |
| EX-037 | Étalement du groupe affiché sous l'écart. |
| EX-041 | Grille réglable : noires, croches, triolets, doubles-croches. |
| EX-042 | Temps par mesure de 2 à 12, ou aucun accent. Le premier temps est marqué aux deux bords du graphe. |
| EX-050 | Interruptions audio écoutées : reprise automatique si le système l'autorise, arrêt signalé sinon. |
| EX-051 | Cinq timbres synthétisés, avec écoute au changement. |
| EX-067 | Échelle du graphe réglable de ±40 à ±300 ms. |
| EX-084 | Fenêtre statistique glissante, de 20 à 1000 notes. |

**EX-103** (démarrage rapide), **EX-122** et **EX-123** (publication) ne se
traduisent par aucun code : ce sont des propriétés à vérifier, pas des
fonctions à écrire.

**Reste en phase 3** : le clic sur les subdivisions (EX-044), le décompte
(EX-049), la vélocité sur le graphe (EX-065), la tendance glissante (EX-071,
EX-089), le résumé et l'historique de séance (EX-086 à EX-088).

Conséquence à connaître : la grille peut être en doubles-croches alors que le
clic ne sonne que sur les temps. C'est voulu — EX-041 est en phase 2, EX-044
en phase 3.

## Organisation des fichiers

| Fichier | Rôle |
|---|---|
| `Core/HostClock.swift` | Base de temps unique partagée par CoreMIDI et le moteur audio. |
| `Core/Settings.swift` | Réglages persistants, seuil de régularité. |
| `Core/RhythmEngine.swift` | Grille, calcul des écarts, statistiques. |
| `MIDI/MIDIManager.swift` | Sources, connexion à chaud, parsing, horodatage. |
| `Audio/ClickVoice.swift` | Les cinq timbres, synthétisés. |
| `Audio/MetronomeEngine.swift` | Clic à l'échantillon près, compensation de latence, interruptions. |
| `Views/Palette.swift` | Couleurs sémantiques du système. |
| `Views/ScopeView.swift` | Le graphe défilant. |
| `Views/MainView.swift` | Écran de mesure, transport, mode plein écran. |
| `Views/SettingsView.swift` | Feuille de réglages. |
