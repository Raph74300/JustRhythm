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
            .navigationTitle("Réglages")
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
                LabeledContent("Clavier") {
                    Text("Aucun détecté").foregroundStyle(.secondary)
                }
            } else {
                Picker("Clavier", selection: Binding(
                    get: { engine.midi.selectedID },
                    set: { engine.midi.connect(uniqueID: $0); s.lastSourceID = $0 })
                ) {
                    ForEach(engine.midi.sources) { Text($0.name).tag($0.id) }
                }
            }

            if let note = engine.midi.lastNote {
                LabeledContent("Dernière note", value: note)
                    .monospacedDigit()
            }

            Picker("Canal écouté", selection: Binding(
                get: { s.midiChannel }, set: { s.midiChannel = $0 })) {
                Text("Tous").tag(0)
                ForEach(1...16, id: \.self) { Text("Canal \($0)").tag($0) }
            }

            Stepper(value: Binding(get: { s.minVelocity },
                                   set: { s.minVelocity = $0 }), in: 1...127) {
                LabeledContent("Vélocité minimale") {
                    Text("\(s.minVelocity)").monospacedDigit()
                }
            }
        } header: {
            Text("Entrée MIDI")
        } footer: {
            if engine.midi.sources.isEmpty {
                Text("Branche le clavier en USB. S'il passe par une interface, vérifie qu'elle est alimentée.")
            } else if engine.midi.selected?.isBluetooth == true {
                Text("Cette source est en Bluetooth : elle ajoute 10 à 20 ms avec une gigue variable. La moyenne en sera faussée ; la régularité, elle, reste exacte. Préfère l'USB.")
            } else {
                Text("Joue une note : elle doit apparaître ci-dessus même métronome à l'arrêt.")
            }
        }
    }

    /// La grille sur laquelle les notes sont jugées. (EX-041 / EX-042)
    private var gridSection: some View {
        Section {
            Picker("Grille de référence", selection: Binding(
                get: { s.subdivision },
                set: { s.subdivision = $0; engine.reanchor() })) {
                ForEach(Subdivision.allCases) { Text($0.label).tag($0) }
            }

            Picker("Temps par mesure", selection: Binding(
                get: { s.beatsPerBar }, set: { s.beatsPerBar = $0 })) {
                Text("Aucun accent").tag(0)
                ForEach(2...12, id: \.self) { Text("\($0)").tag($0) }
            }

            Picker("Timbre du clic", selection: Binding(
                get: { s.clickVoice },
                set: { s.clickVoice = $0; engine.testClick() })) {
                ForEach(ClickVoice.allCases) { Text($0.label).tag($0) }
            }
        } header: {
            Text("Grille et son")
        } footer: {
            Text(s.clickVoice.hint + " Le clic ne sonne que sur les temps, jamais sur les subdivisions.")
        }
    }

    /// Regroupement d'accords. (EX-036 / EX-037)
    private var chordSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Fenêtre d'accord") {
                    Text("\(Int(s.chordWindowMs)) ms").monospacedDigit()
                }
                Slider(value: Binding(get: { s.chordWindowMs },
                                      set: { s.chordWindowMs = $0.rounded() }),
                       in: 0...80, step: 5)
            }
        } header: {
            Text("Accords")
        } footer: {
            Text("Les notes reçues dans cette fenêtre comptent pour un seul événement, daté sur la première, et l'application affiche leur étalement. À 0, chaque note est comptée séparément. Une fenêtre large avale les notes répétées rapides : descends-la si tu travailles des traits.")
        }
    }

    /// Synchronisation sur la boîte à rythmes du clavier. (EX-053 / EX-054)
    private var syncSection: some View {
        Section {
            Toggle("Démarrage synchronisé", isOn: Binding(
                get: { s.syncStart }, set: { s.syncStart = $0 }))

            if let bpm = engine.clockBpm {
                LabeledContent("Tempo reçu") {
                    Text(String(format: "%.1f bpm", bpm)).monospacedDigit()
                }
            }
        } header: {
            Text("Synchronisation")
        } footer: {
            Text("Le métronome part sur le message Start de ta boîte à rythmes, et sa grille est calée exactement sur cet instant. Il suit ensuite l'horloge MIDI du clavier pour ne pas dériver : le message Start donne le départ, pas le tempo.")
        }
    }

    /// Retour sonore sur l'instrument quand la frappe est juste.
    private var feedbackSection: some View {
        Section {
            Toggle("Récompense sonore", isOn: Binding(
                get: { s.feedbackEnabled }, set: { s.feedbackEnabled = $0 }))

            Picker("Mode", selection: Binding(
                get: { s.feedbackMode }, set: { s.feedbackMode = $0 })) {
                ForEach(FeedbackMode.allCases) { Text($0.label).tag($0) }
            }
            .disabled(!s.feedbackEnabled)
        } header: {
            Text("Récompense")
        } footer: {
            Text("En mode octave, une note s'ajoute un octave au-dessus quand la frappe est dans la zone « juste » — pense à laisser le Local Control activé sur l'instrument pour continuer à entendre tes propres notes. En mode muet, c'est l'instrument qui reste silencieux tant que la frappe n'est pas juste ; ça suppose de couper le Local Control, sinon il joue déjà tout seul.")
        }
    }

    private var alignmentSection: some View {
        Section {
            LabeledContent("Compensation automatique") {
                Text("\(Int(engine.outputLatency * 1000)) ms")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Correction manuelle") {
                    Text("\(Int(s.manualAlignmentMs)) ms").monospacedDigit()
                }
                Slider(value: Binding(get: { s.manualAlignmentMs },
                                      set: { s.manualAlignmentMs = $0.rounded() }),
                       in: -60...60, step: 1)
            }

            Button("Tester le son") { engine.testClick() }
        } header: {
            Text("Alignement")
        } footer: {
            Text("Le clic est avancé du retard mesuré de la sortie audio, pour être entendu sur le temps. La correction manuelle s'y ajoute. Ne la règle jamais sur ton ressenti : on anticipe naturellement de 10 à 20 ms, et tu inscrirais ce défaut dans le zéro de l'appareil.\n\nMéthode recommandée : active le démarrage synchronisé, lance la boîte à rythmes du clavier et écoute les deux clics ensemble. Règle la correction manuelle jusqu'à ce qu'ils se confondent. Le son de la boîte à rythmes et celui de tes notes empruntent le même chemin de sortie : les aligner annule la différence entre les deux chaînes audio, ce que le curseur à l'aveugle ne fait que deviner. Il reste le temps de balayage du clavier, 3 à 10 ms, hors de portée de cette méthode.")
        }
    }

    private var toleranceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Zone « juste »") {
                    Text("± \(Int(s.toleranceMs)) ms").monospacedDigit()
                }
                Slider(value: Binding(get: { s.toleranceMs },
                                      set: { s.toleranceMs = $0.rounded() }),
                       in: 5...60, step: 1)
            }

            // (EX-067)
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Échelle affichée") {
                    Text("± \(Int(s.windowMs)) ms").monospacedDigit()
                }
                Slider(value: Binding(get: { s.windowMs },
                                      set: { s.windowMs = ($0 / 10).rounded() * 10 }),
                       in: 40...300, step: 10)
            }

            // (EX-084)
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Fenêtre statistique") {
                    Text("\(s.statsWindow) notes").monospacedDigit()
                }
                Slider(value: Binding(get: { Double(s.statsWindow) },
                                      set: { s.statsWindow = Int(($0 / 10).rounded() * 10) }),
                       in: 20...1000, step: 10)
            }
        } header: {
            Text("Mesure")
        } footer: {
            Text("La zone « juste » donne la largeur de la bande verte et la base du pourcentage. L'échelle resserre ou élargit le graphe sans changer la mesure. La fenêtre statistique limite le bilan aux dernières notes, pour qu'un début de séance hésitant ne le plombe pas indéfiniment.")
        }
    }

    private var dataSection: some View {
        Section {
            Button("Effacer les statistiques", role: .destructive) {
                confirmReset = true
            }
            .confirmationDialog("Effacer les statistiques de la séance ?",
                                isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Effacer", role: .destructive) { engine.resetStats() }
                Button("Annuler", role: .cancel) { }
            }
        } footer: {
            Text("Les compteurs repartent de zéro. Le métronome n'est pas arrêté.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Bundle.main.shortVersion)
        } footer: {
            Text("Aucune donnée ne quitte l'appareil. Aucun compte, aucune mesure d'audience, aucun accès au microphone.")
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
