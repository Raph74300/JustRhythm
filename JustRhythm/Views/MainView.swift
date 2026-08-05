import SwiftUI

struct MainView: View {

    @State private var engine = RhythmEngine()
    @State private var showSettings = false
    @State private var immersive = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Sur iPhone, la hauteur est compacte en paysage et seulement là. La lire
    /// dans l'environnement plutôt que d'interroger la scène a l'avantage
    /// d'être observable : le bouton de rotation change d'icône tout seul.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLandscape: Bool { verticalSizeClass == .compact }

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
                // « Masque tout le reste » inclut le titre et l'engrenage, qui
                // survivaient jusqu'ici au passage en plein écran. (EX-072)
                // Couché, les 44 points qu'ils occupent se prélèvent sur une
                // hauteur totale d'environ 400 : ils ne sont plus seulement de
                // trop, ils coûtent une seconde d'historique visible. (EX-136)
                .toolbar(immersive ? .hidden : .visible, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(engine: engine)
        }
        .statusBarHidden(immersive)
        .persistentSystemOverlays(immersive ? .hidden : .automatic)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && engine.running { engine.stop() }
        }
        // Le paysage n'existe qu'en plein écran. (EX-136)
        .onChange(of: immersive) { _, on in
            if on {
                Orientation.allow([.portrait, .landscapeLeft, .landscapeRight])
            } else {
                Orientation.pin(.portrait)
            }
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
                    // Le pivot manuel n'est pas un doublon de la rotation
                    // automatique : celle-ci ne se déclenche pas quand le verrou
                    // d'orientation du système est actif, et le téléphone posé
                    // sur un pupitre est précisément là où on l'active. (EX-136)
                    Button {
                        Orientation.pin(isLandscape ? .portrait : .landscapeRight)
                    } label: {
                        Image(systemName: isLandscape ? "iphone" : "iphone.landscape")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isLandscape
                                        ? String(localized: "Back to portrait")
                                        : String(localized: "Turn to landscape"))

                    Spacer()
                    Text(String(format: NSLocalizedString("%d bpm · %@", comment: ""),
                               Int(engine.settings.bpm), engine.settings.subdivision.shortLabel))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)

                Spacer()

                HStack {
                    // Le total joué, comme dans la rangée de statistiques : le
                    // pourcentage qui suit, lui, porte sur la fenêtre.
                    Text(engine.stats.count > 0
                         ? String(format: NSLocalizedString("%d notes · %d %%", comment: ""),
                                  engine.stats.played, Int(engine.stats.inZone))
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
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }


    // Tout ce bloc lit la fourchette glissante, et non l'écart de la dernière
    // note : celui-ci change à chaque frappe, au point d'être illisible en
    // jouant. (EX-066)


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
            MessageBar(message: message) { engine.message = nil }
        }
    }
}

// =====================================================================

/// Le bandeau du bas : un résumé d'une ligne, le reste derrière un appui.
/// (EX-135)
struct MessageBar: View {

    let message: EngineMessage
    let onDismiss: () -> Void

    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasDetail: Bool { message.detail != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: message.severity.icon)
                    .foregroundStyle(message.severity == .warning ? .orange : .secondary)

                // Sans `lineLimit` et avec `fixedSize` : le résumé tient sur une
                // ligne aux tailles de texte courantes, mais s'il devait
                // déborder — traduction plus longue, corps de texte agrandi — il
                // passe à la ligne au lieu de se faire couper. C'est exactement
                // ce qui manquait à l'ancien bandeau.
                Text(message.summary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if hasDetail {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        // La cible tactile fait le minimum recommandé ; l'icône,
                        // elle, reste discrète.
                        .frame(width: 44, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Dismiss the message"))
            }

            if expanded, let detail = message.detail {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .contentShape(Rectangle())
        .onTapGesture {
            guard hasDetail else { return }
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                expanded.toggle()
            }
        }
        // Un nouveau message repart replié : sans cela, un avertissement long
        // s'ouvrirait tout seul parce que le précédent avait été déplié.
        .onChange(of: message) { _, _ in expanded = false }
        .accessibilityElement(children: .combine)
        .accessibilityHint(hasDetail ? String(localized: "Tap to read the details") : "")
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
            cell(String(localized: "Notes"),
                 value: "\(engine.stats.played)",
                 caption: sampleCaption)
            divider
            cell(String(localized: "Average"),
                 value: hasData ? signed(engine.stats.mean) : "–",
                 unit: hasData ? "ms" : nil)
            divider
            // « Dispersion » et non « Régularité » : c'est un écart-type, donc
            // plus le nombre est grand, moins le jeu est régulier. L'ancien
            // libellé se lisait à l'envers.
            cell(String(localized: "Dispersion"),
                 value: hasData ? String(format: "%.1f", engine.stats.sd * 1000) : "–",
                 unit: hasData ? "ms" : nil,
                 tint: dispersionTint)
            divider
            cell(String(localized: "In the zone"),
                 value: hasData ? "\(Int(engine.stats.inZone))" : "–",
                 unit: hasData ? "%" : nil)
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Taille de l'échantillon, affichée seulement quand la fenêtre glissante
    /// sature. (EX-084)
    ///
    /// Tant que toutes les notes de la séance sont retenues, la préciser
    /// n'apprendrait rien ; passé ce point, elle explique pourquoi les trois
    /// autres cases ne décrivent plus toute la séance.
    private var sampleCaption: String? {
        guard engine.stats.played > engine.stats.count else { return nil }
        return String(format: NSLocalizedString("%d kept", comment: ""), engine.stats.count)
    }


    /// Vert tant que la dispersion reste acceptable, orange au-delà.
    private var dispersionTint: Color {
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
