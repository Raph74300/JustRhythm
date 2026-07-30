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
                syncSection
                instrumentSection
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

    /// Le téléphone sonorise les notes reçues. Rien à voir avec la récompense
    /// ci-dessous : ici tout ce qui est joué sonne, juste ou non. (EX-133)
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
            // l'iPhone, dans la section « Retour clavier » l'instrument. C'est
            // ce qui évite un troisième réglage et un croisement sortie × forme
            // dont une case serait vide. (EX-134)
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
                Text("The iPhone plays every note it receives, with the timbre chosen here — the metronome click and your notes then come out of the same speaker, by the same path. Intended for playing with Local Control off on the instrument: leave it on and you will hear each note twice.")
                Text("On accurate hits, the iPhone can add a note an octave up, or mute everything that misses the zone. This only applies while the metronome is running: stopped, there is no accuracy to judge and every note sounds. Keyboard feedback below is separate — turn both on and you will hear both.")
            }
        }
    }

    /// Une note renvoyée au clavier quand la frappe est juste. (EX-130 / EX-131)
    ///
    /// Chaque niveau ajoute une information et aucun ne répète le précédent :
    /// l'en-tête dit **où** part le son, l'interrupteur **à quelle condition**,
    /// le mode **lequel**. C'est ce qui permet aux libellés de mode de rester
    /// courts sans rien perdre — le sélecteur replié est lu dans le contexte
    /// que les deux lignes du dessus viennent de poser.
    private var feedbackSection: some View {
        Section {
            Toggle("Send a note back on accurate hits", isOn: Binding(
                get: { s.feedbackEnabled },
                set: { s.feedbackEnabled = $0; engine.feedbackSettingChanged() }))

            Picker("Mode", selection: Binding(
                get: { s.feedbackMode }, set: { s.feedbackMode = $0 })) {
                ForEach(FeedbackMode.allCases) { Text($0.label).tag($0) }
            }
            .disabled(!s.feedbackEnabled)
        } header: {
            Text("Keyboard feedback")
        } footer: {
            // L'intention d'abord, commune aux deux modes, puis la consigne
            // propre à celui qui est choisi : celles du Local Control diffèrent
            // d'un mode à l'autre et se contrediraient dans un pavé unique.
            VStack(alignment: .leading, spacing: 8) {
                Text(FeedbackMode.purpose)
                Text(s.feedbackMode.hint)
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
            Text("The two act at different points. The automatic compensation advances the click so it is heard on the beat rather than merely scheduled on it. The manual correction shifts the timestamp of incoming notes, to cancel the input chain's delay — key scan, transport, buffering. It does not move the click: it only changes the measurement.\n\nNever set it by feel: you naturally anticipate by 10 to 30 ms without noticing, and you'd bake that bias into the device's zero point.\n\nReliable method: play a perfectly quantized MIDI file from your keyboard's sequencer and adjust the manual correction until the notes settle on the graph's center line. You are then comparing the measurement against an objective reference instead of your perception. A residual spread of 1 to 2 ms is normal — that's transport jitter. What remains uncompensated is the key scan time, 3 to 10 ms, absent when the sequencer plays but present when you do.")
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
                       in: 1...15, step: 1)
            }

            // (EX-067)
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Displayed scale") {
                    Text(String(format: NSLocalizedString("%d %% · ± %d ms", comment: ""),
                                Int((s.scaleZoom * 100).rounded()),
                                Int((engine.gridPeriod / 2 * s.scaleZoom * 1000).rounded())))
                        .monospacedDigit()
                }
                Slider(value: Binding(get: { s.scaleZoom },
                                      set: { s.scaleZoom = ($0 * 20).rounded() / 20 }),
                       in: 0.25...1, step: 0.05)
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
            Text("Both are expressed relative to the reference grid, because the same error in milliseconds doesn't mean the same thing on a slow quarter note as on a fast sixteenth.\n\nThe “right” zone sets the width of the green band and the basis for the percentage. It tightens on its own as the grid gets finer, but never goes below 20 ms — under that an error stops being audible, so demanding better would be arbitrary.\n\nThe scale is capped at half a subdivision: past that point a note belongs to the next grid step, so there is nothing to show there. Lower it to zoom in; the measurement itself doesn't change. Since both follow the tempo, changing it mid-session also shifts the percentage already accumulated.\n\nThe statistics window limits the summary to the most recent notes, so a hesitant start to a session doesn't weigh it down indefinitely.")
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
