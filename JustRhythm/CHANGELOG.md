# Changelog

All notable changes to JustRhythm are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project aligns its version numbers with the requirements document
(`cahier-des-charges-just-rhythm-natif.xlsx`), not with semantic versioning.

## [Unreleased]

## [2.5] — 2026-07-30

### Added
- **Instrument — the iPhone voices your notes** — A new setting, separate from keyboard feedback, makes the iPhone sound every note it receives with a timbre of your choosing: piano, electric piano, harpsichord, acoustic guitar or marimba. Notes and metronome click then leave by the same speaker and the same path, so there is nothing to correct between them. Intended for playing with Local Control off on the instrument. The sustain pedal is followed; 24-voice polyphony; a test button plays a note without starting a session. Sounds are synthesised in the app — nothing is bundled, downloaded or stored. (EX-133)

### Changed
- **Keyboard feedback now lasts exactly as long as your gesture** — The note sent back on an accurate hit starts on key press and stops on key release, instead of running for a fixed duration. Previous attempts — 150 ms flat, then two thirds of the subdivision — both broke down in real music, where note lengths do not follow the grid: from sixteenth notes on, the returned note stopped being a confirmation and became noise. No duration is computed at all any more. Nothing outlives its trigger: notes are released on stop, when the setting is switched off, and if the keyboard disappears. (EX-130, EX-131)
- **Settings renamed to say what happens** — "Reward / Sound reward" becomes "Keyboard feedback / Send a note back on accurate hits", and the two modes become "Octave note" and "Same note". The former "Note muted if inaccurate" was untrue in the factory configuration: with Local Control on nothing is muted, and accurate hits are in fact reinforced — the opposite of what the name announced. Labels now describe what the app emits; what you need to configure to get the effect you want lives in the footer. (EX-130, EX-131)

### Fixed
- **Errors in the Instrument section are now visible where they happen** — A failure used to post its message to the measurement screen, behind the Settings sheet: the switch appeared to simply refuse to turn on, with no explanation available.

### Removed
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
