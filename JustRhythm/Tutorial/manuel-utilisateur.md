# JustRhythm — Manuel d'utilisation

JustRhythm mesure la précision de ton placement rythmique. Branche un clavier MIDI, lance le métronome, et chaque note jouée est mesurée par rapport au temps — en millisecondes, pas en « à peu près ».

> Version française du manuel. Le fichier `user-manual.md`, à côté, en est l'équivalent anglais : toute correction apportée ici est à reporter là-bas.

---

## 1. Ce qu'il faut

- Un iPhone sous iOS 17 ou plus récent
- Un clavier MIDI, branché de l'une ou l'autre façon :
  - **USB** — filaire, le plus précis, sans latence ajoutée
  - **Bluetooth** — un clavier déjà appairé dans les réglages iOS apparaît tout seul ; ajoute 10 à 20 ms de gigue variable (voir §3)

L'application s'utilise **couchée**, dans un sens ou dans l'autre : le câble sort alors sur le côté au lieu de buter contre le pupitre. Il n'y a pas de mode portrait.

Aucune permission micro n'est jamais demandée. JustRhythm n'écoute que le MIDI.

---

## 2. Prise en main

1. Branche le clavier. Ouvre JustRhythm — l'application retient le dernier clavier utilisé et s'y reconnecte seule au lancement suivant.
2. Joue une note. Son nom (« Do4 » par exemple) doit apparaître dans le bandeau de droite : c'est la confirmation que la liaison fonctionne, avant même d'avoir appuyé sur Démarrer.
3. Touche **Démarrer** pour lancer le métronome. Joue : chaque note est jugée à l'instant où elle survient.
4. Touche **Arrêter** pour clore la séance.

---

## 3. L'écran principal

L'écran se lit en deux colonnes : le graphe occupe les deux tiers de gauche, et le tiers de droite porte tout ce qu'on touche en jouant.

**Lecture instantanée (au-dessus du graphe).** Un mot, et lui seul — *dans le temps*, *en avance*, *en retard*, *irrégulier*. Il est centré sur la ligne verticale du graphe, juste en dessous : les deux disent la même chose sur le même axe. Vert quand tu es dans la zone, orange sinon, la couleur ne faisant que doubler le mot.

*Irrégulier* est le mot qu'il faut comprendre : il veut dire centré en moyenne mais dispersé autour du temps. C'est pour lui que la lecture suit une *fourchette* et non une simple moyenne. Une moyenne seule le masquerait — une note 40 ms en avance et une 40 ms en retard s'annulent, et l'application déclarerait parfait un jeu approximatif. Ce que le mot reflète, c'est la plage où tombent réellement tes notes récentes : son centre *et* sa largeur. Et elle porte sur tes **16 dernières notes**, non sur la dernière : l'écart d'une note isolée saute trop d'une frappe à l'autre pour qu'on puisse se corriger dessus — on courrait après du bruit.

Rien d'autre à cet endroit, et pas un chiffre : ce qu'on regarde en jouant doit se lire sans être lu.

**Le graphe.** Une ligne verticale centrale représente le temps. Le défilement va du haut vers le bas : les événements les plus récents sont en haut, et s'estompent en descendant. Chaque note apparaît sous forme de barre : sur la ligne si tu étais pile, à gauche en avance, à droite en retard.

Sa largeur vaut **un temps, toujours** — quelle que soit la subdivision. C'est ce qui en fait une règle plutôt qu'une loupe : deux séances se comparent, et tu n'as aucun réglage d'échelle à surveiller.

Trois teintes, du dehors vers le dedans :

- **Gris — hors d'atteinte.** Aucune note ne peut y tomber : au-delà, elle appartiendrait au pas de grille suivant. La part de gris te dit donc, d'un coup d'œil, à quel point la grille que tu as choisie est exigeante. Aucune en noires, les trois quarts de la largeur en doubles-croches.
- **Orangé — mesurable, hors zone.** C'est la plage que ta grille sait juger.
- **Vert — la zone « juste ».** Sa largeur suit ton réglage de tolérance, et le pourcentage rappelé sur la règle, entre les pictogrammes, en donne la valeur.

Un filet marque chaque frontière, pour que l'information ne repose pas sur la couleur seule.

En bas, une **règle en valeurs de note** : la demi-largeur vaut une croche, le quart une double-croche, le huitième une triple-croche. Tu lis donc ton écart en musique — « en retard d'une double-croche » — et non en millisecondes. En triolets, les repères passent au tiers et au sixième de temps, marqués d'un 3. Ceux qui tombent dans le gris sont estompés : ils existent, mais ta grille ne peut pas les atteindre.

**Touche le graphe** pour passer en plein écran : le bandeau s'efface et le graphe prend toute la largeur, jusque sous l'encoche. Le tempo et **Démarrer / Arrêter** restent en bas à droite, sous le pouce. Touche à nouveau pour revenir.

Chaque note est mesurée pour elle-même : il n'y a pas de regroupement d'accord. Les notes d'un accord apparaissent donc séparément, et c'est voulu — tu vois du même coup si l'accord est *ensemble*, ce qu'un regroupement masquerait. Cela évite aussi qu'un legato un peu chevauchant se fasse avaler.

**Le bandeau de droite** porte, de haut en bas :
- Le nom du clavier (ou « Aucun clavier »), et l'engrenage des réglages
- Si le démarrage synchronisé est actif, un témoin disant si l'application *attend le Start* ou est déjà *synchronisée* sur la boîte à rythmes du clavier ; puis la subdivision de la grille (« Noires » par exemple) et la dernière note jouée
- Le tempo, avec les boutons **−**/**+** et un curseur (30 à 240 bpm). Si l'application suit l'horloge MIDI du clavier, c'est le tempo reçu qui s'affiche et les commandes se grisent — c'est le clavier qui commande
- **Démarrer / Arrêter**
- Deux volumes séparés : le **clic** du métronome et l'**instrument**, c'est-à-dire les notes que l'iPhone sonorise lui-même (§4). Chaque icône coupe et rétablit sa voix — haut-parleur pour le clic, note de musique pour l'instrument, barrée quand elle est muette. Le clic doit rester audible *sous* ton jeu, et le bon rapport dépend du timbre choisi autant que du morceau : c'est pour ça qu'ils ne se règlent pas ensemble

Tu ne trouveras ici aucun chiffre de bilan — nombre de notes, moyenne, dispersion. C'est délibéré : cet écran sert à corriger le geste en cours, et quatre chiffres décrivant ce qui vient d'être joué invitent à s'arrêter pour les lire. Ils reviendront le jour où l'application saura exporter une séance.

Un message peut apparaître en bas de l'écran, sur toute la largeur — un avertissement sur le retard de ta sortie audio (typique d'une enceinte ou d'un casque sans fil), ou l'absence d'horloge MIDI derrière un départ synchronisé. Il tient sur une ligne : **touche-le** pour lire l'explication complète, qui dit quoi faire, et la croix pour l'effacer. Un message disparaît de toute façon quand tu arrêtes la séance qu'il décrit.

---

## 4. Les réglages (icône d'engrenage, en haut à droite)

### Entrée MIDI
Choisis ton clavier si plusieurs sont disponibles, vérifie la dernière note reçue, restreins l'écoute à certains canaux MIDI, et fixe une vélocité minimale en dessous de laquelle les notes sont ignorées (pratique pour filtrer les effleurements involontaires).

### Grille et son
Choisis la subdivision sur laquelle tes notes sont jugées (noires, croches, triolets, doubles-croches) et le timbre du clic — cinq possibilités, chacune accompagnée d'une note sur le cas où elle convient (les claves ont l'attaque la plus nette et sont le meilleur choix pour l'étalonnage ; la grosse caisse se sent plus qu'elle ne s'entend et ne doit jamais servir à ça).

### Alignement — la méthode de mesure

Deux corrections, « Horloge de l'iPhone » et « Horloge du clavier », et c'est l'application qui choisit : la chaîne d'entrée est réellement plus longue quand l'instrument transmet son horloge, ses messages temps réel passant devant les notes dans sa file de sortie. Un repère indique celle qui s'applique.

Chacune se règle **une fois, par la mesure**. Ne les règle jamais au ressenti : on anticipe naturellement de 10 à 30 ms sans s'en apercevoir, et tu inscrirais ce défaut dans le zéro de l'appareil — l'application ne pourrait plus jamais te contredire.

La méthode :

1. Enregistre au micro, dans un même fichier, le **choc mécanique de la touche** et le **son que l'iPhone produit** en réponse. Place le micro à égale distance des deux.
2. Mesure l'écart entre les deux attaques — leur *début*, pas leur pic.
3. Retire de cet écart la **compensation automatique** affichée dans les Réglages : elle correspond à la sortie audio, déjà compensée par ailleurs.
4. Reporte le reste **en négatif**.

Compte quelques millisecondes pour la chaîne seule, une quinzaine de plus avec l'horloge du clavier. Deux limites connues : le boum de la touche arrive légèrement après le déclenchement MIDI, et le balayage du clavier reste non mesurable sans instrumenter la touche elle-même.

### Synchronisation
**Démarrage synchronisé** — si ton clavier possède une boîte à rythmes ou un séquenceur, ce réglage fait partir JustRhythm sur son message Start plutôt qu'après un délai fixe, puis suit son horloge MIDI pour que les deux ne dérivent jamais l'un par rapport à l'autre. Désactivé, tu démarres et arrêtes à la main comme d'habitude.

Tant que l'horloge pilote, le tempo affiché indique **bpm reçu** et l'application l'adopte comme le sien : la zone « juste » et l'échelle du graphe le suivent, et les commandes de tempo se grisent — les régler à la main n'aurait aucun effet, le temps suivant écraserait ta valeur. Change le tempo sur le clavier et l'application suit en un temps. Le tempo reçu est conservé à l'arrêt, si bien que la séance manuelle suivante démarre sur le tempo réellement joué plutôt que sur un réglage périmé.

### Instrument
L'iPhone peut sonoriser lui-même les notes qu'il reçoit, avec un timbre que tu choisis — piano, piano électrique, clavecin, guitare acoustique ou marimba. Tes notes et le clic du métronome sortent alors du même haut-parleur, par le même chemin, si bien qu'il n'y a plus rien à corriger entre les deux.

C'est prévu pour jouer **Local Control coupé** sur l'instrument, qui devient alors un clavier muet : en le laissant activé, tu entendras chaque note deux fois. Toutes les notes sonnent, justes ou non — ce n'est pas une récompense mais une voix. La pédale forte est suivie. **Tester l'instrument** joue une note sans lancer de séance.

Les sons sont synthétisés dans l'application plutôt qu'échantillonnés : rien n'est téléchargé, rien n'est stocké. Attends-toi à un instrument plausible, pas à un piano de concert — ce que tu écoutes, c'est où tombe l'attaque. Toute la tessiture d'un 88 touches est couverte, avec 64 voix de polyphonie et la pédale suivie : un trait pédale baissée ne coupe rien.

**Quand la frappe est juste**, l'iPhone peut faire une chose de plus :
- **Rien de particulier** — toutes les notes sonnent pareil. C'est le réglage par défaut.
- **Ajouter l'octave** — une note à l'octave se superpose à celles qui tombent dans la zone. Elle s'éteint avec la touche qui l'a déclenchée.
- **Étouffer les autres** — seules les frappes justes sonnent ; celles qui manquent la zone restent silencieuses. Le retour le plus franc des trois, et le plus exigeant.

Cela ne vaut que **métronome en marche** : à l'arrêt il n'y a pas de justesse à juger, et toutes les notes sonnent — sinon couper le métronome rendrait ton clavier muet.

Désactivé par défaut. Une fois activé, l'interrupteur reste à portée sans revenir ici : l'icône du curseur de volume de l'instrument, sur l'écran de mesure, coupe et rétablit le module. C'est le même interrupteur que celui-ci, vu d'ailleurs.


### Alignement
Deux nombres interviennent, et ils n'agissent **pas au même endroit** — c'est important pour les régler juste.

- La **compensation automatique** est mesurée sur le retard de ta sortie audio. Elle avance l'émission du clic pour qu'il soit *entendu* sur le temps, et non simplement programmé sur le temps. Tu n'as rien à y faire.
- La **correction manuelle** (−60 à +60 ms) décale l'horodatage des **notes reçues**, pas le clic. Elle sert à annuler le retard de la chaîne d'entrée — balayage du clavier, transport USB, tampons du pilote — qui fait arriver tes notes à l'application quelques millisecondes après que ta touche est enfoncée. Tourner ce curseur ne déplace donc pas le clic d'un millième : il ne change que la mesure.

**Ne règle jamais la correction manuelle au ressenti.** On anticipe naturellement le temps de 10 à 30 ms sans s'en apercevoir (voir §6) : tu inscrirais ce défaut dans le zéro de l'appareil, qui perdrait tout intérêt — un instrument incapable de te contredire ne sert à rien.

**La méthode fiable** consiste à te comparer à une référence objective plutôt qu'à ta perception :

1. Prépare un fichier MIDI parfaitement quantifié — quelques mesures de notes régulières suffisent.
2. Joue-le depuis le séquenceur de ton clavier, avec le démarrage synchronisé actif, en laissant JustRhythm le mesurer comme s'il s'agissait de ton jeu.
3. Ajuste la correction manuelle jusqu'à ce que les notes se posent sur la ligne centrale du graphe. Une dispersion résiduelle de 1 à 2 ms est normale : c'est la gigue du transport MIDI.

Le bouton **Tester le son** joue un clic isolé pour vérifier la chaîne audio sans lancer de séance.

### Mesure
Le premier réglage s'exprime **par rapport à la grille de référence**, et non en millisecondes fixes — parce qu'un même écart n'a pas la même portée sur une noire lente et sur une double-croche rapide. Il affiche la valeur en ms qui en découle au tempo courant, pour que le chiffre concret reste sous les yeux.

- **Zone « juste »** — la largeur de la bande de justesse, en pourcentage de la subdivision ; elle détermine la bande verte du graphe et la base du pourcentage « dans la zone ». Elle se resserre d'elle-même quand la grille s'affine. Elle ne descend jamais sous **20 ms** : en deçà, un écart cesse d'être audible, l'exiger serait arbitraire. Quand c'est ce plancher qui s'applique, la valeur affiche `(mini)` — sur une grille fine c'est normal, et bouger le curseur de pourcentage n'y changera rien tant que tu ne montes pas nettement.

Comme la zone suit le tempo, en changer au milieu d'une séance déplace aussi la part de notes qui y tombent.

### À propos
La version de l'application, et un rappel : aucune donnée ne quitte l'appareil, aucun compte, aucune mesure d'audience, aucun accès au microphone.

---

## 5. Une séance type

1. **Une fois pour toutes** : étalonne la correction manuelle avec un fichier quantifié (§4, Alignement). Elle dépend de ton matériel, pas du morceau — inutile d'y revenir à chaque séance.
2. Réglages → active **Démarrage synchronisé** si tu joues sur la boîte à rythmes du clavier.
3. Joue normalement. Regarde le mot au-dessus du graphe ; le graphe se remplit sous lui.
4. Touche le graphe pour passer en plein écran quand tu veux la plus grande résolution possible sur ton écart.

---

## 6. Ce que « Dans la zone » et « Dispersion » veulent dire

Ces deux chiffres mesurent des choses différentes, et les confondre mène à corriger la mauvaise chose :

- La **Moyenne** dit si tu as une habitude *systématique* — toujours un peu devant, ou toujours un peu derrière. C'est un biais, et il se corrige en ajustant consciemment le moment où tu joues, pas en répétant davantage.
- La **Dispersion** dit à quel point tes notes sont *éparpillées* autour de ta propre moyenne, même si cette moyenne est exactement nulle. C'est de l'inconstance, et c'est un autre problème — davantage de répétition et de contrôle, pas un ajustement de placement.

Un pourcentage « dans la zone » élevé avec une moyenne non nulle signifie que tu es pénalisé par un biais qui se promène à l'intérieur d'une zone assez large : va lire la Moyenne précisément, pas seulement le pourcentage.

Les deux seuils — la zone « juste » et la limite de dispersion — suivent la grille au lieu de rester à un nombre fixe de millisecondes, et tous deux cessent de suivre à un plancher (20 ms et 15 ms respectivement). Le raisonnement est le même dans les deux cas : un pourcentage seul finirait par exiger plus de précision qu'une main n'en peut fournir ou qu'une oreille n'en peut entendre ; c'est donc le plus permissif des deux critères qui l'emporte. En pratique, un feu vert sur des doubles-croches rapides se mérite davantage que sur des noires lentes — et c'est bien l'intention.

### Pourquoi l'application peut te contredire

Il est fréquent qu'un instrumentiste correctement étalonné se voie annoncer une avance systématique de 20 à 30 ms alors que son jeu lui *semble* parfaitement en place. Ce n'est pas un défaut de l'appareil, et pas davantage un défaut de musicien : quand on se synchronise sur une pulsation, on l'anticipe spontanément, et cette anticipation ne se perçoit pas de l'intérieur. C'est un phénomène documenté et quasi universel.

Faut-il pour autant la corriger ? Pas toujours, et c'est important de le savoir avant de s'acharner dessus.

En **groupe**, chacun s'ajuste en continu sur ce qu'il entend : les anticipations individuelles se compensent largement, et l'ensemble trouve sa pulsation commune. Un décalage absolu partagé par tous est musicalement invisible. Ce qui s'entend, c'est l'écart *entre* les musiciens — pas le décalage de chacun par rapport à une horloge idéale.

L'avance systématique compte vraiment dans deux cas : face à une référence qui ne s'adapte pas — clic de studio, playback, séquenceur — où elle s'entend et s'enregistre ; et lorsqu'elle diffère nettement de celle des autres, auquel cas on est systématiquement devant eux.

**Conséquence pratique**, qui vaut pour tous les réglages : une erreur d'étalonnage, quelle qu'elle soit, ne déplace que la **Moyenne**. Elle ne touche jamais la **Dispersion** ni l'état *irrégulier*. Ces deux-là sont donc exploitables sans condition, même si tu doutes de ton zéro — et ce sont aussi les plus utiles en groupe : un jeu dispersé gêne tout le monde, un jeu régulièrement un peu en avant ne gêne personne.
