# JustRhythm — Manuel d'utilisation

JustRhythm mesure la précision de ton placement rythmique. Branche un clavier MIDI, lance le métronome, et chaque note jouée est mesurée par rapport au temps — en millisecondes, pas en « à peu près ».

> Version française du manuel. Le fichier `user-manual.md`, à côté, en est l'équivalent anglais : toute correction apportée ici est à reporter là-bas.

---

## 1. Ce qu'il faut

- Un iPhone sous iOS 17 ou plus récent
- Un clavier MIDI, branché de l'une ou l'autre façon :
  - **USB** — filaire, le plus précis, sans latence ajoutée
  - **Bluetooth** — un clavier déjà appairé dans les réglages iOS apparaît tout seul ; ajoute 10 à 20 ms de gigue variable (voir §3)

Aucune permission micro n'est jamais demandée. JustRhythm n'écoute que le MIDI.

---

## 2. Prise en main

1. Branche le clavier. Ouvre JustRhythm — l'application retient le dernier clavier utilisé et s'y reconnecte seule au lancement suivant.
2. Joue une note. Son nom (« Do4 » par exemple) doit apparaître en bas de l'écran principal : c'est la confirmation que la liaison fonctionne, avant même d'avoir appuyé sur Démarrer.
3. Touche **Démarrer** pour lancer le métronome. Joue : chaque note est jugée à l'instant où elle survient.
4. Touche **Arrêter** pour clore la séance.

---

## 3. L'écran principal

**Lecture instantanée (en haut).** Trois voyants, à lire comme un accordeur de guitare : un triangle de chaque côté et une barre au milieu. C'est ce qu'on regarde en jouant.

- **Barre centrale verte** — ton jeu tient dans la zone « juste ». Rien d'autre n'est allumé
- **Triangle gauche** — tu es **en avance**
- **Triangle droit** — tu es **en retard**
- **Les deux triangles** — ton placement est **irrégulier** : centré en moyenne, mais dispersé autour du temps

Comme sur un accordeur, le centre ne s'allume que lorsque la cible est atteinte : c'est l'état visé, pas un repère permanent. Les voyants éteints restent faiblement visibles, pour que la cible soit identifiable avant d'avoir joué la moindre note.

Ce quatrième état est la raison pour laquelle la lecture suit une *fourchette* et non une simple moyenne. Une moyenne seule le masquerait : une note 40 ms en avance et une 40 ms en retard s'annulent, et l'application déclarerait parfait un jeu approximatif. Ce que les voyants reflètent, c'est la plage où tombent réellement tes notes récentes — son centre *et* sa largeur. Et elle porte sur tes **16 dernières notes**, non sur la dernière : l'écart d'une note isolée saute trop d'une frappe à l'autre pour qu'on puisse se corriger dessus — on courrait après du bruit.

En dessous, un mot dit la même chose en clair — *dans le temps*, *en avance*, *en retard*, *irrégulier* — puis un seul chiffre : ton écart moyen sur ces 16 notes (`+` en retard, `−` en avance). Trois voyants ne peuvent pas montrer *de combien* tu es décalé : c'est ce nombre qu'il faut lire pour ça. Ta dispersion, elle, se lit dans la rangée du bas sous **Dispersion**. Si tu viens de jouer un accord, une dernière ligne indique combien de notes le composaient et leur étalement.

**Le graphe.** Une ligne verticale centrale représente le temps. Le défilement va du haut vers le bas — les événements les plus récents sont en bas, près de la ligne. Chaque note apparaît sous forme de barre : sur la ligne si tu étais pile, à gauche en avance, à droite en retard. Une bande verte autour du centre matérialise ta zone « juste » — les notes qui y tombent comptent comme justes. Les deux bords du graphe ont un sens eux aussi : ils se situent exactement à une demi-subdivision du temps, c'est-à-dire là où une note cesse d'être « en retard sur ce pas » pour devenir « en avance sur le suivant ». Les temps du métronome défilent également, en traits horizontaux discrets, pour situer tes notes par rapport à la pulsation. **Touche le graphe** pour passer en plein écran : le même graphe, plus grand, avec le strict nécessaire (la fourchette, le tempo, le nombre de notes).

**Rangée de statistiques**, sous le graphe :
- **Notes** — combien tu en as jouées depuis le début de la séance. Le compte continue de monter tant que tu joues. Dès que la fenêtre statistique commence à écarter les plus anciennes, un petit chiffre en dessous indique combien sont encore retenues : c'est l'échantillon sur lequel reposent les trois cases voisines
- **Moyenne** — ton biais systématique : positif si tu traînes, négatif si tu précipites
- **Dispersion** — à quel point tes notes sont éparpillées autour de ta propre moyenne (un écart-type, en ms), indépendamment du biais ci-dessus. **Plus le nombre est grand, moins c'est bon** : 0 signifierait que toutes tes notes tombent exactement au même endroit. Le petit chiffre en dessous est la même valeur rapportée à un pas de grille, pour rester comparable d'un tempo à l'autre — 17 ms sont serrés sur une noire lente, larges sur une double-croche rapide. Il passe en orange au-delà de la limite acceptable, fixée au plus permissif entre 5 % du pas et 15 ms
- **Dans la zone** — le pourcentage de notes tombées dans ta zone « juste »

**Barre de transport**, en bas :
- Le nom du clavier (ou « Aucun clavier »), et — si le démarrage synchronisé est actif — si l'application *attend le Start* ou est déjà *synchronisée* sur la boîte à rythmes du clavier
- La subdivision de la grille (« Noires » par exemple) et la dernière note jouée
- Le tempo, avec les boutons **−**/**+** et un curseur (30 à 240 bpm). Si l'application suit l'horloge MIDI du clavier, c'est le tempo reçu qui s'affiche et les commandes se grisent — c'est le clavier qui commande
- **Démarrer / Arrêter**
- L'interrupteur de coupure du clic et son volume

Un message peut apparaître juste au-dessus de la barre de transport — un avertissement sur le retard de ta sortie audio (typique d'une enceinte ou d'un casque sans fil), ou la déconnexion d'un clavier.

---

## 4. Les réglages (icône d'engrenage, en haut à droite)

### Entrée MIDI
Choisis ton clavier si plusieurs sont disponibles, vérifie la dernière note reçue, restreins l'écoute à certains canaux MIDI, et fixe une vélocité minimale en dessous de laquelle les notes sont ignorées (pratique pour filtrer les effleurements involontaires).

### Grille et son
Choisis la subdivision sur laquelle tes notes sont jugées (noires, croches, triolets, doubles-croches), le nombre de temps par mesure recevant un accent, et le timbre du clic — cinq possibilités, chacune accompagnée d'une note sur le cas où elle convient (les claves ont l'attaque la plus nette et sont le meilleur choix pour l'étalonnage ; la grosse caisse se sent plus qu'elle ne s'entend et ne doit jamais servir à ça).

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

À ne pas confondre avec le **Retour clavier** ci-dessous, qui est indépendant : celui-ci agit sur la voix de l'iPhone, l'autre envoie une note à ton instrument. Active les deux et tu entendras les deux.

Désactivé par défaut.

### Retour clavier
Une note facultative est renvoyée à ton instrument quand la frappe tombe dans la zone « juste ». Le principe est celui d'une confirmation immédiate : la frappe juste s'entend au moment où elle se produit, dans le temps du jeu et non dans celui de l'analyse.

La note part à l'appui et s'éteint au lever, si bien qu'elle dure exactement ce que dure ton geste — quels que soient le tempo, la subdivision ou l'écriture du passage. Deux modes :

- **Note à l'octave** — une note située une octave au-dessus de celle que tu joues est renvoyée. Laisse le **Local Control activé** pour continuer à entendre tes propres notes à côté.
- **Même note** — ta note t'est renvoyée à la même hauteur, mais seulement si la frappe est juste. Coupe le **Local Control** pour que l'instrument reste silencieux quand tu es imprécis ; en le laissant activé, il sonne déjà tout seul et les frappes justes s'entendent simplement renforcées.

Désactivé par défaut. Les deux modes exigent que ton instrument accepte les notes MIDI entrantes, et pas seulement qu'il en émette. Rien ne survit à son déclencheur : les notes sont relâchées à l'arrêt, à la coupure du réglage, et si le clavier disparaît. Si un message de relâchement se perdait, la note de retour est lâchée au bout d'une mesure de toute façon, si bien qu'une note fantôme ne peut jamais s'installer. Revers de la médaille : une note que tu tiens au-delà d'une mesure voit son écho écourté — y compris tenue à la pédale par-dessus une barre de mesure.

### Accords
Les notes jouées dans une courte fenêtre (30 ms par défaut) comptent pour un seul événement, daté sur la première, avec leur étalement affiché à côté — ainsi un accord ne ressemble pas à une série d'erreurs de placement distinctes. Règle la fenêtre à 0 pour compter chaque note séparément ; baisse-la si tu travailles des notes répétées rapides plutôt que des accords.

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
Les deux premiers réglages s'expriment **par rapport à la grille de référence**, et non en millisecondes fixes — parce qu'un même écart n'a pas la même portée sur une noire lente et sur une double-croche rapide. Tous deux affichent la valeur en ms qui en découle au tempo courant, pour que le chiffre concret reste sous les yeux.

- **Zone « juste »** — la largeur de la bande de justesse, en pourcentage de la subdivision ; elle détermine la bande verte du graphe et la base du pourcentage « dans la zone ». Elle se resserre d'elle-même quand la grille s'affine. Elle ne descend jamais sous **20 ms** : en deçà, un écart cesse d'être audible, l'exiger serait arbitraire. Quand c'est ce plancher qui s'applique, la valeur affiche `(mini)` — sur une grille fine c'est normal, et bouger le curseur de pourcentage n'y changera rien tant que tu ne montes pas nettement.
- **Échelle affichée** — la largeur du graphe, en pourcentage d'une demi-subdivision. À 100 %, le graphe couvre exactement la plage qu'un écart peut atteindre : au-delà d'une demi-subdivision, une note appartient au pas de grille *suivant*, il n'y a donc rien à y montrer. Baisse-la pour resserrer. Purement visuel : la mesure ne change jamais.
- **Fenêtre statistique** — combien de notes récentes alimentent le bilan, pour qu'un début de séance hésitant ne plombe pas la moyenne indéfiniment.

Comme les deux premiers suivent le tempo, en changer au milieu d'une séance déplace aussi le pourcentage « dans la zone » déjà accumulé.

### Données
**Effacer les statistiques** remet les compteurs et le graphe à zéro sans arrêter le métronome — pratique pour repartir sur une lecture propre en cours de séance.

### À propos
La version de l'application, et un rappel : aucune donnée ne quitte l'appareil, aucun compte, aucune mesure d'audience, aucun accès au microphone.

---

## 5. Une séance type

1. **Une fois pour toutes** : étalonne la correction manuelle avec un fichier quantifié (§4, Alignement). Elle dépend de ton matériel, pas du morceau — inutile d'y revenir à chaque séance.
2. Réglages → active **Démarrage synchronisé** si tu joues sur la boîte à rythmes du clavier.
3. Joue normalement. Regarde les voyants ; le graphe et les statistiques se remplissent.
4. Pour une lecture propre sur un passage précis, utilise **Effacer les statistiques** juste avant de l'attaquer.

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
