# Changelog

All notable changes to JustRhythm are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project aligns its version numbers with the requirements document
(`cahier-des-charges-just-rhythm-natif.xlsx`), not with semantic versioning.

## [Unreleased]

## [2.8] — 2026-08-04

### Fixed
- **The note marker stops lying about the zone's edge** — Reported as notes sounding in "mute the others" while sitting slightly outside the green band. The sound gate and the drawn edge use the same number — verified at every tempo, the difference is zero — but the marker was four points wide and centred on its deviation, so it overflowed the point it designates by two points on each side. On sixteenths, where the twenty-millisecond floor leaves the zone about ten points wide either side of the line, those two points are a fifth of it: a note comfortably inside looked like it was biting the edge. The zone's hairlines are now drawn **over** the notes rather than under them — a reference a datum can cover is not a reference. Narrowing the marker to two points was tried for the same reason and reversed after playing: the notes became too discreet, which costs more than the precision it bought at the edge.
- **Internal documents no longer ship inside the app** — The requirements spreadsheet, the changelog, the README, both user manuals, the publication guide, the tooling scripts and the App Store screenshots were all being copied into the app bundle by the synchronized file group. An `.ipa` unzips; the spec and its decision log would have travelled with the app. Excluded from the target.

### Changed
- **The app lies on its side, everywhere** — Landscape is no longer reserved for full-screen mode; it is the only orientation, settings sheet included. A cable, even a right-angled one, butts against the music stand while the phone stands upright. Landscape-in-full-screen-only did not solve it: you still had to stand the phone up to change a tempo. (EX-004)
- **The measuring screen is two columns** — Two thirds on the left for the graph and the one-word readout, one third on the right for keyboard, subdivision, tempo, Start and the two volumes. Stacked vertically none of it fits in the 400 points a screen on its side has to give. The navigation bar goes with the change — 44 of those points for a title nobody reads — and the gear moves into the sidebar. The trade is not a consolation prize: the graph's width is what carries the resolution of the deviation, and it goes from 390 points to more than 600. A 10 ms lead used to land inside two pixels. (EX-138)
- **The readout is the word alone, plumb on the line** — The three tuner lights said what the word says while asking to be learned first, and they cost thirty-six points of height against eighteen. Sitting to their right, the word was pushed off the graph's vertical line; alone, it falls on it within a point. The verdict became the readout's accessibility value, so nothing was lost for VoiceOver. (EX-066)
- **The "right" zone percentage sits on the pictogram line** — It labels a zone, not a graduation, and nothing tied it to a line of its own. The ruler drops from 50 points to 36, and the graph gets fourteen points of scrolling back.

### Added
- **Separate volumes for the click and the instrument, each with its own mute** — They never dosed together: the click has to stay audible under the playing, and the right ratio depends on the timbre as much as on the piece, so a single slider meant choosing which of the two to sacrifice. The module's gain is applied after the soft clip, not before — before, it would have moved the clipping threshold and the timbre would have changed with the level. It defaults to maximum, which is exactly the level the module had when it was not adjustable, so the slider can only attenuate and nothing can be made to clip. The note icon mutes the module using the same switch the Settings sheet owns, not a second notion of silence. (EX-137)

### Removed
- **The statistics leave the playing screen** — The four figures, the full-screen counter, and the Settings "Data" section that erased them. Four figures describing what has just been played invite you to stop and read them, while the whole point of that screen is the gesture in progress. The engine still computes everything; they come back with the export, where reading them is the intent. (EX-080 to EX-083 and EX-085 to phase 2, EX-088)
- **The tempo slider's step track** — `step: 1` over 30 to 240 is two hundred and ten notches drawn across two hundred points, which renders as a solid grey bar. The notches were never needed: the binding already rounds.

## [2.7] — 2026-07-31

### Changed
- **Messages arrive in two parts** — The bar at the bottom of the measuring screen used to show the whole explanation at once, and cut it off at the first line: all that was left was the start of a sentence and an ellipsis. Each message now carries a one-line summary and, separately, the paragraph that tells you what to do. The bar shows the summary — never truncated, it wraps rather than cuts at large text sizes — and a tap unfolds the rest. The explanations stay long on purpose: the one about a missing MIDI clock points at a setting that lives on the instrument, not in the app, and that sentence is what saves you looking in the wrong place. They simply no longer sit four lines deep at the bottom of the screen while you play. (EX-135)
- **A message can be dismissed, and dies with its session** — A cross clears it. Stopping the session clears it too: the missing-clock warning used to survive the session, then the whole time you were not playing, until the next start — describing a situation that no longer existed, with no way to be rid of it. (EX-135)
- **Full-screen mode hides the navigation bar** — The title and the gear survived the switch to full screen. EX-072 asked for everything else to be hidden, status bar included; the criterion was written, it was simply not met. Upright it went unnoticed; on its side those 44 points come out of a total height of about 400. (EX-072)

### Added
- **Landscape in full-screen mode** — For laying the phone across the music stand. Full screen only: it shows nothing but the graph, whose canvas draws itself from whatever size it is given, while the standard layout — a 300-point graph, the statistics row and the whole transport — does not fit in the 390 to 430 points of a screen on its side. Leaving full screen returns to portrait on its own. A toggle button sits alongside automatic rotation, which does not fire while the system's rotation lock is on — and a phone propped on a music stand is exactly where you turn that lock on. (EX-136)

## [2.6] — 2026-07-31

### Changed
- **The graph is a ruler now, one beat wide** — Its width no longer follows the subdivision, so what you see means the same thing at every grid. One beat is exactly the widest deviation a note can reach, so the frame is neither arbitrary nor too large. Three zones: grey out of reach — a note further off belongs to the next grid step — orange measurable, green the "right" zone, each boundary marked by a hairline so the meaning never rests on colour alone. The share of grey therefore reads the demand of your grid without a single figure: none on quarter notes, three quarters of the width on sixteenths. Reported after hours of playing: "it feels like I missed completely, when we are talking about −20 ms". (EX-067)
- **A ruler in note values** — Along the bottom, half the width is an eighth note, a quarter a sixteenth, an eighth a thirty-second; in triplet mode a third and a sixth of a beat, marked with a 3. Marks out of reach are dimmed. You read your error as music — "late by a sixteenth" is something you can correct, "late by 47 ms" is not. The glyphs are drawn rather than typed: Unicode has no standalone thirty-second note, and the flag counts have to be told apart at a glance.
- **Settings say less, the manual says more** — Every footer was cut to what you need at the moment you touch the setting; one still described a scale slider that no longer exists, another ran to three paragraphs. The detail moved to the user manual in both languages, including a step-by-step for measuring the alignment with a microphone. Measurement also moves up between Grid and Synchronization: the "right" zone gets retouched at every change of exercise, alignment gets set once.

### Removed
- **The scale slider** — A reference you can move is not a reference. The cost is real: on a fine grid the notes crowd into a quarter of the width, which is a true statement about what you asked for and still harder to read. (EX-067)
- **Chord grouping** — Merging notes that arrived close together hid the thing worth seeing, whether a chord is actually together, and it absorbed the second note of any slightly overlapping legato — which is most legato played by a human. The measurement was losing exactly the notes an imperfect passage is made of. Every note is now measured on its own and their spread is read off the graph, which the fixed scale finally makes possible. (EX-036, EX-037 retired)
- **The brace under the "right" zone** — It pointed the wrong way, and it repeated what the green band already shows over the full height. Only the percentage remains.

## [2.5] — 2026-07-30

### Added
- **Instrument — the iPhone voices your notes** — A new setting makes the iPhone sound every note it receives with a timbre of your choosing: piano, electric piano, harpsichord, acoustic guitar or marimba. Notes and metronome click then leave by the same speaker and the same path, so there is nothing to correct between them. Intended for playing with Local Control off on the instrument. Full 88-key range, 64-voice polyphony, sustain pedal followed; a test button plays a note without starting a session. Sounds are synthesised in the app — nothing is bundled, downloaded or stored. (EX-133)
- **Accuracy marking on the iPhone's own voice** — On accurate hits the instrument can add a note an octave up, or mute everything that misses the zone. It applies only while the metronome is running: stopped, there is no accuracy to judge and every note sounds. The app being the voice here, it can genuinely mute a note — something a return sent to the instrument never could, since what you heard depended on Local Control, a setting outside the app's reach. (EX-134)

### Changed
- **The "right" zone opens up to 30 %** — It stopped at 15 %, which on a fine grid asks for a precision nobody has starting out: on sixteenths at 60 bpm the zone was ±38 ms, and an indicator that never turns green teaches nothing. It now reaches ±75 ms there. The ceiling is 30 % because half a subdivision is where a note already belongs to the next grid step — a zone reaching that far would call everything accurate. Widening changes only the green band, the percentage and the readout: each note's position on the graph, the average and the dispersion stay exactly as measured, so a teacher can loosen it without the instrument ever having lied. (EX-063)
- **Alignment correction is now two values, and the app picks** — The input correction was a single figure, while its right value differs by about 15 ms depending on whether the keyboard's clock is being followed: when the instrument transmits clock, its real-time messages take priority in its output queue, so keystrokes leave behind them and the input chain really is longer. You had to change the setting on every switch, and forgetting cost a systematic, silent error — precisely what the app exists to reveal rather than produce. Two values are now remembered and the app applies the right one, with a marker showing which is in force. Each is set once, by measurement: record the key's mechanical thud and the iPhone's sound together, subtract the automatic compensation from the interval, enter the remainder as a negative value. (EX-035)

### Removed
- **Three figures under the readout** — The average error in milliseconds below the verdict, the chord-spread line under it, and the percentage doubling the standard deviation in the Dispersion cell are all gone. Each was defensible on its own; together they cluttered exactly the area meant to be taken in at a glance while playing. The readout is now three lights and one word; Dispersion carries a single number. The average figure had mostly served to set the alignment, a use made obsolete by measuring the correction with a microphone instead. Chord spread is still computed and kept — only its display goes, so EX-037 returns to being a phase 2 requirement that can be reopened without writing any code. (EX-066, EX-082, EX-089)
- **Beats per bar, and accents with it** — The accent needed a time signature the MIDI protocol does not transmit: with external sync the app cannot know the drum machine is playing a waltz, so the setting had to be matched by hand and a mismatch produced an accent contradicting the music — worse than none. Removed at the user's request after use; all clicks are now identical, and the accented variant of the five timbres goes with it. Worth noting for next time: this setting had just been repaired — it had been broken in sync since v2.2 — and getting it working is what revealed it was not wanted. (EX-042 retired)

### Fixed
- **Accents come back when following the keyboard's clock** — With sync active, no downbeat was heard at all and the bar length meant nothing. `stepIndex` was serving two incompatible purposes: the offset from the anchor point, which clock following resets on every received beat so that measurement noise cannot be amplified by its growth (the v2.2 drift fix), and the position within the bar. Reset every beat, it never got past two or three, so it could never land on a multiple of the steps-per-bar. Musical position now lives in its own counter, anchored on the beat count since Start — which means "from the beginning" and therefore gives the downbeat. Verified in 4/4, 3/4 and 6/8, at every subdivision. (EX-042)
- **A synced start with no clock now says so** — The Start message gives the downbeat, never the tempo; without a MIDI clock behind it the app started on the right instant then ran at its own tempo and drifted from the drum machine. Nothing distinguished that from a fault, since the start itself worked. Two beats after a synced start with no usable clock, the app now says so and points at the instrument's clock-transmission setting. The pulse divider also resets on Start, so the first announced beat no longer lands at an arbitrary phase. (EX-053, EX-054)
- **The app no longer falls behind on dense playing** — Playing sixteenth notes for a few minutes could leave the graph blank while the metronome kept clicking, recovering on its own after a pause. Two causes, both on the main queue. Every MIDI clock pulse crossed it — 32 a second at 80 bpm — only to advance a counter and return 23 times out of 24; the division now happens on the receiving thread, so one crossing per beat instead. And every MIDI packet was copied into an array before parsing, an allocation per message on CoreMIDI's real-time thread; the buffer is now parsed in place. A note handled late keeps its hardware timestamp, so its measured error stayed correct — it was simply drawn where that instant put it, already off the bottom of the graph. (EX-100)
- **A backlog now says so** — Notes handled more than 250 ms after their timestamp raise a message naming the delay, and the audio guards report when they have had to drop work. What used to surface only as "the app seems to saturate" now names the subsystem.
- **Errors in the Instrument section are now visible where they happen** — A failure used to post its message to the measurement screen, behind the Settings sheet: the switch appeared to simply refuse to turn on, with no explanation available.
- **The instrument timbre is no longer re-staged on every note** — `prepareInstrument` sits on the per-note path and rebuilt the whole recipe each time, allocating while holding the lock the audio thread needs. Measured at 0.024 µs per note it was not the cause of the backlog above, but allocating under an audio lock is an inversion worth removing on its own.

### Removed
- **Keyboard feedback, in full** — Sending a MIDI note back to the instrument on an accurate hit is gone, and with it every MIDI output from the app: the link to the keyboard is now one-way and can no longer loop back on itself. Built, reworked three times, then withdrawn. Every attempt ran into a setting on the keyboard rather than a fault in the code — Local Control decided what you actually heard, to the point where the "muted" mode was untrue in the factory configuration; the note's length never found a right value, through a flat 150 ms, then two thirds of the subdivision, then following the key release; and the instrument's own MIDI echo ("Soft Thru") looped back whatever was sent, judged and returned without end. Each fix uncovered the next dependency. The need is better served by the iPhone voicing the notes itself (EX-133 / EX-134), which reaches the same goal while assuming nothing about the instrument. Synced start is kept — it runs the other way and never had this problem. (EX-130, EX-131 retired)
- **Reward ping on the iPhone speaker** — Built, then withdrawn. Playing the reward through the metronome's own audio engine worked technically, but proved unusable from eighth notes on: a ping bursting in on every accurate hit covers the click instead of blending with it, you lose the thread of the metronome, and the app feels like it is malfunctioning while doing exactly what it was asked. Replaced by the Instrument setting above, which is continuous and expected, and reaches the same goal. (see the decision log)

## [2.4] — 2026-07-29

### Fixed
- **MIDI clock sync drift** — The grid now remains stable over long sessions without accumulating errors from the smoothed period estimate. Phase and period corrections are applied separately: period is smoothed to reject jitter, phase is clamped to ±20ms per anchor to prevent step-index error amplification. Intervals outside the 20–300 bpm range are ignored as noise. (EX-053, EX-054 / v2.2)
- **Note counter stuck at window size** — Counter now shows cumulative notes in the session, not the size of the sliding window. Visible throughout long sessions without topping out. (EX-080)
- **MIDI source fallback now temporary** — When a keyboard fails to enumerate at launch, the app falls back to the first available source; on the next scan, the remembered keyboard is prioritized and the fallback is released. Previously the fallback was permanent, locking out the intended source. (EX-013)

### Changed
- **Instant readout: tuner display replaces last-note value** — The last note's error bounced erratically with every keystroke and could not be used to correct during play. Replaced by a tuner-style indicator (three lights: left/bar/right triangle) fed by the mean and dispersion of the last 16 notes. Both sides light independently, distinguishing a systematic bias (one triangle steady) from scattered play centered on the beat (both triangles flickering). Adds a "Verdict" label: "Ready" (on-target), "Early/Late" (systematic bias), or "Scattered" (high dispersion but centered). (EX-066, EX-089)
- **Grid and tolerance now follow keyboard MIDI clock** — When synchronized start is enabled, both the grid period and tolerance now track the keyboard's MIDI clock instead of the manually-set tempo, preventing drift relative to the external reference. (EX-054)
- **Keyboard tempo is adopted and persists** — A deliberate tempo change on the keyboard is now tracked in a single beat instead of twenty, and the new tempo persists in the app after the sync ends — keyboard tempo acts as a shortcut to the manual control. (EX-054)

## [2.3] — 2026-07-29

### Changed
- **Tolerance as percentage of subdivision** — The "correct" zone now scales with the grid subdivision instead of remaining fixed in milliseconds. Expressed as a percentage of the note's duration with a minimum floor of 20 ms (the threshold below which the human ear cannot distinguish timing). A tight tolerance at 60 bpm no longer becomes unconscionably strict at 120 bpm. The same percentage logic applies to the dispersion threshold (EX-082). (EX-063)
- **Horizontal scale clamped to half-subdivision** — The scale slider cannot zoom beyond the smallest gap an error could occupy, eliminating empty space on the display and preventing false precision claims. (EX-067)

## [2.2] — 2026-07-28

### Fixed
- **MIDI clock sync: race condition on grid state** — Grid anchor, period, step index, and next-step time were written from the scheduling queue and read from the main queue without synchronization. Added NSLock protection on all four state variables. Without this fix, note placement becomes incoherent and drifts differently on every run when sync is active — very difficult to diagnose. (EX-053)
- **MIDI clock sync: step-index error amplification** — Recalculating `nextStep = anchor + stepIndex * newPeriod` at each correction multiplied measurement noise by step index, which only grows during the session. A few tenths of milliseconds of jitter became tens of milliseconds of drift within a minute. Fixed by anchoring locally at each phase correction and resetting step index to 0, so error is bounded by the phase correction (±20 ms) and cannot be amplified by session duration. (EX-054)

### Changed
- **Start button disables while waiting for sync trigger** — When synchronized start is enabled but the keyboard's Start message has not yet arrived, the Start button is disabled to prevent confusion. (EX-053)
- **Multiple MIDI channels supported** — The app now listens to all MIDI channels by default, or can be restricted to a selected subset. Previously it accepted only a single channel. (EX-017)

## [2.1] — 2026-07-28

### Added
- **Localization: English and French** — The app's language follows the iPhone's system language setting via the Localizable String Catalog. Musical note names adapt to the locale (C/D/E vs. Do/Ré/Mi). (EX-003, EX-130, EX-131)
- **Reward feedback on accurate hits** — Optional feedback on the keyboard when a note lands in the tolerance zone. Two modes: the note is echoed an octave higher, or the keyboard stays silent if the note is out of tolerance (requires Local Control off on the instrument). Activable from Settings. (EX-130, EX-131)

### Changed
- **Synchronized start and clock follow merged into one setting** — "Synced start" now enables both the Start trigger and clock following together. They are never used independently in practice; the merger simplifies the Settings interface. (EX-053, EX-054)

## [2.0] — 2026-07-27

### Added
- **Native iOS application** — Complete rewrite from web-based prototype to SwiftUI on iOS 17+. All UI uses system vocabulary: semantic colors (light/dark theme, high-contrast mode, accessibility settings), system typeface, system icons, dynamic type. (EX-110 to EX-118)
- **App Store publication support** — Lifecycle and signing documentation, privacy policy, icon generation tooling. (EX-120 to EX-124)

### Changed
- **Settings reorganized** — Play-time controls (tempo, click on/off, volume) remain on the main screen. Configuration settings (keyboard, grid, alignment, tolerance, sync) are now behind a Settings button. (EX-096)
- **Spec scope narrowed** — Phase 1 reduced to ~40 core requirements. Features deferred to Phase 2 are documented; features tried and abandoned are recorded in the decision log with their failure reasons (not reproposed later). (Risques et décisions, cahier-des-charges)

### Removed
- **Custom visual identity** — Proprietary palette, imported fonts, hand-drawn frames abandoned. UI now exclusively uses system colors and typography, which adapt automatically to theme, contrast, and accessibility preferences. (Risques et décisions)
- **Haptic feedback on correct note** — Implemented and tested but removed: rhythm accuracy is an auditory skill; haptics arrive after the note and do not communicate how far off the timing was. (Risques et décisions)
- **Landscape orientation** — Requested for cable-up phone placement, but iOS Face ID iPhones do not rotate their system chrome in landscape, making rotation a poor user experience. Workaround: USB cable adapter. (Risques et décisions)

## [1.0] — 2026-07-27

Initial release. Functional prototype with custom visual identity (palette, imported fonts, drawn UI). Real-time MIDI measurement, scrolling graph, live statistics, Settings.

---

## Version Numbering

App Store versions (1.0, 2.4, etc.) are aligned with the requirements document, not semantic versioning. This allows users who report "I'm on 2.4" to point directly to a specific state of the spec and all decisions that led to it.

The build number is always incremented before archiving for TestFlight or App Store, even if the marketing version does not change (e.g., a bug fix before first release moves from 1.0(2) to 1.0(3)).
