import SwiftUI

/// Le graphe. Le temps descend, l'écart s'écarte.
struct ScopeView: View {

    let engine: RhythmEngine
    /// Profondeur d'historique visible, en secondes.
    var depth: Double = 6.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .accessibilityLabel("Graphe de justesse rythmique")
        .accessibilityValue(summary)
    }

    private var summary: String {
        guard let delta = engine.lastDelta else { return "aucune note" }
        let ms = Int((delta * 1000).rounded())
        let sense = abs(delta) <= engine.tolerance ? "dans le temps"
                  : (delta < 0 ? "en avance" : "en retard")
        return "\(abs(ms)) millisecondes, \(sense)"
    }

    // =====================================================================

    private func draw(context: GraphicsContext, size: CGSize, now: Double) {
        let cx = size.width / 2
        let window = engine.settings.windowMs / 1000
        let scale = (size.width / 2 - 16) / window        // points par seconde d'écart
        let pxPerSecond = size.height / depth

        // Bande de tolérance. (EX-063)
        let tolPx = engine.tolerance * scale
        context.fill(
            Path(CGRect(x: cx - tolPx, y: 0, width: tolPx * 2, height: size.height)),
            with: .color(Palette.onTime.opacity(0.10)))

        // Graduations tous les 50 ms.
        var graduation = 0.050
        while graduation <= window {
            let dx = graduation * scale
            for x in [cx - dx, cx + dx] {
                context.fill(Path(CGRect(x: x, y: 0, width: 0.5, height: size.height)),
                             with: .color(Palette.grid))
            }
            graduation += 0.050
        }

        // Temps du métronome qui descendent. (EX-068)
        //
        // Trois niveaux : le premier temps de la mesure est marqué aux deux
        // bords, le temps est plein, la subdivision est plus discrète. (EX-042)
        if engine.running {
            for beat in engine.beats {
                let y = (now - beat.time) * pxPerSecond
                guard y > -2, y < size.height else { continue }
                let opacity = beat.isAccent ? 0.9 : (beat.isMain ? 0.5 : 0.2)
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)),
                             with: .color(Palette.beatLine.opacity(opacity)))
                if beat.isAccent {
                    for rect in [CGRect(x: 0, y: y - 1, width: 14, height: 2),
                                 CGRect(x: size.width - 14, y: y - 1, width: 14, height: 2)] {
                        context.fill(Path(rect), with: .color(Palette.beatLine))
                    }
                }
            }
        }

        // Notes jouées. (EX-062)
        for hit in engine.hits {
            let y = (now - hit.time) * pxPerSecond
            guard y > -16, y < size.height else { continue }
            let dx = min(max(hit.delta * scale, -size.width / 2 + 8), size.width / 2 - 8)
            let fade = max(0.2, 1 - y / size.height)

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
            context.fill(Path(CGRect(x: cx - 3, y: 0, width: 6, height: size.height)),
                         with: .color(Palette.plumb.opacity(0.15 * pulse)))
        }
        context.fill(Path(CGRect(x: cx - 0.5, y: 0, width: 1, height: size.height)),
                     with: .color(Palette.plumb.opacity(0.55)))
    }
}
