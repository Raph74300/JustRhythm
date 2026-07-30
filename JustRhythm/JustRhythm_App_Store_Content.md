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
- how many milliseconds you're off
- your consistency over time

Audio feedback goes further too. When a hit lands in time, the app can send a note back to your instrument — an octave above what you played, or the same pitch — held for exactly as long as you hold the key, so the confirmation arrives in the time of playing rather than after it. And if you prefer, the iPhone can voice your notes itself, with a piano, electric piano, harpsichord, acoustic guitar or marimba sound: your playing and the metronome then come out of the same speaker, with nothing to correct between them.

After a few weeks of training, your playing naturally becomes more precise, more stable, and more in the groove. You'll play more easily with a drummer or other musicians, and your music will gain cohesion, energy, and impact.

Key features:
- Customizable metronome
- Real-time rhythmic placement analysis
- Millisecond deviation measurement
- Visual precision indicator
- Play consistency analysis
- Audio feedback when perfectly locked in
- Training tool for all instruments

Supported MIDI input: USB MIDI devices (including USB-MIDI interfaces)
```

**Note** : la ligne d'exigence MIDI est désormais la toute première phrase, conformément à ta propre remarque dans "Additional Notes". Les lignes Bluetooth/Network MIDI ont été retirées jusqu'à confirmation qu'elles fonctionnent réellement — à réintégrer dans une future mise à jour de la Description une fois testées.

---

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

- **Utiliser les captures de vraie séance** (notes affichées en temps réel, +11 ms / -3 ms visibles) plutôt qu'un écran vide — une capture publique doit montrer la valeur de l'app, pas l'absence de clavier
- **Ne pas inclure l'état "No keyboard"** dans les captures publiques — utile uniquement en App Review Notes ou en QA interne
- Si l'écran Settings est utilisé en capture, **flouter le nom d'appareil détecté** (ex. "CVP-303 Port 1") pour éviter toute implication de partenariat de marque non sollicité

---

## Pre-Launch Checklist (mise à jour)

- [x] ~~Verify exact availability of JustRhythm name on App Store~~ — déjà fait, la fiche existe sous ce nom
- [x] ~~Reserve domain name if necessary~~ — non applicable, convention Bundle ID `dev.oundjian.*` ne nécessite pas de domaine possédé
- [ ] Confirmer le support réel de Bluetooth MIDI et Network MIDI avant de les mentionner publiquement
- [ ] Préparer captures iPhone et iPad à partir d'une vraie séance de jeu
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
