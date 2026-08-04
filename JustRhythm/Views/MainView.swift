import SwiftUI

/// L'écran de mesure, couché. (EX-138)
///
/// Deux colonnes plutôt qu'une pile : le graphe à gauche sur les deux tiers, et
/// sur le tiers restant tout ce qu'on touche en jouant. Le partage vient du
/// câble — même coudé, il gêne quand le téléphone est debout sur le pupitre —
/// et le paysage rend d'un coup la disposition verticale intenable : le graphe,
/// les statistiques et le transport empilés ne tiennent pas dans les quelque
/// 400 points de hauteur qui restent.
///
/// Ce que le paysage donne en échange n'est pas qu'un pis-aller : la largeur du
/// graphe est ce qui porte la résolution de l'écart, et elle passe de 390 à plus
/// de 600 points. On lit une avance de 10 ms là où elle tenait dans deux pixels.
struct MainView: View {

    @State private var engine = RhythmEngine()
    @State private var showSettings = false
    @State private var immersive = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Part de la largeur laissée au bandeau de droite.
    private static let sidebarShare: CGFloat = 1.0 / 3.0

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                measurement
                    .frame(width: immersive
                           ? geometry.size.width
                           : geometry.size.width * (1 - Self.sidebarShare))

                if !immersive {
                    sidebar
                        .frame(width: geometry.size.width * Self.sidebarShare)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { messageBar }
        // Plus de NavigationStack : sa barre coûtait 44 points de haut sur les
        // 400 disponibles, pour un titre que personne ne lit et un engrenage qui
        // a désormais sa place dans le bandeau.
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
    // Colonne de gauche : la mesure
    // =====================================================================

    private var measurement: some View {
        VStack(spacing: 6) {
            if !immersive { readout }

            scope
                .background(immersive ? Color.clear
                            : Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: immersive ? 0 : 12,
                                            style: .continuous))
                // Le graphe déborde jusqu'aux bords physiques en plein écran :
                // couché, l'encoche mange une soixantaine de points sur un côté,
                // et c'est la largeur qui porte la résolution de l'écart.
                .ignoresSafeArea(edges: immersive ? .all : [])
        }
        .padding(.leading, immersive ? 0 : 12)
        .padding(.vertical, immersive ? 0 : 10)
        // Posée sur la pile et non sur le graphe : les commandes, elles,
        // doivent rester en deçà de l'encoche et de la barre d'accueil.
        .overlay(alignment: .bottom) {
            if immersive { immersiveControls }
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

    /// En plein écran le bandeau disparaît : marche/arrêt doit rester à portée
    /// de pouce, sans quoi le mode ne servirait qu'à regarder. (EX-091)
    private var immersiveControls: some View {
        HStack {
            Text(engine.stats.count > 0
                 ? String(format: NSLocalizedString("%d notes · %d %%", comment: ""),
                          engine.stats.played, Int(engine.stats.inZone))
                 : "—")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            Text(String(format: NSLocalizedString("%d bpm · %@", comment: ""),
                        Int(engine.settings.bpm), engine.settings.subdivision.shortLabel))
                .font(.footnote)
                .foregroundStyle(.secondary)

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

    // =====================================================================
    // Lecture instantanée (EX-066)
    // =====================================================================

    private var readout: some View {
        HStack(spacing: 14) {
            BiasMeter(placement: engine.recentPlacement, tolerance: engine.tolerance)

            Text(verdict)
                .font(.title3.weight(.medium))
                .foregroundStyle(currentTint)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.25), value: verdict)
        }
        // Côte à côte et non l'un sous l'autre : couché, chaque point de hauteur
        // pris ici est un point de moins pour le graphe.
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
    // Colonne de droite : ce qu'on touche en jouant
    // =====================================================================

    /// Vrai tant que l'horloge du clavier pilote le tempo : le régler à la main
    /// n'aurait aucun effet, la valeur serait reprise au battement suivant.
    private var clockDriven: Bool { engine.clockBpm != nil }

    private var sidebar: some View {
        // Défilement replié tant que tout tient : sur un grand écran il ne se
        // manifeste jamais, sur un petit il évite que le bouton Démarrer sorte
        // par le bas plutôt que d'être atteignable. (EX-091)
        ScrollView {
            VStack(spacing: 10) {
                sidebarHeader
                StatsGrid(engine: engine)
                tempoControls
                startButton
                volumes
            }
            .padding(10)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label {
                    Text(engine.midi.selected?.name ?? String(localized: "No keyboard"))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: engine.midi.sources.isEmpty
                          ? "pianokeys" : "pianokeys.inverse")
                }
                .font(.footnote)
                .foregroundStyle(engine.midi.sources.isEmpty ? .secondary : .primary)

                Spacer(minLength: 0)

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Settings"))
            }

            HStack(spacing: 6) {
                if engine.settings.syncStart {
                    Label(engine.externallyTriggered ? "synced" : "waiting for Start",
                          systemImage: engine.externallyTriggered
                              ? "link.circle.fill" : "link.circle")
                        .font(.caption2)
                        .foregroundStyle(engine.externallyTriggered ? Palette.onTime : .secondary)
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                }

                Text(engine.settings.subdivision.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let note = engine.midi.lastNote {
                    Text(note)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var tempoControls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    engine.settings.bpm = max(30, engine.settings.bpm - 1)
                    engine.reanchor()
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .disabled(clockDriven)

                // Sur une ligne et non l'un sous l'autre : couché, l'unité en
                // légende coûtait une ligne de plus dans une colonne qui n'en a
                // pas à donner.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    // Quand l'horloge du clavier est suivie, c'est elle qui fait
                    // foi : afficher le tempo réglé serait mensonger.
                    Text(engine.clockBpm.map { String(format: "%.0f", $0) }
                         ?? "\(Int(engine.settings.bpm))")
                        .font(.system(.title2, design: .rounded, weight: .medium))
                        .monospacedDigit()
                    Text(engine.clockBpm != nil ? "bpm received" : "bpm")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)

                Button {
                    engine.settings.bpm = min(240, engine.settings.bpm + 1)
                    engine.reanchor()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .disabled(clockDriven)
            }

            Slider(value: Binding(get: { engine.settings.bpm },
                                  set: { engine.settings.bpm = $0.rounded(); engine.reanchor() }),
                   in: 30...240, step: 1) {
                Text("Tempo")
            }
            .disabled(clockDriven)
        }
    }

    private var startButton: some View {
        Button { engine.toggle() } label: {
            Label(engine.running ? "Stop" : "Start",
                  systemImage: engine.running ? "stop.fill" : "play.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(engine.running ? .secondary : .accentColor)
        .disabled(engine.settings.syncStart && !engine.running)
    }

    /// Deux niveaux séparés. (EX-137)
    ///
    /// Le clic et les notes ne se dosent pas ensemble : il faut que le clic
    /// reste audible *sous* le jeu, et le rapport juste dépend du timbre choisi
    /// autant que du morceau. Un curseur unique obligeait à choisir lequel des
    /// deux on sacrifiait.
    private var volumes: some View {
        VStack(spacing: 8) {
            volumeRow(icon: engine.settings.clickEnabled
                      ? "speaker.wave.2.fill" : "speaker.slash.fill",
                      label: String(localized: "Click volume"),
                      value: Binding(get: { engine.settings.clickVolume },
                                     set: { engine.settings.clickVolume = $0 }),
                      enabled: engine.settings.clickEnabled,
                      iconAction: { engine.settings.clickEnabled.toggle() },
                      iconHint: engine.settings.clickEnabled
                          ? String(localized: "Mute the click")
                          : String(localized: "Enable the click"))

            volumeRow(icon: "pianokeys",
                      label: String(localized: "Instrument volume"),
                      value: Binding(get: { engine.settings.instrumentVolume },
                                     set: {
                                         engine.settings.instrumentVolume = $0
                                         engine.instrumentVolumeChanged()
                                     }),
                      enabled: engine.settings.instrumentEnabled,
                      iconAction: nil,
                      iconHint: String(localized: "Instrument volume"))
        }
    }

    private func volumeRow(icon: String,
                           label: String,
                           value: Binding<Double>,
                           enabled: Bool,
                           iconAction: (() -> Void)?,
                           iconHint: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .contentShape(Rectangle())
                .onTapGesture { iconAction?() }
                .accessibilityLabel(iconHint)

            Slider(value: value, in: 0...1) { Text(label) }
                .disabled(!enabled)
        }
        // Le curseur du module reste visible quand celui-ci est coupé, grisé
        // plutôt qu'absent : une commande qui disparaît fait sauter la
        // disposition et laisse croire qu'on l'a rêvée.
        .opacity(enabled ? 1 : 0.45)
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
                // passe à la ligne au lieu de se faire couper.
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

/// Les quatre chiffres, en carré. (EX-080 à EX-083)
///
/// En deux colonnes et non plus en rangée : le bandeau fait un tiers de la
/// largeur, où quatre cellules côte à côte n'auraient laissé la place ni au
/// libellé ni à l'unité.
struct StatsGrid: View {

    let engine: RhythmEngine

    private var hasData: Bool { engine.stats.count > 0 }
    private var step: Double { engine.gridPeriod }

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 8) {
            GridRow {
                // Seule cette rangée réserve la ligne de légende, parce que
                // seule « Notes » peut en porter une. La réserver partout
                // coûtait une ligne pleine de plus dans une colonne comptée au
                // point près ; ne la réserver nulle part ferait sauter la
                // disposition en pleine séance, au moment où la fenêtre sature.
                cell(String(localized: "Notes"),
                     value: "\(engine.stats.played)",
                     caption: sampleCaption,
                     reservesCaption: true)
                cell(String(localized: "Average"),
                     value: hasData ? signed(engine.stats.mean) : "–",
                     unit: hasData ? "ms" : nil,
                     reservesCaption: true)
            }
            GridRow {
                // « Dispersion » et non « Régularité » : c'est un écart-type,
                // donc plus le nombre est grand, moins le jeu est régulier.
                // L'ancien libellé se lisait à l'envers.
                cell(String(localized: "Dispersion"),
                     value: hasData ? String(format: "%.1f", engine.stats.sd * 1000) : "–",
                     unit: hasData ? "ms" : nil,
                     tint: dispersionTint)
                cell(String(localized: "In the zone"),
                     value: hasData ? "\(Int(engine.stats.inZone))" : "–",
                     unit: hasData ? "%" : nil)
            }
        }
        .padding(.vertical, 8)
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

    private func signed(_ seconds: Double) -> String {
        let ms = seconds * 1000
        let sign = ms > 0.05 ? "+" : (ms < -0.05 ? "−" : "")
        return sign + String(format: "%.1f", abs(ms))
    }

    private func cell(_ title: String,
                      value: String,
                      unit: String? = nil,
                      tint: Color = .primary,
                      caption: String? = nil,
                      reservesCaption: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

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

            if reservesCaption {
                Text(caption ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MainView()
}
