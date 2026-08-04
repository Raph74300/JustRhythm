import SwiftUI

/// L'écran de mesure, couché. (EX-138)
///
/// Deux colonnes plutôt qu'une pile : le graphe à gauche sur les deux tiers, et
/// sur le tiers restant tout ce qu'on touche en jouant. Le partage vient du
/// câble — même coudé, il gêne quand le téléphone est debout sur le pupitre —
/// et le paysage rend d'un coup la disposition verticale intenable : graphe et
/// transport empilés ne tiennent pas dans les quelque 400 points de hauteur qui
/// restent.
///
/// Ce que le bandeau porte a été tranché par la négative : rien qui décrive ce
/// qui vient d'être joué. Cet écran sert à corriger le geste en cours, et quatre
/// chiffres de bilan y invitaient à s'arrêter pour les lire.
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
        VStack(spacing: 12) {
            if !immersive {
                // Le Tuner touchait le haut de l'écran. C'est pourtant lui qu'on
                // consulte le plus, et une commande collée au bord se lit mal
                // autant qu'elle se touche mal.
                readout.padding(.top, 8)
            }

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
        .padding(.leading, immersive ? 0 : 16)
        // Une gouttière côté bandeau : sans elle, le cadre du graphe venait
        // buter contre les commandes.
        .padding(.trailing, immersive ? 0 : 6)
        .padding(.top, immersive ? 0 : 10)
        .padding(.bottom, immersive ? 0 : 14)
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
        // Le décompte de notes et le pourcentage de la séance sont partis avec
        // le carré de statistiques, et pour la même raison : ils parlent de ce
        // qui est déjà joué. Il ne reste que ce qui sert à jouer.
        HStack {
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

    /// Les trois voyants seuls, d'aplomb sur le fil à plomb. (EX-066)
    ///
    /// Le mot qui doublait les voyants — *dans le temps*, *en avance* — a été
    /// retiré, et c'est ce qui permet le centrage. Posé à droite des voyants, il
    /// poussait forcément la barre centrale à gauche du milieu : l'ensemble était
    /// centré, la barre ne l'était pas. Elle tombe maintenant exactement sur la
    /// ligne verticale du graphe, juste en dessous. Les deux ne disent plus la
    /// même chose à deux endroits, ils disent la même chose sur le même axe.
    ///
    /// Le verdict n'est pas perdu pour autant : il devient la valeur
    /// d'accessibilité de l'ensemble, seule façon de continuer à énoncer le
    /// placement à qui ne voit pas les voyants.
    private var readout: some View {
        BiasMeter(placement: engine.recentPlacement, tolerance: engine.tolerance)
            .frame(maxWidth: .infinity)
            .accessibilityElement()
            .accessibilityLabel(String(localized: "Placement"))
            .accessibilityValue(verdict)
    }

    // Tout ce bloc lit la fourchette glissante, et non l'écart de la dernière
    // note : celui-ci change à chaque frappe, au point d'être illisible en
    // jouant. (EX-066)

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

    /// Ce qu'on touche en jouant, et rien d'autre. (EX-138)
    ///
    /// Le carré de statistiques a été retiré d'ici : quatre chiffres qui
    /// décrivent ce qui vient d'être joué invitent à s'arrêter pour les lire,
    /// alors que tout l'objet de cet écran est la correction en cours. Le moteur
    /// continue de les tenir — ils reviendront avec l'export, où ils sont à leur
    /// place. (EX-080 à EX-084)
    ///
    /// Plus de `ScrollView` non plus : ce qui reste tient partout, et deux
    /// ressorts répartissent l'excédent — l'en-tête reste en haut, les commandes
    /// descendent vers les pouces. (EX-091)
    private var sidebar: some View {
        VStack(spacing: 20) {
            sidebarHeader
            Spacer(minLength: 8)
            tempoControls
            startButton
            Spacer(minLength: 8)
            volumes
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
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


#Preview {
    MainView()
}
