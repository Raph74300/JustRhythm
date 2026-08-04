# JustRhythm — User Manual

JustRhythm measures how accurately you play in time. Connect a MIDI keyboard, start the metronome, and every note you play is measured against the beat — in milliseconds, not just "close enough."

---

## 1. What you need

- An iPhone running iOS 17 or later
- A MIDI keyboard, connected either way:
  - **USB** — wired, the most accurate, no added latency
  - **Bluetooth** — a keyboard already paired in iOS Settings shows up automatically; adds 10–20 ms of variable jitter (see §3)

The app is used **on its side**, either way round: the cable then comes out sideways instead of butting against the music stand. There is no portrait mode.

No microphone permission is ever requested. JustRhythm only listens to MIDI.

---

## 2. Getting started

1. Connect your keyboard (see above). Open JustRhythm — it remembers the last keyboard you used and reconnects automatically next time.
2. Play a note. Its name (e.g. "C4") should appear in the right-hand sidebar — that confirms the connection works, even before you press Start.
3. Tap **Start** to begin the metronome. Play along; each note you play is scored the instant it happens.
4. Tap **Stop** (or the same button) to end the session.

---

## 3. The main screen

The screen reads in two columns: the graph takes the left two thirds, and the right third holds everything you touch while playing.

**Readout (above the graph).** One word, and only that — *on time*, *early*, *late*, *uneven*. It is centred on the graph's vertical line, directly above it: the two say the same thing on the same axis. Green inside the zone, orange outside, the colour only doubling the word.

*Uneven* is the one worth understanding: it means centred on average but scattered around the beat. It is why the reading tracks a *range* rather than a single average. An average alone would hide it — a note 40 ms early and one 40 ms late cancel out, and the app would call sloppy playing perfect. What the word reflects is the range your recent notes are landing in: its centre *and* its width. And it follows your **last 16 notes**, not the last single one: one note's error jumps around too much from keystroke to keystroke to steer by — you'd be chasing noise.

Nothing else there, and not a figure: what you watch while playing has to register without being read.

**Graph.** A vertical line down the centre represents the beat. Time scrolls from top to bottom: the newest events are at the top and fade as they descend. Each note appears as a short bar: on the line if you were exactly on time, left if early, right if late.

Its width is **one beat, always** — whatever the subdivision. That is what makes it a ruler rather than a magnifier: two sessions can be compared, and there is no scale setting to watch.

Three tints, from the outside in:

- **Grey — out of reach.** No note can land there: any further off and it belongs to the next grid step. The amount of grey therefore tells you at a glance how demanding the grid you chose is. None on quarter notes, three quarters of the width on sixteenths.
- **Orange — measurable, outside the zone.** This is the range your grid can judge.
- **Green — the "right" zone.** Its width follows your tolerance setting, and the percentage recalled on the ruler, among the pictograms, gives its value.

A hairline marks each boundary, so the information never rests on colour alone.

Along the bottom, a **ruler in note values**: half the width is an eighth note, a quarter a sixteenth, an eighth a thirty-second. You read your error as music — "late by a sixteenth" — rather than in milliseconds. In triplet mode the marks move to a third and a sixth of a beat, carrying a 3. Marks falling in the grey are dimmed: they exist, but your grid cannot reach them.

**Tap the graph** for full-screen mode: the sidebar clears away and the graph takes the whole width, right under the notch. Tempo and **Start/Stop** stay at the bottom right, under your thumb. Tap again to come back.

Every note is measured on its own: there is no chord grouping. The notes of a chord therefore appear separately, and that is deliberate — you see at the same time whether the chord is *together*, which grouping would hide. It also stops a slightly overlapping legato from being swallowed.

**The right-hand sidebar** holds, top to bottom:
- Keyboard name (or "No keyboard"), and the settings gear
- If synced start is on, an indicator saying whether the app is *waiting for Start* or already *synced* to your keyboard's drum machine; then the grid subdivision (e.g. "Quarter notes") and the last note played
- Tempo with **−**/**+** buttons and a slider (30–240 bpm). If the app is following your keyboard's MIDI clock, this shows the tempo it's receiving instead, and it stops being editable — the keyboard is in charge
- **Start/Stop**
- Two separate volumes: the metronome **click**, and the **instrument**, meaning the notes the iPhone voices itself (§4). Each icon mutes and unmutes its own voice — a speaker for the click, a music note for the instrument, barred when silent. The click has to stay audible *under* your playing, and the right ratio depends on the timbre as much as on the piece: that is why they don't move together

You will find no summary figures here — note count, average, dispersion. That is deliberate: this screen is for correcting the gesture in progress, and four figures describing what has just been played invite you to stop and read them. They come back the day the app can export a session.

A message may appear across the bottom of the screen — e.g. a warning that your audio output is adding delay (typical with wireless speakers/headphones), or that no MIDI clock is following a synced start. It fits on one line: **tap it** to read the full explanation, which tells you what to do, and the cross to clear it. A message goes away anyway when you stop the session it describes.

---

## 4. Settings (gear icon, top right)

### MIDI Input
Pick your keyboard if more than one is available, see the last note received, restrict listening to a single MIDI channel, and set a minimum velocity below which notes are ignored (useful to filter out accidental light touches).

### Grid & sound
Choose the subdivision your notes are judged against (quarter notes, eighth notes, triplets, sixteenths) and the metronome's click sound — five options, each with a short note on when it's the right choice (Claves is the sharpest attack and the best pick for calibrating alignment; Kick drum is felt more than heard and should never be used for that purpose).

### Alignment — how to measure it

Two corrections, "iPhone clock" and "Keyboard clock", and the app picks: the input chain really is longer when the instrument transmits its clock, its real-time messages taking priority over notes in its output queue. A marker shows which one is in force.

Each is set **once, by measurement**. Never set them by feel: you naturally anticipate by 10 to 30 ms without noticing, and you would write that bias into the device's zero — after which the app could never contradict you again.

The method:

1. Record, in one file, the **mechanical thud of the key** and the **sound the iPhone makes** in reply. Put the microphone equidistant from both.
2. Measure the interval between the two attacks — their *onset*, not their peak.
3. Subtract the **automatic compensation** shown in Settings: that part is the audio output, already compensated elsewhere.
4. Enter what remains as a **negative** value.

Expect a few milliseconds for the chain alone, some fifteen more with the keyboard's clock running. Two known limits: the key's thud arrives slightly after the MIDI trigger, and key scan time stays unmeasurable without instrumenting the key itself.

### Synchronization
**Synced start** — when your keyboard has a built-in drum machine or sequencer, turning this on makes JustRhythm start on its Start message instead of a fixed delay, and keep following its MIDI clock afterward so the two never drift apart. With it off, you start and stop manually as usual.

While the clock is driving, the tempo shown reads **bpm received** and the app adopts it as its own: the "right" zone and the graph scale follow it, and the app's tempo controls are greyed out — setting them by hand would be pointless, since the next beat would overwrite your value. Change the tempo on the keyboard and the app follows within a beat. The received tempo is kept when you stop, so the next manual session starts from the tempo you were actually playing at rather than from a stale setting.

### Instrument
The iPhone can play the notes it receives itself, with a timbre you choose — piano, electric piano, harpsichord, acoustic guitar or marimba. Your notes and the metronome click then come out of the same speaker, by the same path, so nothing has to be corrected between them.

It is meant for playing with **Local Control off** on your instrument, which then acts as a silent controller: leave it on and you will hear every note twice. Every note sounds, accurate or not — this is not a reward but a voice. The sustain pedal is followed. **Test the instrument** plays a note without starting a session.

The sounds are synthesised inside the app rather than sampled, so nothing is downloaded and nothing is stored. Expect a plausible instrument, not a concert grand — what you are listening for is where the attack falls. The full range of an 88-key keyboard is covered, with 64-voice polyphony and the sustain pedal followed: a run with the pedal down cuts nothing.

**On accurate hits**, the iPhone can do one thing more:
- **Nothing in particular** — every note sounds alike. This is the default.
- **Add an octave** — a note an octave up is layered over the hits that land in the zone. It stops with the key that triggered it.
- **Mute the others** — only accurate hits sound; anything that misses the zone stays silent. The bluntest of the three, and the most demanding.

This only applies **while the metronome is running**: stopped, there is no accuracy to judge and every note sounds — otherwise stopping the metronome would leave your keyboard silent.

Off by default.


### Alignment
Two numbers are involved, and they act at **different points** — which matters for setting them correctly.

- The **automatic compensation** is measured from your audio output's delay. It advances the click so it is *heard* on the beat rather than merely scheduled on it. Nothing to do here.
- The **manual correction** (−60 to +60 ms) shifts the timestamp of **incoming notes**, not the click. It exists to cancel the input chain's delay — key scan, USB transport, driver buffering — which makes your notes reach the app a few milliseconds after the key goes down. Turning this slider does not move the click at all: it only changes the measurement.

**Never set the manual correction by feel.** You naturally anticipate the beat by 10–30 ms without noticing (see §6), and you would bake that bias into the device's zero point — an instrument that cannot contradict you is worthless.

**The reliable method** compares you against an objective reference rather than your perception:

1. Prepare a perfectly quantized MIDI file — a few bars of steady notes is enough.
2. Play it from your keyboard's sequencer, with Synced start on, letting JustRhythm measure it as if it were your own playing.
3. Adjust the manual correction until the notes settle on the graph's center line. A residual spread of 1–2 ms is normal — that's MIDI transport jitter.

A **Test the sound** button plays an isolated click to check the audio chain without starting a session.

### Measurement
This setting is expressed **relative to the reference grid**, not in fixed milliseconds — because the same error doesn't mean the same thing on a slow quarter note as on a fast sixteenth. It shows you the resulting value in ms for your current tempo, so you keep the concrete figure in view.

- **"Right" zone** — how wide the accurate band is, as a percentage of the subdivision; sets both the green band on the graph and the "In the zone" percentage. It tightens on its own as the grid gets finer. It never goes below **20 ms**, though: under that an error stops being audible, so demanding better would be arbitrary. When that floor is what's actually in effect, the value reads `(min)` — on fine grids that's normal, and moving the percentage slider won't change anything until you go well above it.

Because the zone follows the tempo, changing tempo or subdivision mid-session also shifts which of your notes fall inside it.

### About
App version, and a one-line reminder: no data ever leaves the device, no account, no analytics, no microphone access.

---

## 5. A typical session

1. **Once and for all**: calibrate the manual correction with a quantized file (§4, Alignment). It depends on your hardware, not on the piece — no need to revisit it every session.
2. Settings → turn on **Synced start** if you're playing along with the keyboard's drum machine.
3. Play normally. Watch the word above the graph; the graph fills in beneath it.
4. Tap the graph for full-screen mode whenever you want the finest possible resolution on your deviation.

---

## 6. What "In the zone" and "Dispersion" actually mean

They measure two different things, and mixing them up leads to the wrong fix:

- **Average** tells you if you have a *systematic* habit — always a little ahead or a little behind. That's a bias, and it's corrected by consciously adjusting when you play, not by practicing more of the same.
- **Dispersion** tells you how *scattered* your notes are around wherever your average sits, even if that average is exactly zero. That's inconsistency, and it's a different problem — more repetition and more control, not a timing adjustment.

A high "In the zone" percentage with a non-zero average means you're being penalized for a bias that dodges around inside a wide enough tolerance zone — worth checking the Average figure specifically, not just the percentage.

Both thresholds — the "right" zone and the dispersion limit — scale with the grid rather than sitting at a fixed number of milliseconds, and both stop scaling at a floor (20 ms and 15 ms respectively). The reasoning is the same in each case: a percentage alone would eventually demand more precision than a hand can deliver or an ear can hear, so the more forgiving of the two criteria wins. In practice this means a green light on fast sixteenths is genuinely harder to earn than on slow quarter notes — which is the point.

### Why the app may contradict you

It is common for a correctly calibrated player to be told they run 20–30 ms early while their playing *feels* perfectly placed. That is neither a fault of the device nor of the musician: when synchronising to a pulse, people spontaneously anticipate it, and that anticipation is not perceptible from the inside. The effect is well documented and close to universal.

Does it need correcting, though? Not always — worth knowing before you go to war with it.

In a **group**, everyone adjusts continuously to what they hear: individual anticipations largely cancel out, and the ensemble settles on a shared pulse. An absolute offset shared by everyone is musically invisible. What is audible is the gap *between* players, not each player's offset from some ideal clock.

Systematic anticipation does matter in two cases: against a reference that doesn't adapt — studio click, backing track, sequencer — where it is both audible and recorded; and when it differs markedly from everyone else's, which puts you consistently ahead of them.

**A practical consequence**, true for any calibration setting: a calibration error only shifts the **Average**. It never touches **Dispersion** or the *uneven* state. Those two are therefore usable unconditionally, even if you doubt your zero point — and they are also the ones that matter most in a group: scattered playing bothers everyone, playing consistently a little ahead bothers nobody.
