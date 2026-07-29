import SwiftUI

struct MainView: View {

    @State private var engine = RhythmEngine()
    @State private var showSettings = false
    @State private var immersive = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            content
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("JustRhythm")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(String(localized: "Settings"))
                    }
                }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(engine: engine)
        }
        .statusBarHidden(immersive)
        .persistentSystemOverlays(immersive ? .hidden : .automatic)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && engine.running { engine.stop() }
        }
    }

    // =====================================================================

    @ViewBuilder private var content: some View {
        if immersive {
            immersiveLayout
        } else {
            standardLayout
        }
    }

    private var standardLayout: some View {
        VStack(spacing: 16) {
            readout

            scope
                .frame(height: 300)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            StatsGrid(engine: engine)

            Spacer(minLength: 0)

            transport
        }
        .padding(.horizontal, 16)
        // Les voyants remplissent leur cadre de bord à bord, sans l'interligne
        // qui aérait le chiffre qu'ils remplacent : sans cette marge, ils
        // viennent toucher la barre de navigation.
        .padding(.top, 28)
        .safeAreaInset(edge: .bottom) { messageBar }
    }

    /// Mode plein écran : plus que la mesure. (EX-072)
    ///
    /// La zone de mesure est la même vue dans les deux modes, jamais une
    /// seconde implémentation : seuls le cadrage et la densité changent.
    private var immersiveLayout: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            scope.ignoresSafeArea()

            VStack {
                HStack {
                    Text(compactValue)
                        .font(.system(.title, design: .rounded, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(currentTint)
                        .contentTransition(.numericText())
                    Spacer()
                    Text(String(format: NSLocalizedString("%d bpm · %@", comment: ""),
                               Int(engine.settings.bpm), engine.settings.subdivision.shortLabel))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)

                Spacer()

                HStack {
                    Text(engine.stats.count > 0
                         ? String(format: NSLocalizedString("%d notes · %d %%", comment: ""),
                                  engine.stats.count, Int(engine.stats.inZone))
                         : "—")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    Button { engine.toggle() } label: {
                        Image(systemName: engine.running ? "stop.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(engine.running ? .secondary : .accentColor)
                    .disabled(engine.settings.syncStart && !engine.running)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }

    private var scope: some View {
        ScopeView(engine: engine)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
                    immersive.toggle()
                }
            }
    }

    // =====================================================================
    // Lecture instantanée (EX-066)
    // =====================================================================

    private var readout: some View {
        VStack(spacing: 6) {
            BiasMeter(placement: engine.recentPlacement, tolerance: engine.tolerance)

            Text(verdict)
                .font(.title3.weight(.medium))
                .foregroundStyle(currentTint)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.25), value: verdict)

            // La valeur chiffrée reste utile — pour régler l'alignement,
            // notamment — mais elle n'a plus à être ce qu'on regarde en
            // jouant : les barres le disent plus vite.
            Text(displayValue)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.25), value: engine.recentPlacement)

            // Pour un accord, l'étalement compte autant que le placement.
            // Ligne toujours présente pour que la hauteur ne saute pas. (EX-037)
            Text(chordDetail ?? " ")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var chordDetail: String? {
        guard let hit = engine.hits.last, hit.notes.count > 1 else { return nil }
        return String(format: NSLocalizedString("%d notes · spread %d ms", comment: ""),
                      hit.notes.count, Int((hit.spread * 1000).rounded()))
    }

    // Tout ce bloc lit la fourchette glissante, et non l'écart de la dernière
    // note : celui-ci change à chaque frappe, au point d'être illisible en
    // jouant. (EX-066)

    private var displayValue: String {
        guard let placement = engine.recentPlacement else { return "–" }
        let mean = Int((placement.mean * 1000).rounded())
        let deviation = Int((placement.deviation * 1000).rounded())
        let sign = mean > 0 ? "+" : (mean < 0 ? "−" : "")
        return String(format: NSLocalizedString("%@%d ± %d ms", comment: ""),
                      sign, abs(mean), deviation)
    }

    private var compactValue: String { displayValue }

    private var currentTint: Color {
        guard let placement = engine.recentPlacement else { return .secondary }
        return placement.isWithin(engine.tolerance) ? Palette.onTime : Palette.offTime
    }

    private var verdict: String {
        guard let placement = engine.recentPlacement else {
            // « milliseconds » servait d'unité sous le gros chiffre ; celui-ci
            // est passé en dessous et porte désormais son unité.
            return engine.running ? String(localized: "play on the beat") : String(localized: "ready")
        }
        let tolerance = engine.tolerance
        // L'ordre compte : la fourchette entière doit tenir dans la zone pour
        // que le jeu soit dit juste, et un décalage franc prime sur
        // l'irrégularité, parce qu'il se corrige autrement.
        if placement.isWithin(tolerance) { return String(localized: "on time") }
        if placement.mean < -tolerance { return String(localized: "early") }
        if placement.mean > tolerance { return String(localized: "late") }
        return String(localized: "uneven")
    }

    // =====================================================================
    // Transport : ce qu'on touche en jouant reste sur l'écran
    // =====================================================================

    /// Vrai tant que l'horloge du clavier pilote le tempo : le régler à la
    /// main n'aurait aucun effet, la valeur serait reprise au battement
    /// suivant. Condition sur l'horloge reçue, et non sur le réglage de
    /// synchro : un clavier qui envoie Start sans horloge laisse la main.
    private var clockDriven: Bool { engine.clockBpm != nil }

    private var transport: some View {
        VStack(spacing: 14) {
            HStack {
                Label {
                    Text(engine.midi.selected?.name ?? String(localized: "No keyboard"))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: engine.midi.sources.isEmpty
                          ? "pianokeys" : "pianokeys.inverse")
                }
                .font(.footnote)
                .foregroundStyle(engine.midi.sources.isEmpty ? .secondary : .primary)

                if engine.settings.syncStart {
                    Label(engine.externallyTriggered ? "synced" : "waiting for Start",
                          systemImage: engine.externallyTriggered
                              ? "link.circle.fill" : "link.circle")
                        .font(.caption2)
                        .foregroundStyle(engine.externallyTriggered ? Palette.onTime : .secondary)
                        .labelStyle(.titleAndIcon)
                        .fixedSize()
                        .layoutPriority(1)
                }

                Text(engine.settings.subdivision.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color(uiColor: .tertiarySystemFill),
                                in: Capsule())
                    .fixedSize()
                    .layoutPriority(1)

                Spacer()

                if let note = engine.midi.lastNote {
                    Text(note)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .layoutPriority(1)
                }
            }

            HStack(spacing: 16) {
                Button {
                    engine.settings.bpm = max(30, engine.settings.bpm - 1)
                    engine.reanchor()
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .disabled(clockDriven)

                VStack(spacing: 2) {
                    // Quand l'horloge du clavier est suivie, c'est elle qui
                    // fait foi : afficher le tempo réglé serait mensonger.
                    Text(engine.clockBpm.map { String(format: "%.0f", $0) }
                         ?? "\(Int(engine.settings.bpm))")
                        .font(.system(.title2, design: .rounded, weight: .medium))
                        .monospacedDigit()
                    Text(engine.clockBpm != nil ? "bpm received" : "bpm")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(width: 78)

                Button {
                    engine.settings.bpm = min(240, engine.settings.bpm + 1)
                    engine.reanchor()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .disabled(clockDriven)

                Spacer()

                Button { engine.toggle() } label: {
                    Label(engine.running ? "Stop" : "Start",
                          systemImage: engine.running ? "stop.fill" : "play.fill")
                        .frame(minWidth: 96)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(engine.running ? .secondary : .accentColor)
                .disabled(engine.settings.syncStart && !engine.running)
            }

            Slider(value: Binding(get: { engine.settings.bpm },
                                  set: { engine.settings.bpm = $0.rounded(); engine.reanchor() }),
                   in: 30...240, step: 1) {
                Text("Tempo")
            } minimumValueLabel: {
                Text("30").font(.caption2).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("240").font(.caption2).foregroundStyle(.secondary)
            }
            .disabled(clockDriven)

            HStack(spacing: 12) {
                Image(systemName: engine.settings.clickEnabled
                      ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundStyle(.secondary)
                    .onTapGesture { engine.settings.clickEnabled.toggle() }
                    .accessibilityLabel(engine.settings.clickEnabled
                                        ? String(localized: "Mute the click") : String(localized: "Enable the click"))

                Slider(value: Binding(get: { engine.settings.volume },
                                      set: { engine.settings.volume = $0 }),
                       in: 0...1)
                    .disabled(!engine.settings.clickEnabled)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.bottom, 8)
    }

    @ViewBuilder private var messageBar: some View {
        if let message = engine.message {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.thinMaterial)
        }
    }
}

// =====================================================================

/// Les quatre chiffres. (EX-080 à EX-083)
struct StatsGrid: View {

    let engine: RhythmEngine

    private var hasData: Bool { engine.stats.count > 0 }
    private var step: Double { engine.gridPeriod }

    var body: some View {
        HStack(spacing: 0) {
            cell(String(localized: "Notes"), value: "\(engine.stats.count)")
            divider
            cell(String(localized: "Average"),
                 value: hasData ? signed(engine.stats.mean) : "–",
                 unit: hasData ? "ms" : nil)
            divider
            cell(String(localized: "Regularity"),
                 value: hasData ? String(format: "%.1f", engine.stats.sd * 1000) : "–",
                 unit: hasData ? "ms" : nil,
                 tint: regularityTint,
                 caption: hasData ? String(format: "%.1f %%", ratio) : nil)
            divider
            cell(String(localized: "In the zone"),
                 value: hasData ? "\(Int(engine.stats.inZone))" : "–",
                 unit: hasData ? "%" : nil)
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Dispersion rapportée à l'intervalle : comparable d'un tempo à l'autre,
    /// contrairement à la valeur en millisecondes. (EX-082)
    private var ratio: Double { step > 0 ? engine.stats.sd / step * 100 : 0 }

    /// Vert tant que la dispersion reste acceptable, orange au-delà.
    private var regularityTint: Color {
        guard hasData else { return .primary }
        return Regularity.isAcceptable(sd: engine.stats.sd, step: step)
            ? Palette.onTime : Palette.offTime
    }

    private var divider: some View {
        Divider().frame(height: 34)
    }

    private func signed(_ seconds: Double) -> String {
        let ms = seconds * 1000
        let sign = ms > 0.05 ? "+" : (ms < -0.05 ? "−" : "")
        return sign + String(format: "%.1f", abs(ms))
    }

    private func cell(_ title: String,
                      value: String,
                      unit: String? = nil,
                      tint: Color = .primary,
                      caption: String? = nil) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                if let unit {
                    Text(unit).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            // Ligne toujours présente, même vide : sans cela les quatre
            // cellules n'auraient pas la même hauteur.
            Text(caption ?? " ")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MainView()
}
