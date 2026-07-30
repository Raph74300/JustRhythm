# JustRhythm

Native iPhone app for rhythm-accuracy training at the piano. Connect a MIDI
keyboard, and every note is measured against the metronome's beat — in
milliseconds, not just "close enough."

Requires iOS 17+ and a MIDI keyboard (USB, Bluetooth, or a keyboard already
paired in iOS Settings). No microphone permission, no account, no data
collected — see `PrivacyInfo.xcprivacy`.

## What it does

- Tuner-style readout over the last 16 notes — center bar for on-target, a
  triangle each side for early/late (`Views/BiasMeter.swift`). Both sides read
  the range the notes actually land in (mean ± dispersion), not just the
  average, so both triangles light for scattered-but-centered playing that an
  average alone would call perfect — early and late errors cancel out in a mean
- Real-time scrolling graph: a centered plumb line is the beat, notes land
  left (early), right (late), or on the line
- Live stats: note count, average bias, dispersion, percentage in the "right"
  zone
- Metronome with five synthesized click tones, adjustable grid subdivision
  and accent
- **Grid-relative accuracy** — the "right" zone is a percentage of the
  subdivision with a 20 ms floor, and the graph is capped at half a
  subdivision (the point where a note flips to the next grid step). Both
  follow the keyboard's clock when it's being tracked (`Core/Settings.swift`,
  `Tolerance` / `Regularity`)
- **Synced start** — starts on a connected drum machine's MIDI Start message
  and follows its clock, instead of a fixed delay (`Core/RhythmEngine.swift`)
- **Instrument** — the iPhone can voice the notes it receives itself, with one
  of five synthesised timbres, so notes and click share one speaker and one
  latency (`Audio/InstrumentSynth.swift`). Full 88-key range, 64-voice
  polyphony, sustain pedal followed. Meant for playing with Local Control off.
  On accurate hits it can add an octave, or mute everything that misses the
  zone (`Settings.accuracyVoicing`)
- English by default, French automatically when the device is in French
  (`Localizable.xcstrings`); note names switch between letters (C, D, E…) and
  solfège (Do, Ré, Mi…) the same way

Full walkthrough for end users: `Tutorial/user-manual.md`
(`Tutorial/manuel-utilisateur.md` in French).

## Project structure

```
JustRhythm/
├── JustRhythmApp.swift       — @main entry point
├── Core/                     — time base, persisted settings, measurement engine
├── MIDI/                     — MIDI input (sources, parsing, timestamping)
├── Audio/                    — click synthesis and sample-accurate scheduling
├── Views/                    — SwiftUI screens
├── Assets.xcassets, Localizable.xcstrings, PrivacyInfo.xcprivacy, Info.plist
└── Tutorial/                 — reference docs (see below)
```

The Xcode group is file-system synchronized (`PBXFileSystemSynchronizedRootGroup`):
moving a file on disk is enough, no project file surgery needed.

## Reference docs (`Tutorial/`)

- `cahier-des-charges-just-rhythm-natif.xlsx` — the actual spec: requirements
  (`Exigences`, one row per need with an `EX-NNN` id, priority and phase),
  tunable parameters (`Paramètres`), and a decision log (`Risques et
  décisions`) explaining *why*, not just what. Every non-trivial piece of code
  references its requirement id in a comment (`// (EX-053)`) — start a new
  spreadsheet from this one for the next project rather than from scratch.
- `guide-publication-app-store.md` — the actual App Store submission
  playbook, with the real pitfalls hit along the way (missing distribution
  certificate, encryption compliance popup, orientation lock). Reusable as-is
  for the next app on the same developer account.
- `user-manual.md` / `manuel-utilisateur.md` — end-user documentation,
  English and French. Keep the two in step: a fix in one belongs in the other.
- `instructions-projet.md`, `parcours-etapes.md` — the original learning
  path this project was built from.

## Naming, for the next project

Renaming an iOS app touches several independent things — it's normal that
they don't all match:

| What | Where it's set | Who sees it |
|---|---|---|
| Project/target name | Xcode, at creation | nobody |
| `CFBundleName` | Target Info | nobody |
| `CFBundleDisplayName` | Target Info | **the user, under the icon** |
| Bundle Identifier | Signing & Capabilities | Apple, permanently |

The Bundle Identifier — `dev.oundjian.nomdelapp` — **cannot change after
publication**. Pick it before the first submission. The convention for every
app under this developer account: `dev.oundjian.*`, one explicit App ID per
app, never a wildcard (breaks push, iCloud, App Groups, in-app purchases,
Sign in with Apple).

"Rythm" isn't a word in English (*rhythm*) or French (*rythme*) — it hurts
App Store search and reads as careless. Kept here because renaming after
publication isn't practical; worth getting right from the start next time.
