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
