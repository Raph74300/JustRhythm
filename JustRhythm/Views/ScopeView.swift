import SwiftUI

/// Le graphe. Le temps descend, l'écart s'écarte.
///
/// Sa largeur vaut **un temps**, quelle que soit la subdivision. C'est ce qui
/// en fait une règle plutôt qu'une loupe : deux séances se comparent, et la
/// part de gris — l'espace où aucune note ne peut tomber — dit d'un coup d'œil
/// à quel point la grille choisie est exigeante. (EX-067)
struct ScopeView: View {

    let engine: RhythmEngine
    /// Profondeur d'historique visible, en secondes.
    var depth: Double = 6.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Hauteur réservée à la règle, en bas. Le défilement s'arrête au-dessus :
    /// une graduation lisible vaut mieux qu'une poignée de pixels de plus.
    private let rulerHeight: CGFloat = 50

    var body: some View {
        TimelineView(.animation) { timeline in
            // `now` est calculé ICI, hors du Canvas.
            //
            // C'est la condition du défilement fluide : le contenu doit
            // dépendre de la date fournie par la timeline. Si on se contente
            // de lire l'horloge dans le rendu, SwiftUI juge le contenu
            // invariant et ne le redessine qu'au gré des autres changements
            // d'état — soit une image par temps. (EX-069)
            let now = HostClock.hostTime(for: timeline.date)
            Canvas { context, size in
                draw(context: context, size: size, now: now)
            }
        }
        .accessibilityLabel(String(localized: "Rhythm accuracy graph"))
        .accessibilityValue(summary)
    }

    private var summary: String {
        guard let delta = engine.lastDelta else { return String(localized: "no note") }
        let ms = Int((delta * 1000).rounded())
        let sense = abs(delta) <= engine.tolerance ? String(localized: "on time")
                  : (delta < 0 ? String(localized: "early") : String(localized: "late"))
        return String(format: NSLocalizedString("%d milliseconds, %@", comment: ""), abs(ms), sense)
    }

    // =====================================================================

    private func draw(context: GraphicsContext, size: CGSize, now: Double) {
        let cx = size.width / 2
        let plotHeight = size.height - rulerHeight

        // Échelle fixe : la demi-largeur vaut une demi-noire, c'est-à-dire
        // exactement la plus large plage qu'un écart puisse atteindre — celle
        // d'une grille en noires. Le cadre n'est donc ni arbitraire ni trop
        // grand, et il ne bouge plus quand la subdivision change.
        let window = engine.beatPeriod / 2
        guard window > 0 else { return }
        let scale = (size.width / 2 - 16) / window        // points par seconde d'écart
        let pxPerSecond = plotHeight / depth

        let reachable = min(engine.gridPeriod / 2, window)   // au-delà : note du pas suivant
        let tolerance = min(engine.tolerance, reachable)

        drawBands(context, cx: cx, height: plotHeight, scale: scale,
                  window: window, reachable: reachable, tolerance: tolerance)

        // Temps du métronome qui descendent. (EX-068)
        if engine.running {
            for beat in engine.beats {
                let y = (now - beat.time) * pxPerSecond
                guard y > -2, y < plotHeight else { continue }
                let opacity = beat.isMain ? 0.5 : 0.2
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)),
                             with: .color(Palette.beatLine.opacity(opacity)))
            }
        }

        // Notes jouées. (EX-062)
        for hit in engine.hits {
            let y = (now - hit.time) * pxPerSecond
            guard y > -16, y < plotHeight else { continue }
            let dx = min(max(hit.delta * scale, -size.width / 2 + 8), size.width / 2 - 8)
            let fade = max(0.2, 1 - y / plotHeight)

            var link = Path()
            link.move(to: CGPoint(x: cx, y: y))
            link.addLine(to: CGPoint(x: cx + dx, y: y))
            context.stroke(link, with: .color(Palette.grid.opacity(fade)), lineWidth: 0.5)

            let tint = Palette.tint(for: hit.delta, tolerance: engine.tolerance)
            // Un accord est plus haut qu'une note seule : l'événement groupé
            // doit rester identifiable d'un coup d'œil. (EX-036)
            let half: CGFloat = hit.notes.count > 1 ? 10 : 7
            context.fill(
                Path(roundedRect: CGRect(x: cx + dx - 2, y: y - half, width: 4, height: half * 2),
                     cornerRadius: 2),
                with: .color(tint.opacity(fade)))
        }

        // Le fil à plomb, par-dessus tout le reste. (EX-060)
        var pulse = 0.0
        if !reduceMotion, engine.running,
           let last = engine.beats.last(where: { $0.time <= now }) {
            let since = now - last.time
            if since < 0.09 { pulse = 1 - since / 0.09 }
        }
        if pulse > 0 {
            context.fill(Path(CGRect(x: cx - 3, y: 0, width: 6, height: plotHeight)),
                         with: .color(Palette.plumb.opacity(0.15 * pulse)))
        }
        context.fill(Path(CGRect(x: cx - 0.5, y: 0, width: 1, height: plotHeight)),
                     with: .color(Palette.plumb.opacity(0.55)))

        drawRuler(context, cx: cx, top: plotHeight, width: size.width,
                  scale: scale, window: window, reachable: reachable, tolerance: tolerance)
    }

    // =====================================================================
    // Les trois zones
    // =====================================================================

    /// Gris, orangé, vert — et un filet à chaque rupture.
    ///
    /// Les filets ne sont pas décoratifs : trois teintes portant seules le sens
    /// contreviendraient à la règle qui interdit de confier une information à
    /// la couleur (EX-117). Une frontière visible reste lisible en niveaux de
    /// gris comme en contraste renforcé.
    private func drawBands(_ context: GraphicsContext, cx: CGFloat, height: CGFloat,
                           scale: CGFloat, window: Double,
                           reachable: Double, tolerance: Double) {
        func band(_ half: Double, _ color: Color) {
            let w = half * scale
            context.fill(Path(CGRect(x: cx - w, y: 0, width: w * 2, height: height)),
                         with: .color(color))
        }
        // La marge au-delà de l'échelle est hors d'atteinte elle aussi : la
        // laisser vide donnerait deux bandes claires de sens différent.
        context.fill(Path(CGRect(x: 0, y: 0, width: cx * 2, height: height)),
                     with: .color(Color(uiColor: .quaternarySystemFill)))
        func edge(_ half: Double) {
            let w = half * scale
            for x in [cx - w, cx + w] {
                context.fill(Path(CGRect(x: x - 0.25, y: 0, width: 0.5, height: height)),
                             with: .color(Palette.grid))
            }
        }

        // Du plus large au plus étroit : chaque bande recouvre la précédente.
        band(reachable, Palette.offTime.opacity(0.10))          // mesurable, hors zone
        band(tolerance, Palette.onTime.opacity(0.14))           // zone juste

        if reachable < window { edge(reachable) }
        edge(tolerance)
    }

    // =====================================================================
    // La règle
    // =====================================================================

    /// Un repère par valeur de note, plus l'accolade de la zone juste.
    ///
    /// Les valeurs sont celles qu'on lit sur une partition, pas des
    /// millisecondes : « en retard d'une double-croche » se corrige, « en
    /// retard de 47 ms » ne se corrige pas.
    private func drawRuler(_ context: GraphicsContext, cx: CGFloat, top: CGFloat,
                           width: CGFloat, scale: CGFloat, window: Double,
                           reachable: Double, tolerance: Double) {
        _ = tolerance
        for mark in marks(beat: engine.beatPeriod,
                          ternary: engine.settings.subdivision == .triplet) {
            guard mark.offset <= window + 1e-9 else { continue }
            let dx = mark.offset * scale
            // Estompé au-delà du mesurable : le repère existe, mais aucune note
            // ne peut l'atteindre avec la grille en cours.
            let faded = mark.offset > reachable + 1e-9
            let tint = Palette.beatLine.opacity(faded ? 0.35 : 1)

            for (x, sign) in [(cx - dx, "−"), (cx + dx, "+")] {
                context.fill(Path(CGRect(x: x - 0.5, y: top, width: 1, height: 6)),
                             with: .color(Palette.beatLine.opacity(faded ? 0.35 : 0.8)))
                // Le libellé se recentre s'il déborde ; le trait, lui, reste
                // exactement sur la graduation.
                let label = min(max(x, 21), width - 21)
                context.draw(Text(sign).font(.system(size: 11, weight: .semibold))
                                .foregroundColor(tint),
                             at: CGPoint(x: label - 9, y: top + 20))
                note(context, at: CGPoint(x: label + 3, y: top + 25),
                     flags: mark.flags, triplet: mark.triplet, color: tint)
            }
        }

        // Le chiffre seul, centré sous sa zone. L'accolade a été retirée : la
        // bande verte montre déjà l'étendue sur toute la hauteur du graphe, et
        // la redoubler d'un trait n'ajoutait rien qu'un ornement de plus.
        context.draw(Text(zoneLabel).font(.system(size: 10, weight: .medium))
                        .foregroundColor(Palette.onTime),
                     at: CGPoint(x: cx, y: top + 42))
    }

    /// Le pourcentage réglé — sauf quand le plancher de 20 ms l'emporte, auquel
    /// cas l'afficher mentirait sur la largeur qu'on voit.
    private var zoneLabel: String {
        engine.tolerance == Tolerance.floor
            ? String(localized: "min")
            : String(format: NSLocalizedString("%d %%", comment: ""),
                     Int(engine.settings.tolerancePercent))
    }

    /// Une graduation : un écart, et la valeur de note qui lui correspond.
    private struct Mark {
        let offset: Double      // en secondes depuis le temps
        let flags: Int          // 1 croche, 2 double-croche, 3 triple-croche
        let triplet: Bool
    }

    /// La largeur vaut un temps : une demi-largeur vaut donc une croche, un
    /// quart une double-croche, un huitième une triple-croche. En ternaire les
    /// mêmes fractions ne tombent plus juste — un tiers et un sixième de temps
    /// prennent le relais, et le 3 du triolet le signale.
    private func marks(beat: Double, ternary: Bool) -> [Mark] {
        ternary
            ? [Mark(offset: beat / 3, flags: 1, triplet: true),
               Mark(offset: beat / 6, flags: 2, triplet: true)]
            : [Mark(offset: beat / 2, flags: 1, triplet: false),
               Mark(offset: beat / 4, flags: 2, triplet: false),
               Mark(offset: beat / 8, flags: 3, triplet: false)]
    }

    /// Dessine une note : tête, hampe, crochets.
    ///
    /// Dessinée et non écrite : Unicode n'offre pas de triple-croche isolée, et
    /// `♪ ♫ ♬` ne se rendent pas de la même façon d'une police à l'autre. Ici la
    /// forme est la même partout et suit la couleur du texte.
    private func note(_ context: GraphicsContext, at point: CGPoint,
                      flags: Int, triplet: Bool, color: Color) {
        let headW: CGFloat = 7.4, headH: CGFloat = 5.2
        let stemW: CGFloat = 1.2, stemH: CGFloat = 16

        var head = Path(ellipseIn: CGRect(x: -headW / 2, y: -headH / 2,
                                          width: headW, height: headH))
        head = head.applying(CGAffineTransform(rotationAngle: -0.34))
        head = head.applying(CGAffineTransform(translationX: point.x, y: point.y))
        context.fill(head, with: .color(color))

        let stemX = point.x + headW / 2 - 0.6
        let stemTop = point.y - stemH
        context.fill(Path(CGRect(x: stemX, y: stemTop, width: stemW, height: stemH)),
                     with: .color(color))

        for i in 0..<flags {
            let fy = stemTop + CGFloat(i) * 4.3
            var flag = Path()
            flag.move(to: CGPoint(x: stemX + stemW - 0.2, y: fy))
            flag.addQuadCurve(to: CGPoint(x: stemX + stemW + 4.4, y: fy + 6),
                              control: CGPoint(x: stemX + stemW + 5.2, y: fy + 1.2))
            context.stroke(flag, with: .color(color), lineWidth: 1.3)
        }

        if triplet {
            context.draw(Text("3").font(.system(size: 8, weight: .semibold))
                            .foregroundColor(color),
                         at: CGPoint(x: stemX + 1, y: stemTop - 5))
        }
    }
}
