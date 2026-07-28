import SwiftUI

/// Ce qu'on règle une fois, par opposition à ce qu'on touche en jouant.
///
/// Le partage est délibéré : tempo, clic et volume restent sur l'écran de
/// mesure parce qu'on les ajuste au milieu d'un morceau ; clavier, alignement
/// et tolérance vivent ici parce qu'on les fixe puis qu'on les oublie.
struct SettingsView: View {

    let engine: RhythmEngine
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    private var s: Settings { engine.settings }

    var body: some View {
        NavigationStack {
            Form {
                keyboardSection
                gridSection
                syncSection
                feedbackSection
                chordSection
                alignmentSection
                toleranceSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    // =====================================================================

    private var keyboardSection: some View {
        Section {
            if engine.midi.sources.isEmpty {
                LabeledContent("Keyboard") {
                    Text("None detected").foregroundStyle(.secondary)
                }
            } else {
                Picker("Keyboard", selection: Binding(
                    get: { engine.midi.selectedID },
                    set: { engine.midi.connect(uniqueID: $0); s.lastSourceID = $0 })
                ) {
                    ForEach(engine.midi.sources) { Text($0.name).tag($0.id) }
                }
            }

            if let note = engine.midi.lastNote {
                LabeledContent("Last note", value: note)
                    .monospacedDigit()
            }

            Picker("Listened channel", selection: Binding(
                get: { s.midiChannel }, set: { s.midiChannel = $0 })) {
                Text("All").tag(0)
                ForEach(1...16, id: \.self) { n in
                    Text(String(format: NSLocalizedString("Channel %d", comment: ""), n)).tag(n)
                }
            }

            Stepper(value: Binding(get: { s.minVelocity },
                                   set: { s.minVelocity = $0 }), in: 1...127) {
                LabeledContent("Minimum velocity") {
                    Text("\(s.minVelocity)").monospacedDigit()
                }
            }
        } header: {
            Text("MIDI Input")
        } footer: {
            if engine.midi.sources.isEmpty {
                Text("Connect the keyboard via USB. If it goes through an interface, make sure it's powered.")
            } else if engine.midi.selected?.isBluetooth == true {
                Text("This source is Bluetooth: it adds 10 to 20 ms with variable jitter. The average will be skewed; regularity, though, stays accurate. Prefer USB.")
            } else {
                Text("Play a note: it should appear above, even with the metronome stopped.")
            }
        }
    }

    /// La grille sur laquelle les notes sont jugées. (EX-041 / EX-042)
    private var gridSection: some View {
        Section {
            Picker("Reference grid", selection: Binding(
                get: { s.subdivision },
                set: { s.subdivision = $0; engine.reanchor() })) {
                ForEach(Subdivision.allCases) { Text($0.label).tag($0) }
            }

            Picker("Beats per bar", selection: Binding(
                get: { s.beatsPerBar }, set: { s.beatsPerBar = $0 })) {
                Text("No accent").tag(0)
                ForEach(2...12, id: \.self) { Text("\($0)").tag($0) }
            }

            Picker("Click tone", selection: Binding(
                get: { s.clickVoice },
                set: { s.clickVoice = $0; engine.testClick() })) {
                ForEach(ClickVoice.allCases) { Text($0.label).tag($0) }
            }
        } header: {
            Text("Grid & sound")
        } footer: {
            Text(s.clickVoice.hint + String(localized: " The click only sounds on the beat, never on subdivisions."))
        }
    }

    /// Regroupement d'accords. (EX-036 / EX-037)
    private var chordSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Chord window") {
                    Text("\(Int(s.chordWindowMs)) ms").monospacedDigit()
                }
                Slider(value: Binding(get: { s.chordWindowMs },
                                      set: { s.chordWindowMs = $0.rounded() }),
                       in: 0...80, step: 5)
            }
        } header: {
            Text("Chords")
        } footer: {
            Text("Notes received within this window count as a single event, timestamped on the first one, and the app shows their spread. At 0, each note is counted separately. A wide window swallows fast repeated notes: lower it if you're working on rapid passages.")
        }
    }

    /// Synchronisation sur la boîte à rythmes du clavier. (EX-053 / EX-054)
    private var syncSection: some View {
        Section {
            Toggle("Synced start", isOn: Binding(
                get: { s.syncStart }, set: { s.syncStart = $0 }))

            if let bpm = engine.clockBpm {
                LabeledContent("Tempo received") {
                    Text(String(format: "%.1f bpm", bpm)).monospacedDigit()
                }
            }
        } header: {
            Text("Synchronization")
        } footer: {
            Text("The metronome starts on your drum machine's Start message, and its grid is anchored exactly on that instant. It then follows the keyboard's MIDI clock to avoid drifting: the Start message gives the downbeat, not the tempo.")
        }
    }

    /// Retour sonore sur l'instrument quand la frappe est juste.
    private var feedbackSection: some View {
        Section {
            Toggle("Sound reward", isOn: Binding(
                get: { s.feedbackEnabled }, set: { s.feedbackEnabled = $0 }))

            Picker("Mode", selection: Binding(
                get: { s.feedbackMode }, set: { s.feedbackMode = $0 })) {
                ForEach(FeedbackMode.allCases) { Text($0.label).tag($0) }
            }
            .disabled(!s.feedbackEnabled)
        } header: {
            Text("Reward")
        } footer: {
            Text("In octave mode, a note is added an octave higher when the hit lands in the “right” zone — remember to leave Local Control on so you keep hearing your own notes. In mute mode, the instrument stays silent until the hit is accurate; that requires turning Local Control off, otherwise it's already sounding on its own.")
        }
    }

    private var alignmentSection: some View {
        Section {
            LabeledContent("Automatic compensation") {
                Text("\(Int(engine.outputLatency * 1000)) ms")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Manual correction") {
                    Text("\(Int(s.manualAlignmentMs)) ms").monospacedDigit()
                }
                Slider(value: Binding(get: { s.manualAlignmentMs },
                                      set: { s.manualAlignmentMs = $0.rounded() }),
                       in: -60...60, step: 1)
            }

            Button("Test the sound") { engine.testClick() }
        } header: {
            Text("Alignment")
        } footer: {
            Text("The click is advanced by the measured audio output delay, so it's heard on the beat. The manual correction adds to that. Never set it by feel: you naturally anticipate by 10 to 20 ms, and you'd bake that bias into the device's zero point.\n\nRecommended method: turn on synced start, start the keyboard's drum machine, and listen to both clicks together. Adjust the manual correction until they merge. The drum machine's sound and your notes' sound take the same output path: aligning them cancels out the difference between the two audio chains, which the blind slider can only guess at. What remains is the keyboard's scan time, 3 to 10 ms, beyond the reach of this method.")
        }
    }

    private var toleranceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("“Right” zone") {
                    Text("± \(Int(s.toleranceMs)) ms").monospacedDigit()
                }
                Slider(value: Binding(get: { s.toleranceMs },
                                      set: { s.toleranceMs = $0.rounded() }),
                       in: 5...60, step: 1)
            }

            // (EX-067)
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Displayed scale") {
                    Text("± \(Int(s.windowMs)) ms").monospacedDigit()
                }
                Slider(value: Binding(get: { s.windowMs },
                                      set: { s.windowMs = ($0 / 10).rounded() * 10 }),
                       in: 40...300, step: 10)
            }

            // (EX-084)
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Statistics window") {
                    Text("\(s.statsWindow) notes").monospacedDigit()
                }
                Slider(value: Binding(get: { Double(s.statsWindow) },
                                      set: { s.statsWindow = Int(($0 / 10).rounded() * 10) }),
                       in: 20...1000, step: 10)
            }
        } header: {
            Text("Measurement")
        } footer: {
            Text("The “right” zone sets the width of the green band and the basis for the percentage. The scale narrows or widens the graph without changing the measurement. The statistics window limits the summary to the most recent notes, so a hesitant start to a session doesn't weigh it down indefinitely.")
        }
    }

    private var dataSection: some View {
        Section {
            Button("Clear statistics", role: .destructive) {
                confirmReset = true
            }
            .confirmationDialog("Clear this session's statistics?",
                                isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Clear", role: .destructive) { engine.resetStats() }
                Button("Cancel", role: .cancel) { }
            }
        } footer: {
            Text("The counters reset to zero. The metronome isn't stopped.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Bundle.main.shortVersion)
        } footer: {
            Text("No data leaves the device. No account, no audience measurement, no microphone access.")
        }
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

#Preview {
    SettingsView(engine: RhythmEngine())
}
