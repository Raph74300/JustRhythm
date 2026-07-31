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

    private var channelSummary: String {
        let channels = s.midiChannels.sorted()
        if channels.isEmpty { return String(localized: "All") }
        if channels.count <= 4 { return channels.map(String.init).joined(separator: ", ") }
        return String(format: NSLocalizedString("%d channels", comment: ""), channels.count)
    }

    var body: some View {
        NavigationStack {
            Form {
                keyboardSection
                gridSection
                // Ce qu'on retouche en changeant d'exercice vient en premier :
                // la zone « juste » se règle bien plus souvent que l'alignement,
                // qui ne se pose qu'une fois.
                toleranceSection
                syncSection
                instrumentSection
                alignmentSection
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

            NavigationLink {
                ChannelSelectionView(settings: s)
            } label: {
                LabeledContent("Listened channels", value: channelSummary)
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
                Text("Bluetooth adds 10 to 20 ms of variable delay. Your average will be skewed — your regularity stays accurate. Prefer USB.")
            } else {
                Text("Play a note: it should appear above, even with the metronome stopped.")
            }
        }
    }

    /// La grille sur laquelle les notes sont jugées. (EX-041)
    private var gridSection: some View {
        Section {
            Picker("Reference grid", selection: Binding(
                get: { s.subdivision },
                set: { s.subdivision = $0; engine.reanchor() })) {
                ForEach(Subdivision.allCases) { Text($0.label).tag($0) }
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
            Text("The metronome starts on your drum machine's Start message and then follows its MIDI clock. Start gives the downbeat, never the tempo — without a clock behind it, the two drift apart.")
        }
    }

    /// Le téléphone sonorise les notes reçues : tout ce qui est joué sonne,
    /// juste ou non, l'option de justesse ne faisant que nuancer. (EX-133)
    private var instrumentSection: some View {
        Section {
            Toggle("Play notes on the iPhone", isOn: Binding(
                get: { s.instrumentEnabled },
                set: { s.instrumentEnabled = $0; engine.instrumentSettingChanged() }))

            Picker("Sound", selection: Binding(
                get: { s.instrumentVoice },
                set: { s.instrumentVoice = $0; engine.instrumentSettingChanged() })) {
                ForEach(InstrumentVoice.allCases) { Text($0.label).tag($0) }
            }
            .disabled(!s.instrumentEnabled)

            // L'option de justesse appartient à ce qui produit le son : ici
            // l'iPhone, seule source de son que l'application pilote. (EX-134)
            Picker("On accurate hits", selection: Binding(
                get: { s.accuracyVoicing }, set: { s.accuracyVoicing = $0 })) {
                ForEach(AccuracyVoicing.allCases) { Text($0.label).tag($0) }
            }
            .disabled(!s.instrumentEnabled)

            Button("Test the instrument") { engine.testInstrument() }
                .disabled(!s.instrumentEnabled)

            // Un échec ici repose l'interrupteur : sans ce rappel, il paraît
            // simplement refuser de s'activer, et l'explication reste sur
            // l'écran de mesure, derrière cette feuille — invisible au moment
            // précis où elle servirait.
            if let message = engine.message {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        } header: {
            Text("Instrument")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your notes and the click then come out of the same speaker, by the same path. Meant for playing with Local Control off on the instrument: leave it on and you hear every note twice.")
                Text("The accuracy option applies only while the metronome runs: stopped, there is nothing to judge and every note sounds.")
            }
        }
    }

    private var alignmentSection: some View {
        Section {
            LabeledContent("Automatic compensation") {
                Text("\(Int(engine.outputLatency * 1000)) ms")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            correctionRow("iPhone clock", value: s.manualAlignmentMs,
                          active: !engine.alignmentFollowsClock) { s.manualAlignmentMs = $0 }

            correctionRow("Keyboard clock", value: s.syncAlignmentMs,
                          active: engine.alignmentFollowsClock) { s.syncAlignmentMs = $0 }

            Button("Test the sound") { engine.testClick() }
        } header: {
            Text("Alignment")
        } footer: {
            Text("These shift the timestamp of incoming notes to cancel the input chain's delay. They never move the click. Two values, because the chain really is longer when the instrument transmits its clock — the app applies whichever fits.\n\nNever set them by feel: you anticipate by 10 to 30 ms without noticing, and you would write that bias into the zero. Measure them once; the manual gives the method.")
        }
    }

    /// Une correction, marquée quand c'est elle qui s'applique.
    private func correctionRow(_ title: LocalizedStringKey, value: Double,
                               active: Bool, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                Text("\(Int(value)) ms").monospacedDigit()
            } label: {
                HStack(spacing: 6) {
                    Text(title)
                    // Le repère dit laquelle est concernée : sans lui, deux
                    // valeurs voisines n'apprendraient rien de plus qu'une
                    // seule, et il faudrait deviner. (EX-117 : jamais la
                    // couleur seule — c'est un symbole doublé d'un libellé.)
                    if active {
                        Label("in force", systemImage: "checkmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.tint)
                            .accessibilityLabel(Text("in force"))
                    }
                }
            }
            Slider(value: Binding(get: { value }, set: { set($0.rounded()) }),
                   in: -60...60, step: 1)
        }
    }

    private var toleranceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("“Right” zone") {
                    // Sur une grille fine, le plancher l'emporte sur le
                    // pourcentage : sans ce repère, le curseur semblerait
                    // sans effet.
                    Text(String(format: NSLocalizedString(
                        engine.tolerance == Tolerance.floor ? "%d %% · ± %d ms (min)" : "%d %% · ± %d ms",
                        comment: ""),
                                Int(s.tolerancePercent),
                                Int((engine.tolerance * 1000).rounded())))
                        .monospacedDigit()
                }
                Slider(value: Binding(get: { s.tolerancePercent },
                                      set: { s.tolerancePercent = $0.rounded() }),
                       in: 1...30, step: 1)
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
            Text("The graph is one beat wide, always — so what you see means the same at every subdivision. Grey is out of reach: a note further off belongs to the next grid step. Orange is what your grid can measure, green is the “right” zone, and the note values along the bottom read your error as an eighth, a sixteenth, a thirty-second.\n\nThe zone is a share of the grid rather than a fixed delay, and never narrower than 20 ms. Open it up for a beginner: widening it moves the green band and the percentage, never the measurement.\n\nThe statistics window keeps the summary on your recent notes.")
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
