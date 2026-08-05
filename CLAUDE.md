# JustRhythm — notes pour Claude Code

App iPhone native (SwiftUI, iOS 17+) de mesure de précision rythmique au
piano via MIDI. Le vrai cahier des charges vit dans
`JustRhythm/Tutorial/cahier-des-charges-just-rhythm-natif.xlsx` — le lire
avant de proposer une fonction, pas après.

## Cahier des charges (xlsx)

Quatre onglets :
- **Contexte** — besoin, principe d'affichage, journal des versions. Bumper
  la version et ajouter une ligne au journal à chaque évolution notable.
- **Exigences** — une ligne par besoin : `ID` (`EX-NNN`), `Thème`,
  `Exigence`, `Critère d'acceptation`, `Priorité` (Indispensable / Important
  / Souhaitable), `Réglage / valeur`, `Phase` (1 = à construire, 2/3 =
  reporté mais valide), `Mes notes`.
- **Paramètres** — chaque réglage utilisateur avec sa valeur par défaut, ses
  bornes, et l'exigence qui le justifie.
- **Risques et décisions** — le *pourquoi* des choix, y compris ceux
  abandonnés après essai. À alimenter à chaque décision non triviale, pas
  seulement les succès.

Édité avec `openpyxl` (pas d'app Excel/Numbers dispo dans l'environnement).
`recalc.py` du skill xlsx ne fonctionne pas ici — LibreOffice n'est pas
installé sur cette machine ; les formules `COUNTIFS` se recalculent seules à
l'ouverture dans Excel, ce n'est pas bloquant.

**Chaque exigence non triviale implémentée doit porter son numéro en
commentaire dans le code** (`// (EX-053)`), et inversement toute fonction
significative doit avoir sa ligne dans `Exigences`. C'est la règle la plus
importante de ce projet — elle est ce qui permet de savoir, six mois plus
tard, pourquoi un bout de code existe.

## Conventions

- **Bundle ID** : `dev.oundjian.nomdelapp`, explicite, jamais de wildcard.
  Même convention pour toutes les prochaines apps sous ce compte développeur.
- **Localisation** : anglais = langue source (les chaînes dans le code sont
  déjà en anglais), français traduit dans `Localizable.xcstrings` (String
  Catalog). Ne jamais coder une chaîne visible directement en français.
- **Docs de référence** dans `JustRhythm/Tutorial/` : guide de publication
  App Store, manuel utilisateur, parcours d'apprentissage d'origine. Le
  cahier des charges, lui, vit à la racine de `JustRhythm/` (pas dans
  `Tutorial/`) — choix délibéré du développeur, ne pas le redéplacer.

## Git

- **Ne jamais commit ni push sans demande explicite.** Ce projet a une
  longue habitude de "je fais les changements, je décris ce qui a changé,
  j'attends le feu vert" — même après plusieurs tours de modifications
  accumulées.
- Avant un `git add -A`, vérifier `git status` : Xcode modifie parfois
  `project.pbxproj` tout seul pendant une session (build number, capacités) —
  ces changements sont légitimes, ne pas les écraser.
- Toujours `xcodebuild -scheme JustRhythm -sdk iphonesimulator build` après
  une modification de code, avant de considérer une tâche terminée.

## Matériel de référence

Tout ce qui a été mesuré l'a été sur un **Yamaha CVP-303 en USB**. Ces
valeurs sont celles de ce clavier, pas des constantes :

- **Correction manuelle : −20 ms**, étalonnée en jouant un fichier MIDI
  quantifié depuis le séquenceur du clavier (protocole décrit dans les
  Réglages). Elle compense un décalage interne au CVP entre son horloge et
  ses notes : les messages temps réel sont prioritaires dans sa file de
  sortie, les notes passent derrière. Un autre clavier donnera autre chose.
- **Gigue résiduelle du transport : 1 à 2 ms**, une fois synchronisé.
- Un résidu **n'est pas** compensé : le balayage des touches, absent quand le
  séquenceur joue mais présent quand l'instrumentiste joue. Quelques ms,
  hors de portée sans instrumentation externe.

## Orientation et disposition

Depuis la 2.8 l'application est **entièrement en paysage**, réglages compris —
un câble, même coudé, bute contre le pupitre quand le téléphone est debout. Cela
se déclare en une ligne dans le projet (`INFOPLIST_KEY_UISupportedInterfaceOrientations`) ;
il n'y a ni `AppDelegate` ni masque d'orientation variable, et la tentative
précédente qui n'ouvrait le paysage qu'au plein écran est tracée dans les
décisions. L'écran de mesure est en deux colonnes, deux tiers / un tiers, sans
`NavigationStack` : sa barre coûtait 44 des quelque 400 points de hauteur.

**La hauteur est la dimension rare, la largeur celle qui porte la mesure.** Toute
proposition d'ajout à cet écran se juge d'abord là-dessus.

## Pistes ouvertes

Décisions prises mais pas encore appliquées, ou options écartées qui restent
rouvrables — à ne pas reproposer comme des nouveautés :

- **Numéro de build** : à incrémenter avant chaque archive TestFlight. Apple
  refuse un couple version + build déjà envoyé.
- **Tolérance réglée haut** (~12-15 %) sur l'appareil du développeur. À 5 %
  le retour serait nettement plus discriminant ; recommandé, pas encore fait.
- **« Network Session 1 » résiduelle** dans la liste des sources : vestige
  système d'un Network MIDI abandonné, plus aucun code dans l'app. Se
  désactive côté Mac (Configuration audio et MIDI → Réseau). Le correctif du
  repli de source la rend inoffensive ; le nettoyage reste à faire.
- **Options écartées, rouvrables** : afficher le seuil dans la légende de
  Dispersion (`5,3 % / limite 5 %`) pour expliquer l'orange. Ne pas reproposer
  les voyants d'accordeur : essayés, puis retirés en 2.8 au profit du mot seul.
- **Export des données** (EX-088) : toujours ouvert, et c'est devenu le point
  de rendez-vous du reste. Les statistiques (EX-080 à EX-083, EX-085) et la
  fenêtre statistique (EX-084) sont passées en phase 2 et ne s'affichent plus
  nulle part : le moteur les calcule toujours, elles reviendront là.
- **Publication** : rien n'est publié. La 1.0 n'a jamais été validée et sa
  demande a été retirée — l'application avait trop changé. La 2.8 sera donc une
  **première** soumission, pas une mise à jour : le champ « Nouveautés »
  n'existe pas, seule la Description compte. Le numéro de build continue
  néanmoins de ne pouvoir que croître, des builds ayant déjà été envoyés.
- **Captures de l'App Store** : refaites en paysage pour la 2.8, conformées en
  6,9" et 6,5" dans `AppStore-Ready/conformes/`. Reste à flouter
  « CVP-303 Port 1 », visible sur deux des trois.

## Reprendre après une perte de contexte

Dans l'ordre : `CLAUDE.md`, l'onglet **Risques et décisions** du cahier des
charges (le *pourquoi* de tout ce qui a été tranché, y compris les fausses
pistes), puis `git log` dont les messages portent le raisonnement. Le reste
se relit dans le code, qui référence ses exigences.
