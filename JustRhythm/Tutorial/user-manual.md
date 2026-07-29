# JustRhythm — User Manual

JustRhythm measures how accurately you play in time. Connect a MIDI keyboard, start the metronome, and every note you play is measured against the beat — in milliseconds, not just "close enough."

---

## 1. What you need

- An iPhone running iOS 17 or later
- A MIDI keyboard, connected either way:
  - **USB** — wired, the most accurate, no added latency
  - **Bluetooth** — a keyboard already paired in iOS Settings shows up automatically; adds 10–20 ms of variable jitter (see §3)

No microphone permission is ever requested. JustRhythm only listens to MIDI.

---

## 2. Getting started

1. Connect your keyboard (see above). Open JustRhythm — it remembers the last keyboard you used and reconnects automatically next time.
2. Play a note. Its name (e.g. "C4") should appear at the bottom of the main screen — that confirms the connection works, even before you press Start.
3. Tap **Start** to begin the metronome. Play along; each note you play is scored the instant it happens.
4. Tap **Stop** (or the same button) to end the session.

---

## 3. The main screen

**Readout (top).** Three indicators, read like a guitar tuner: a triangle on each side and a bar in the middle. This is the thing to watch while you play.

- **Center bar green** — your playing fits inside the "right" zone. Nothing else is lit
- **Left triangle** — you're running **early**
- **Right triangle** — you're running **late**
- **Both triangles** — your placement is **uneven**: centered on average, but scattered around the beat

Like a tuner, the center only lights when you're actually on target — it's the state you're aiming for, not a permanent marker. The indicators stay faintly visible when off, so the target is identifiable before you've played a note.

That fourth state is why the reading tracks a *range* rather than a single average. An average alone would hide it: a note 40 ms early and one 40 ms late cancel out, and the app would call sloppy playing perfect. What the indicators react to is the range your recent notes are landing in — its center *and* its width. And it follows your **last 16 notes**, not the last single one: one note's error jumps around too much from keystroke to keystroke to steer by — you'd be chasing noise.

Underneath, a word says the same thing in plain language — *on time*, *early*, *late*, *uneven* — and below that, the range as numbers: the average (`+` late, `−` early) followed by `±` and how spread out you are, in milliseconds. Three indicators can't show *how far* off you are, so that line is where to look for it, along with the stats row. If you just played a chord, a last line shows how many notes were in it and how spread out they were.

**Graph.** A vertical line down the center represents the beat. Time scrolls from top to bottom — the newest events are at the bottom, near the line. Each note you play appears as a short bar: on the line if you were exactly on time, to the left if early, to the right if late. A green band around the center marks your "right" zone — notes landing inside it count as accurate. The two edges of the graph are meaningful too: they sit exactly half a subdivision away from the beat, which is the point where a note stops being "late on this step" and becomes "early on the next one." Metronome beats scroll down too, as faint horizontal lines, so you can see how your notes line up with the pulse over time. **Tap the graph** to switch to full-screen mode — same graph, larger, with just the essentials (the rolling average, tempo, note count) and nothing else on screen.

**Stats row**, below the graph:
- **Notes** — how many have been measured this session
- **Average** — your systematic bias: positive means you tend to drag, negative means you tend to rush
- **Regularity** — how consistent you are around your own average (a standard deviation, in ms), independent of the bias above
- **In the zone** — the percentage of notes that landed inside your "right" zone

**Transport bar**, at the bottom:
- Keyboard name (or "No keyboard"), and — if synced start is on — whether the app is *waiting for Start* or already *synced* to your keyboard's drum machine
- The current grid subdivision (e.g. "Quarter notes"), and the last note played
- Tempo with **−**/**+** buttons and a slider (30–240 bpm). If the app is following your keyboard's MIDI clock, this shows the tempo it's receiving instead, and it stops being editable — the keyboard is in charge
- **Start/Stop**
- Click mute toggle and volume slider

A message may appear just above the transport bar — e.g. a warning that your audio output is adding delay (typical with wireless speakers/headphones), or that a keyboard disconnected.

---

## 4. Settings (gear icon, top right)

### MIDI Input
Pick your keyboard if more than one is available, see the last note received, restrict listening to a single MIDI channel, and set a minimum velocity below which notes are ignored (useful to filter out accidental light touches).

### Grid & sound
Choose the subdivision your notes are judged against (quarter notes, eighth notes, triplets, sixteenths), how many beats per bar get an accent, and the metronome's click sound — five options, each with a short note on when it's the right choice (Claves is the sharpest attack and the best pick for calibrating alignment; Kick drum is felt more than heard and should never be used for that purpose).

### Synchronization
**Synced start** — when your keyboard has a built-in drum machine or sequencer, turning this on makes JustRhythm start on its Start message instead of a fixed delay, and keep following its MIDI clock afterward so the two never drift apart. With it off, you start and stop manually as usual.

While the clock is driving, the tempo shown reads **bpm received** and the app adopts it as its own: the "right" zone and the graph scale follow it, and the app's tempo controls are greyed out — setting them by hand would be pointless, since the next beat would overwrite your value. Change the tempo on the keyboard and the app follows within a beat. The received tempo is kept when you stop, so the next manual session starts from the tempo you were actually playing at rather than from a stale setting.

### Reward
An optional sound plays back on your instrument when a note lands in the "right" zone — a small, immediate confirmation you're on time. Two modes:
- **Note doubled an octave up** — an extra note, an octave above what you played, sounds alongside it. Keep **Local Control on** on your instrument so your own notes keep sounding normally; this one is just a bonus layered on top.
- **Note muted if inaccurate** — the opposite approach: your note is echoed back at its own pitch only when it's accurate, and stays silent otherwise. This requires **Local Control off** on your instrument (so it doesn't already sound on its own) — otherwise every note plays anyway and you won't notice a difference.

Off by default; both modes need your instrument to accept incoming MIDI notes, not just send them.

### Chords
Notes played within a short window (default 30 ms) count as one event, timestamped on the first note, with their spread shown alongside it — so playing a chord doesn't look like several separate timing errors. Set the window to 0 to count every note individually; lower it if you're working on fast repeated single notes rather than chords.

### Alignment
Two numbers combine to place the click exactly on the beat as *heard*, not just as scheduled: an automatic compensation (measured from your current audio output's delay) and a manual correction you can nudge by ear, from −60 to +60 ms. **Don't tune the manual correction by feel** — everyone naturally anticipates the beat by 10–20 ms, and doing so just bakes that bias into the app's zero point. The reliable method: turn on Synced start, start your keyboard's drum machine, and adjust the manual correction until its click and JustRhythm's click merge into one sound. A **Test the sound** button plays an isolated click to check the audio chain without starting a session.

### Measurement
The first two settings are expressed **relative to the reference grid**, not in fixed milliseconds — because the same error doesn't mean the same thing on a slow quarter note as on a fast sixteenth. Both show you the resulting value in ms for your current tempo, so you keep the concrete figure in view.

- **"Right" zone** — how wide the accurate band is, as a percentage of the subdivision; sets both the green band on the graph and the "In the zone" percentage. It tightens on its own as the grid gets finer. It never goes below **20 ms**, though: under that an error stops being audible, so demanding better would be arbitrary. When that floor is what's actually in effect, the value reads `(min)` — on fine grids that's normal, and moving the percentage slider won't change anything until you go well above it.
- **Displayed scale** — how wide the graph reads left-to-right, as a percentage of half a subdivision. At 100 % the graph covers exactly the range an error can reach: past half a subdivision, a note belongs to the *next* grid step instead, so there's nothing to show out there. Lower it to zoom in. Purely visual — it never changes what's measured.
- **Statistics window** — how many of the most recent notes feed the stats, so a shaky start to a session doesn't drag down the whole average forever

Because the first two follow the tempo, changing tempo or subdivision mid-session also shifts the "In the zone" percentage you've already accumulated.

### Data
**Clear statistics** resets the counters and the graph without stopping the metronome — useful to start a fresh read mid-session.

### About
App version, and a one-line reminder: no data ever leaves the device, no account, no analytics, no microphone access.

---

## 5. A typical calibration + practice session

1. Settings → turn on **Synced start**.
2. Start your keyboard's drum machine and JustRhythm together; listen to both clicks.
3. Settings → Alignment → nudge **Manual correction** until the two clicks merge into one.
4. Play normally. Watch the graph and the stats row build up.
5. If you want a clean read for a specific passage, use **Clear statistics** right before you start it.

---

## 6. What "In the zone" and "Regularity" actually mean

They measure two different things, and mixing them up leads to the wrong fix:

- **Average** tells you if you have a *systematic* habit — always a little ahead or a little behind. That's a bias, and it's corrected by consciously adjusting when you play, not by practicing more of the same.
- **Regularity** tells you how *scattered* your notes are around wherever your average sits, even if that average is exactly zero. That's inconsistency, and it's a different problem — more repetition and more control, not a timing adjustment.

A high "In the zone" percentage with a non-zero average means you're being penalized for a bias that dodges around inside a wide enough tolerance zone — worth checking the Average figure specifically, not just the percentage.

Both thresholds — the "right" zone and the regularity limit — scale with the grid rather than sitting at a fixed number of milliseconds, and both stop scaling at a floor (20 ms and 15 ms respectively). The reasoning is the same in each case: a percentage alone would eventually demand more precision than a hand can deliver or an ear can hear, so the more forgiving of the two criteria wins. In practice this means a green light on fast sixteenths is genuinely harder to earn than on slow quarter notes — which is the point.
