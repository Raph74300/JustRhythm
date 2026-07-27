# Parcours de construction — JustRhythm

Construction depuis un projet Xcode vide jusqu'à l'application décrite dans le
cahier des charges natif.

**Règle de découpage** : chaque étape se termine par quelque chose qui se lance
et qui se voit ou s'entend. Jamais une étape qui ne produit qu'un fichier de
plus.

**Cible** : iOS 17, SwiftUI, iPhone en portrait, aucune bibliothèque tierce,
interface en vocabulaire système.

**Périmètre** : uniquement les exigences en **phase 1** du cahier des charges.
Les phases 2 et 3 ne sont pas abandonnées — elles viendront après, une fois le
socle en place. Si une demande sort de la phase 1 en cours de route, signale-le
et propose de la reporter plutôt que de l'intégrer.

**Charge estimée** : une vingtaine d'heures, quatorze étapes, une dizaine de
séances. Le temps ne part pas où on l'imagine : environ un quart à écrire du
code, un tiers à comprendre quand et pourquoi SwiftUI redessine une vue, un
quart à lire des erreurs, le reste en friction Xcode.

**Ce qui se tape et ce qui se colle.** Raphaël tape à la main tout ce qui
manipule une horloge, un pointeur, un thread ou une conversion d'unité : c'est
là qu'est la matière et là que les erreurs coûtent cher. Il colle et relit ce
qui n'est que mise en page. Quand tu donnes du code, dis à quelle catégorie il
appartient. En clair — **à taper** : `HostClock`, le callback de rendu du
métronome, la boucle de parsing MIDI, le cœur du moteur de rythme, la fonction
de dessin du graphe. **À coller** : `Palette`, `SettingsView`, la mise en page
de `MainView`.

**Simulateur d'abord.** Compiler vers le simulateur ne consomme aucun jeton
d'App ID et va plus vite. Le téléphone n'est nécessaire qu'aux étapes 6 et 9 —
le MIDI et la latence de sortie n'existent pas au simulateur — et à l'étape 13.

**Un commit par étape.** Relire une différence est plus instructif que relire un
fichier.

---

## Étape 0 — Le projet vide qui tourne sur le téléphone

Créer le projet, régler la cible, choisir le Bundle Identifier **définitivement**,
installer sur l'iPhone.

Points à couvrir : le rôle du fichier `@main`, ce qu'est une cible, la
convention DNS inversée du Bundle Identifier, la signature avec un compte
gratuit, l'expiration à sept jours et le quota de 10 App IDs.

**Fini quand** : un écran vide s'affiche sur le téléphone, sous le bon nom.

## Étape 1 — Le vocabulaire visuel du système

`Palette.swift` : les couleurs sémantiques d'Apple, et rien d'autre.
Un `NavigationStack` avec un titre, un bouton d'engrenage dans la barre, une
carte sur fond groupé.

Points à couvrir : `View` et `body`, la composition par empilement, les
modificateurs et pourquoi leur ordre compte, `#Preview` et le canvas, les
couleurs sémantiques et pourquoi elles battent une palette figée — elles
suivent seules le thème clair et sombre, le contraste renforcé et les réglages
d'accessibilité. (EX-110 à EX-113)

**Fini quand** : l'écran est correct dans les deux thèmes, sans une seule
couleur codée en dur.

## Étape 2 — L'horloge

`HostClock.swift`. Toute l'application repose sur une base de temps unique :
`mach_absolute_time`, convertie en secondes via `mach_timebase_info`.

Points à couvrir : pourquoi pas `Date` (l'heure murale saute), pourquoi pas
`Timer` (dérive et imprécision), ce qu'est une horloge monotone. Terrain connu
côté embarqué, vocabulaire Apple à apprendre. (EX-030)

**Fini quand** : un compteur de secondes s'affiche et avance.

## Étape 3 — Faire un son

`AVAudioEngine` et `AVAudioSourceNode`. Un callback de rendu qui synthétise un
bip. C'est l'étape la plus dure du parcours, et la fondation de tout le reste.

Points à couvrir : la session audio et ses catégories, `.playback` et
l'interrupteur silence, `.mixWithOthers`, le format d'échantillon, ce qu'est un
thread temps réel audio et ce qu'on n'a pas le droit d'y faire.

**Décision déjà tranchée** : ne pas utiliser `AVAudioPlayerNode.scheduleBuffer`.
Son horloge `lastRenderTime` n'existe qu'une fois le nœud en train de rendre, et
il ne rend que si un buffer lui a été programmé — blocage circulaire. Il décroche
en outre entre deux clics espacés.

**Fini quand** : un bouton produit un bip.

## Étape 4 — Le métronome

Grille de temps ancrée sur l'horloge host, ordonnanceur périodique qui remplit
une file en avance, clic à intervalle régulier.

Points à couvrir : pourquoi l'ordonnanceur ne détermine jamais la date de
restitution, le compteur d'échantillons absolu, la conversion instant host vers
position d'échantillon, le verrouillage minimal entre thread audio et thread
principal. (EX-047)

**Phase 1 : la noire seulement.** Pas de subdivisions, pas d'accent de mesure,
pas de décompte, pas de choix de timbre.

**Fini quand** : le métronome bat juste et ne dérive pas sur dix minutes.

## Étape 5 — Les réglages persistants

`Settings.swift` avec `@Observable` et `UserDefaults`. Le tempo, le clic, le
volume, tous restaurés au lancement.

Points à couvrir : `@Observable` contre `ObservableObject`, `@State`, `Binding`,
`didSet` et le fait qu'il ne se déclenche pas pendant l'initialisation. (EX-093)

**Piège rencontré** : une fonction locale à `init()` qui lit une propriété de
l'instance capture implicitement `self`, ce que Swift interdit avant la fin de
l'initialisation. Solution : méthodes statiques.

**Règle des trois endroits** : chaque réglage vit dans la déclaration `var`,
dans `init()`, et dans l'énumération des clés. En oublier un donne un « Cannot
find in scope » signalé au mauvais endroit.

**Fini quand** : le tempo choisi est restauré au relancement.

## Étape 6 — Lire le clavier MIDI

`CoreMIDI` : client, port d'entrée, énumération des sources, connexion.
Première étape qui exige le téléphone.

Points à couvrir : l'API C importée dans Swift, `MIDIPacketList.unsafeSequence()`,
le parcours des octets, le *running status*, l'horodatage du paquet et pourquoi
il ne faut jamais utiliser l'instant de traitement. (EX-016, EX-030)

**Phase 1 : USB seulement.** Pas d'appairage Bluetooth, pas de reconnexion
automatique, pas de filtre par canal ni par vélocité. Une source, choisie dans
une liste. Un avertissement suffit si la source active est en Bluetooth
(EX-020).

**Fini quand** : le nom de la dernière note jouée s'affiche, métronome à
l'arrêt.

## Étape 7 — La mesure

Point de grille le plus proche, écart signé, affichage en millisecondes.

Points à couvrir : la convention de signe, pourquoi l'écart ne peut pas dépasser
une demi-période, la différence entre exactitude et fidélité. (EX-032, EX-033)

**Phase 1 : une note, un événement.** Le regroupement d'accords est en phase 2.

**Fini quand** : jouer une note affiche son écart au temps.

## Étape 8 — Le graphe

`Canvas` dans un `TimelineView`. Le fil à plomb central, le temps qui descend,
une barre par note, la bande de tolérance.

**Piège rencontré, majeur** : `now` doit être calculé **hors** du `Canvas`, à
partir de `timeline.date`. Si le contenu ne dépend pas de la date fournie par la
timeline, SwiftUI le juge invariant et ne le redessine qu'au gré des autres
changements d'état — soit une image par temps. Aucun avertissement du
compilateur. (EX-069)

Points à couvrir : le coût par image, pourquoi `filter().last` est à proscrire
dans une boucle de rendu, et pourquoi la direction de l'écart doit se lire à la
position et non à la couleur (EX-117).

**Fini quand** : le défilement est fluide et les notes se posent au bon endroit.

## Étape 9 — La latence de sortie

Compenser `outputLatency + ioBufferDuration` pour que le clic soit *entendu* sur
le temps, plus un réglage manuel d'appoint. Deuxième étape qui exige le
téléphone.

Points à couvrir : la chaîne complète des retards, pourquoi on ne peut pas
calibrer sur son propre ressenti — l'asynchronie négative moyenne fait qu'on
anticipe de 10 à 20 ms — et le protocole de vérification au micro externe.
(EX-034, EX-035, EX-038)

**Fini quand** : la moyenne est proche de zéro quand on joue délibérément juste.

## Étape 10 — Les statistiques

Nombre de notes, moyenne de séance, écart-type, pourcentage dans la zone.

Points à couvrir : biais contre dispersion et pourquoi ils ne se corrigent pas
pareil, l'insensibilité de l'écart-type à l'erreur de calibration, la
normalisation en pourcentage de l'intervalle et son plancher, le code couleur.
(EX-080 à EX-083)

**Phase 1 : séance entière.** La fenêtre glissante est en phase 2, la moyenne
glissante courte en phase 3.

**Fini quand** : les quatre chiffres sont justes et le code couleur fonctionne.

## Étape 11 — La feuille de réglages

`SettingsView` : un `Form` présenté en feuille modale depuis le bouton
d'engrenage. Clavier, alignement, tolérance, effacement des statistiques.

Points à couvrir : le partage entre ce qu'on touche en jouant — tempo, clic,
volume, qui restent sur l'écran de mesure — et ce qu'on fixe une fois. Les
sections d'un `Form`, leurs en-têtes et leurs notes de bas de section, où vont
les explications. Le réancrage de la grille au changement de tempo. (EX-096,
EX-097, EX-048)

**Fini quand** : tous les réglages de phase 1 sont accessibles et mémorisés.

## Étape 12 — Le mode plein écran

Masquer réglages, statistiques et barre d'état. Une seule vue de mesure
partagée entre les deux modes, jamais deux implémentations. (EX-072)

**Fini quand** : un appui sur le graphe bascule dans les deux sens, et le
bouton marche/arrêt reste atteignable.

## Étape 13 — L'icône et l'installation

Icône 1024×1024, sans canal alpha, coins carrés — iOS applique son propre
masque, une squircle qui rogne plus qu'on ne l'imagine. Installation sur le
téléphone. (EX-120, EX-121)

**Fini quand** : l'application est sur l'écran d'accueil sous son nom et son
icône.

---

## Phase 2 — après, pas pendant

| Sujet | Exigences |
|---|---|
| Reconnexion, débranchement à chaud, canal, vélocité | EX-013, 014, 017, 018 |
| Regroupement d'accords et étalement | EX-036, 037 |
| Subdivisions, temps par mesure, interruptions audio | EX-041, 042, 050 |
| Les cinq timbres de clic | EX-051 |
| Échelle du graphe réglable | EX-067 |
| Fenêtre statistique glissante | EX-084 |
| Démarrage rapide, revue App Store, fiche de collecte | EX-103, 122, 123 |

## Phase 3 — plus tard encore

| Sujet | Exigences |
|---|---|
| Bluetooth et MIDI réseau, appairage intégré | EX-011, 015 |
| Clic sur les subdivisions, décompte | EX-044, 049 |
| Vélocité et tendance sur le graphe | EX-065, 071 |
| Moyenne glissante courte | EX-089 |
| Résumé, historique, export | EX-086, 087, 088 |
| Consommation batterie, politique de confidentialité | EX-101, 124 |

Si Raphaël demande une de ces fonctions en cours de parcours, rappelle-lui sa
phase et propose de la noter pour plus tard. S'il insiste, fais-la — mais dis
ce qu'elle ajoute au temps de l'étape en cours.

---

## Décisions déjà tranchées — ne pas les rejouer

| Sujet | Décision |
|---|---|
| Identité graphique propre | Abandonnée. Vocabulaire visuel du système uniquement : couleurs sémantiques, typographie et icônes d'Apple, contrôles standard. |
| Entrée micro | Écartée. Latence d'entrée inconnue de 20 à 80 ms, qui fausse la grandeur mesurée. |
| Web / navigateur | Écarté. Safari sur iOS n'implémente pas Web MIDI. |
| `AVAudioPlayerNode` | Écarté au profit d'`AVAudioSourceNode`. Blocage circulaire de `lastRenderTime`. |
| Bluetooth MIDI | Toléré, mais avertissement à l'écran : 10 à 20 ms et gigue variable. |
| Calibration sur le ressenti | Proscrite. On anticipe de 10 à 20 ms ; calibrer ainsi inscrit son propre défaut dans le zéro de l'appareil. |
| Vibration sur note juste | Écartée. La justesse rythmique est une perception auditive ; une vibration binaire n'apporte rien. |
| Portrait inversé | Écarté. iOS le refuse sur les iPhone à Face ID, et la rotation logicielle ne fait pas tourner les menus système. |
| Pédale de sustain | Ignorée (CC64). Hors périmètre. |
| Échecs silencieux | Proscrits. Tout chemin d'erreur remonte un message à l'écran ; un bouton de test par sous-système. |
