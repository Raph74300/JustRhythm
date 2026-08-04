# JustRhythm – App Store Content (version corrigée)

⚠️ **Avant de coller quoi que ce soit** : confirmer si Bluetooth MIDI (via `CABTMIDICentralViewController`) et Network MIDI (Bonjour) sont réellement implémentés. Tout ce qui a été testé jusqu'ici est de l'USB. Les lignes concernées sont marquées ci-dessous.

---

## Subtitle (champ réel, 30 caractères max)

```
Real-time rhythm feedback
```
25/30 caractères. Fait écho au slogan (cohérence de ton entre les deux champs).

Alternatives si tu préfères garder "Visualize" :
- `See your rhythmic timing` (24 car.)
- `Visualize your rhythm` (21 car.)

---

## Promotional Text (champ réel, 170 caractères max — modifiable à tout moment sans nouvelle version)

```
Turn your metronome into a rhythm coach. Connect a MIDI instrument and see instantly if you're rushing, dragging, or perfectly on time.
```
135/170 caractères — marge pour ajuster plus tard (annonce saisonnière, mise à jour, etc.) sans repasser par la revue Apple.

---

## Description (champ réel, 4000 caractères max)

```
Requires a MIDI-compatible instrument (keyboard, drum pad, or similar) connected via USB.

Improve your rhythmic placement like never before.

JustRhythm transforms your metronome into a real rhythm coach. Connect your MIDI instrument, and as you play, the application analyzes your synchronization with the click and instantly displays your rhythmic precision.

You immediately see:

- if you're rushing
- if you're dragging
- exactly where each note fell against the beat, read as music — late by a sixteenth, not late by 47 ms
- whether your playing is steady or scattered

Audio feedback goes further too. The iPhone can voice your notes itself, with a piano, electric piano, harpsichord, acoustic guitar or marimba sound: your playing and the metronome then come out of the same speaker, with nothing to correct between them. And when a hit lands in time it can add a note an octave up, or keep silent everything that misses — a confirmation that arrives in the time of playing rather than after it.

After a few weeks of training, your playing naturally becomes more precise, more stable, and more in the groove. You'll play more easily with a drummer or other musicians, and your music will gain cohesion, energy, and impact.

Key features:
- Customizable metronome, with separate volumes for the click and for the notes
- Real-time rhythmic placement analysis
- Millisecond-accurate measurement, shown as a scrolling graph one beat wide
- A ruler in note values, so you read your error as music
- Landscape layout: graph on the left, controls under your hand on the right
- Audio feedback when perfectly locked in
- Training tool for all instruments

Supported MIDI input: USB MIDI devices (including USB-MIDI interfaces)
```

**Note** : la ligne d'exigence MIDI est désormais la toute première phrase, conformément à ta propre remarque dans "Additional Notes". Les lignes Bluetooth/Network MIDI ont été retirées jusqu'à confirmation qu'elles fonctionnent réellement — à réintégrer dans une future mise à jour de la Description une fois testées.

---

## What's New in This Version (champ réel, 4000 caractères max — obligatoire pour une mise à jour)

> À coller dans « Nouveautés » de la fiche 2.8. La version publiée est la 1.0, qui
> correspond à l'état v2.1 du cahier des charges : ce texte couvre donc v2.2 à v2.8,
> suppressions comprises.
>
> **À reprendre avant soumission.** Les paragraphes ci-dessous décrivent encore les
> trois voyants d'accordeur et la rangée de statistiques, retirés en 2.8 : le mot seul
> les remplace, et l'application est désormais entièrement en paysage. Deux ajouts à
> faire dans les deux langues — l'orientation couchée avec le graphe en deux tiers de
> largeur, et les volumes séparés du clic et de l'instrument.

### English

Your notes, now played by the iPhone.

The app can voice everything you play — piano, electric piano, harpsichord, acoustic guitar or marimba. Your notes and the metronome click then leave the same speaker by the same path, so where a note falls is something you hear rather than read. Turn Local Control off on your instrument and the iPhone becomes its voice. Full 88-key range, 64 voices, sustain pedal followed.

On accurate hits it can do one thing more: add a note an octave up, or keep silent everything that misses the zone. A confirmation that arrives in the time of playing — usable with your eyes closed.

A graph that shows you what is being asked.

Its width is now one beat, whatever grid you choose — so what you see means the same thing every time. Grey marks what is out of reach, orange what your grid can measure, green the zone counted as accurate. On quarter notes there is no grey at all; on sixteenths it takes three quarters of the width. You can see, without reading a number, how demanding the setting you picked really is. Along the bottom, note values give your error in eighths, sixteenths and thirty-seconds rather than milliseconds.

A readout you can take in at a glance.

The last note's error jumped around too much to steer by. Three tuner-style lights replace it, fed by your last 16 notes — their centre and their spread. Each side lights on its own, so rushing steadily reads differently from playing scattered but centred on the beat. An average alone would have called the second one perfect.

Accuracy that means the same thing at every tempo.

The "right" zone is now a share of the grid rather than a fixed number of milliseconds: 50 ms is nothing on a slow quarter note and a great deal on a fast sixteenth. Open it up to 30 % for a beginner or a fine grid — widening it changes the green band and the percentage, never the measurement underneath.

Sync that holds.

Following your keyboard's MIDI clock no longer drifts. A tempo changed on the instrument is picked up within a beat and kept afterwards. And if a Start message arrives with no clock behind it, the app says so instead of quietly running at its own tempo.

Alignment is handled for you: one correction for the app's own clock, one for the keyboard's, and the app applies whichever fits — the input chain really is longer when an instrument transmits clock.

Fixes: the note counter no longer freezes; your keyboard is found again on every scan instead of being locked out by a fallback; dense playing no longer leaves the graph behind.

Removed: the note echoed back to the instrument on an accurate hit, replaced by the iPhone voicing your notes. It relied on settings inside the keyboard — Local Control, MIDI echo — that the app could neither read nor correct, and it behaved differently on every instrument. Bar accents are gone too: MIDI carries no time signature, so the setting could contradict the music you were playing.

### Français

Tes notes, jouées par l'iPhone.

L'application peut sonoriser tout ce que tu joues — piano, piano électrique, clavecin, guitare acoustique ou marimba. Tes notes et le clic du métronome sortent alors du même haut-parleur par le même chemin : où tombe une note devient quelque chose qui s'entend, et non qui se lit. Coupe le Local Control sur ton instrument et l'iPhone devient sa voix. Toute la tessiture d'un 88 touches, 64 voix, pédale forte suivie.

Quand la frappe est juste, il peut faire une chose de plus : ajouter une note à l'octave, ou étouffer tout ce qui manque la zone. Une confirmation qui arrive dans le temps du jeu — utilisable les yeux fermés.

Un graphe qui montre ce qu'on te demande.

Sa largeur vaut désormais un temps, quelle que soit la grille choisie — ce que tu vois veut donc dire la même chose à chaque fois. Le gris marque ce qui est hors d'atteinte, l'orangé ce que ta grille sait mesurer, le vert la zone comptée comme juste. En noires il n'y a pas de gris du tout ; en doubles-croches il occupe les trois quarts de la largeur. Tu vois donc, sans lire un chiffre, à quel point le réglage que tu as choisi est exigeant. En bas, des valeurs de note donnent ton écart en croches, doubles-croches et triples-croches plutôt qu'en millisecondes.

Une lecture qui se prend d'un coup d'œil.

L'écart de la dernière note sautait trop d'une frappe à l'autre pour qu'on puisse s'y fier. Trois voyants façon accordeur le remplacent, alimentés par tes 16 dernières notes — leur centre et leur étalement. Chaque côté s'allume séparément : précipiter régulièrement ne se lit pas comme jouer dispersé mais centré sur le temps. Une moyenne seule aurait déclaré le second parfait.

Une justesse qui veut dire la même chose à tous les tempos.

La zone « juste » s'exprime désormais en part de la grille et non en millisecondes fixes : 50 ms ne sont rien sur une noire lente et beaucoup sur une double-croche rapide. Ouvre-la jusqu'à 30 % pour un débutant ou une grille fine — l'élargir change la bande verte et le pourcentage, jamais la mesure en dessous.

Une synchro qui tient.

Le suivi de l'horloge MIDI de ton clavier ne dérive plus. Un tempo changé sur l'instrument est repris en un temps et conservé ensuite. Et si un message Start arrive sans horloge derrière, l'application le dit au lieu de continuer discrètement à son propre tempo.

L'alignement est pris en charge : une correction pour l'horloge de l'application, une pour celle du clavier, et c'est elle qui applique la bonne — la chaîne d'entrée est réellement plus longue quand un instrument transmet son horloge.

Corrections : le compteur de notes ne se fige plus ; ton clavier est retrouvé à chaque balayage au lieu d'être écarté par un repli ; le jeu dense ne laisse plus le graphe en arrière.

Retiré : la note renvoyée à l'instrument quand la frappe était juste, remplacée par la sonorisation sur l'iPhone. Elle dépendait de réglages internes au clavier — Local Control, renvoi MIDI — que l'application ne pouvait ni lire ni corriger, et se comportait différemment sur chaque instrument. Les accents de mesure disparaissent aussi : le MIDI ne transmet pas de métrique, si bien que le réglage pouvait contredire la musique jouée.


## Keywords (champ réel, 100 caractères max, séparés par virgules sans espace)

```
metronome,groove,timing,music,MIDI,drums,guitar,piano,tempo,training,precision,synchronization
```
93/100 caractères. "rhythm" et "musician" retirés : "rhythm" est déjà indexé via le nom de l'app et le subtitle, "musician" apportait peu de valeur de recherche différenciante.

---

## App Review Notes (jamais public, visible seulement par l'examinateur)

```
This app requires a MIDI keyboard connected via USB to function — it analyzes the timing of notes played against a metronome click. Without a keyboard connected, the app displays a clean "No keyboard detected" state (see Settings screen) rather than any error. This is expected behavior, not a bug. If a physical MIDI keyboard is not available for testing, connecting via a USB-MIDI interface or any Class-Compliant MIDI keyboard is sufficient.
```

---

## Captures d'écran — recommandations

- **Refaire les captures en paysage** — depuis la 2.8 l'application n'a plus de mode portrait, et toutes les captures existantes sont donc fausses
- **Utiliser les captures de vraie séance** (notes affichées en temps réel, +11 ms / -3 ms visibles) plutôt qu'un écran vide — une capture publique doit montrer la valeur de l'app, pas l'absence de clavier
- **Ne pas inclure l'état "No keyboard"** dans les captures publiques — utile uniquement en App Review Notes ou en QA interne
- Si l'écran Settings est utilisé en capture, **flouter le nom d'appareil détecté** (ex. "CVP-303 Port 1") pour éviter toute implication de partenariat de marque non sollicité

---

## Pre-Launch Checklist (mise à jour)

- [x] ~~Verify exact availability of JustRhythm name on App Store~~ — déjà fait, la fiche existe sous ce nom
- [x] ~~Reserve domain name if necessary~~ — non applicable, convention Bundle ID `dev.oundjian.*` ne nécessite pas de domaine possédé
- [ ] Confirmer le support réel de Bluetooth MIDI et Network MIDI avant de les mentionner publiquement
- [ ] Préparer captures iPhone **en paysage** à partir d'une vraie séance de jeu (plus d'iPad, plus de portrait)
- [ ] Flouter tout nom de marque d'appareil visible dans les captures Settings
- [ ] Vérifier la conformité aux App Store Guidelines (fait dans le cadre du parcours de publication)
- [ ] Icône et images de preview déjà prêtes (voir guide de publication)

---

## Éléments hors champs App Store Connect (repères de ton, pas de texte à coller)

Ces éléments n'ont pas de champ dédié dans App Store Connect — ils servent de boussole de ton pour rédiger cohérence entre Description, réponses aux avis, site web, etc.

**Slogan** : The missing feedback from every metronome.

**Marketing Copy** : It's not a metronome. It's a visual rhythm coach that helps you play more precisely, more consistently, and more in the groove.

**User Promise** : See your rhythmic placement in real-time to naturally correct your playing and develop a stronger groove.

**Positioning** : A visual rhythm coach for musicians who want to truly play in time.
*(Le "The first" du brouillon original a été retiré — une affirmation de préséance ("le premier") est invérifiable et inutilement risquée pour un bénéfice marginal.)*
