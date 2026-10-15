import SwiftUI

/// Notebook paper palette. Deliberately light only: it is a sheet of paper.
enum Palette {
    static let paper = Color(hex: 0xFBF9F1)
    static let rule = Color(hex: 0xB9CDE6)
    static let margin = Color(hex: 0xE59A9A)
    static let graphite = Color(hex: 0x33363B)
    static let pencilLead = Color(hex: 0x6B6F76)
    static let redInk = Color(hex: 0xC8463D)
    static let hole = Color(hex: 0xE4DFCF)
    static let wood = Color(hex: 0xF0D3A6)
    static let coffee = Color(hex: 0x8A5A2B)
    static let farWing = Color(hex: 0xE2E2DC)

    /// Body and center stripe, in the same order as the prototype (yellow twice).
    static let pencils: [(body: Color, dark: Color)] = [
        (Color(hex: 0xF2C230), Color(hex: 0xD9A91C)),
        (Color(hex: 0xF2C230), Color(hex: 0xD9A91C)),
        (Color(hex: 0x4F86C6), Color(hex: 0x3A6DA8)),
        (Color(hex: 0xD9534F), Color(hex: 0xB8403C)),
        (Color(hex: 0x5FAE6B), Color(hex: 0x478F53)),
    ]
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum AppFont {
    static let marker = "PermanentMarker-Regular"
    static let hand = "PatrickHand-Regular"
}

/// Draws one frame, ported from the prototype's canvas drawing functions.
struct GameRenderer {
    let game: GameEngine
    var ctx: GraphicsContext

    private var W: Double { game.W }
    private var H: Double { game.H }
    /// Line and text scale: 1 on every iPhone, larger on iPads so strokes don't look hairline thin.
    private var k: Double { max(1, H / 956) }
    private var tau: Double { .pi * 2 }

    static func draw(_ game: GameEngine, in ctx: GraphicsContext) {
        guard game.H > 0 else {
            ctx.fill(Path(CGRect(x: 0, y: 0, width: 10_000, height: 10_000)), with: .color(Palette.paper))
            return
        }
        GameRenderer(game: game, ctx: ctx).draw()
    }

    private func draw() {
        var world = ctx
        if game.shake > 0 {
            let s = game.shake * H * 0.015
            world.translateBy(x: (Double.random(in: 0..<1) - 0.5) * s, y: (Double.random(in: 0..<1) - 0.5) * s)
        }
        drawPaper(world)
        for d in game.doodles { drawDoodle(d, world) }
        for o in game.pencils {
            drawPencil(o.x, tipY: o.top, dir: 1, color: Palette.pencils[o.topColor], world)
            drawPencil(o.x, tipY: o.bot, dir: -1, color: Palette.pencils[o.botColor], world)
        }
        drawTrail(world)
        drawPlane(world)
        drawHud(ctx)
        if game.state == .ready { warmUp(ctx) }
    }

    /// iOS builds the GPU pipeline for each new kind of stroke the first time it is drawn,
    /// which froze the game for about half a second mid-flight ("building pipeline
    /// stroke_joins ... took 0.55 seconds"). On the start screen, draw everything the game
    /// will need at an invisible opacity so that work happens before takeoff.
    private func warmUp(_ base: GraphicsContext) {
        var ctx = base
        ctx.opacity = 0.01
        let x = W * 0.8, y = H * 0.5
        drawPencil(x, tipY: y - H * 0.15, dir: 1, color: Palette.pencils[0], ctx)
        drawPencil(x, tipY: y + H * 0.15, dir: -1, color: Palette.pencils[2], ctx)

        var dashed = Path()
        dashed.move(to: CGPoint(x: x - 40, y: y))
        dashed.addLine(to: CGPoint(x: x, y: y + 10))
        dashed.addLine(to: CGPoint(x: x + 40, y: y))
        ctx.stroke(dashed, with: .color(Palette.pencilLead), style: StrokeStyle(lineWidth: 1.5 * k, dash: [5 * k, 7 * k]))

        var lines = Path()
        lines.move(to: CGPoint(x: x - 20, y: y - 20))
        lines.addLine(to: CGPoint(x: x + 20, y: y + 20))
        lines.addLine(to: CGPoint(x: x + 30, y: y))
        lines.closeSubpath()
        ctx.fill(lines, with: .color(.white))
        for width in [1.0, 1.4, 1.8, 2.0] {
            ctx.stroke(lines, with: .color(Palette.redInk), lineWidth: width * k)
            ctx.stroke(lines, with: .color(Palette.graphite), style: StrokeStyle(lineWidth: width * k, lineJoin: .round))
        }

        let label = Text("0123456789")
            .font(.custom(AppFont.marker, fixedSize: (H * 0.065).rounded()))
            .foregroundColor(Palette.graphite)
        ctx.draw(label, at: CGPoint(x: W / 2, y: H * 0.1), anchor: .center)
    }

    // MARK: Paper

    private func drawPaper(_ ctx: GraphicsContext) {
        // Over-fill so the screen shake never reveals an edge.
        ctx.fill(Path(CGRect(x: -W * 0.1, y: -H * 0.1, width: W * 1.2, height: H * 1.2)), with: .color(Palette.paper))

        let step = H * 0.042
        var rules = Path()
        var y = H * 0.14
        while y < H {
            rules.move(to: CGPoint(x: 0, y: y + 0.5))
            rules.addLine(to: CGPoint(x: W, y: y + 0.5))
            y += step
        }
        ctx.stroke(rules, with: .color(Palette.rule), lineWidth: 1 * k)

        // margin line repeats every page
        let page = W * 2.4
        var margin = Path()
        var x = W * 0.12 - game.worldX.truncatingRemainder(dividingBy: page)
        while x < W {
            if x >= -2 {
                margin.move(to: CGPoint(x: x, y: 0))
                margin.addLine(to: CGPoint(x: x, y: H))
            }
            x += page
        }
        ctx.stroke(margin, with: .color(Palette.margin), lineWidth: 1.5 * k)

        // punched holes along the top binding
        var holes = Path()
        let hs = max(34 * k, W / 10), r = H * 0.009
        var hx = hs / 2
        while hx < W {
            holes.addEllipse(in: CGRect(x: hx - r, y: H * 0.028 - r, width: r * 2, height: r * 2))
            hx += hs
        }
        ctx.fill(holes, with: .color(Palette.hole))
    }

    private func drawDoodle(_ d: GameEngine.Doodle, _ base: GraphicsContext) {
        var ctx = base
        ctx.translateBy(x: d.x, y: d.y)
        ctx.rotate(by: .radians(d.rot))
        let s = d.size
        var color = Palette.pencilLead
        var lineWidth = 1.6 * k
        ctx.opacity = 0.45

        var p = Path()
        switch d.kind {
        case .stain:
            ctx.opacity = 0.18
            color = Palette.coffee
            lineWidth = s * 0.25
            p.addArc(center: .zero, radius: s * 2.2, startAngle: .zero, endAngle: .radians(tau * 0.9), clockwise: false)
        case .star:
            for i in 0..<5 {
                let a = Double(i) * tau * 2 / 5 - .pi / 2
                let pt = CGPoint(x: cos(a) * s, y: sin(a) * s)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        case .spiral:
            var a = 0.0
            while a < tau * 3 {
                let rr = s * a / (tau * 3)
                let pt = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
                if a == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                a += 0.2
            }
        case .heart:
            p.move(to: CGPoint(x: 0, y: s * 0.8))
            p.addCurve(to: CGPoint(x: 0, y: -s * 0.3),
                       control1: CGPoint(x: -s * 1.4, y: -s * 0.2),
                       control2: CGPoint(x: -s * 0.5, y: -s * 1.1))
            p.addCurve(to: CGPoint(x: 0, y: s * 0.8),
                       control1: CGPoint(x: s * 0.5, y: -s * 1.1),
                       control2: CGPoint(x: s * 1.4, y: -s * 0.2))
        case .x:
            p.move(to: CGPoint(x: -s * 0.6, y: -s * 0.6)); p.addLine(to: CGPoint(x: s * 0.6, y: s * 0.6))
            p.move(to: CGPoint(x: s * 0.6, y: -s * 0.6)); p.addLine(to: CGPoint(x: -s * 0.6, y: s * 0.6))
        case .smiley:
            p.addArc(center: .zero, radius: s, startAngle: .zero, endAngle: .radians(tau), clockwise: false)
            p.move(to: CGPoint(x: -s * 0.35, y: -s * 0.2))
            p.addArc(center: CGPoint(x: -s * 0.35, y: -s * 0.25), radius: 0.5, startAngle: .zero, endAngle: .radians(tau), clockwise: false)
            p.move(to: CGPoint(x: s * 0.35, y: -s * 0.2))
            p.addArc(center: CGPoint(x: s * 0.35, y: -s * 0.25), radius: 0.5, startAngle: .zero, endAngle: .radians(tau), clockwise: false)
            p.move(to: CGPoint(x: -s * 0.5, y: s * 0.2))
            p.addQuadCurve(to: CGPoint(x: s * 0.5, y: s * 0.2), control: CGPoint(x: 0, y: s * 0.7))
        }
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    // MARK: Pencils

    /// A pencil standing in from the top (dir = 1, tip points down) or bottom (dir = -1, tip points up).
    private func drawPencil(_ x: Double, tipY: Double, dir: Double, color: (body: Color, dark: Color), _ ctx: GraphicsContext) {
        let w = game.pencilWidth, tip = w * 1.1, lead = tip * 0.32
        let baseY = tipY - dir * tip              // where the sharpened cone meets the body
        let farY = dir == 1 ? -H * 0.1 : H * 1.1  // off screen, past any shake
        let x0 = x - w / 2, x1 = x + w / 2
        let outline = StrokeStyle(lineWidth: 2 * k, lineJoin: .round)
        let ink = GraphicsContext.Shading.color(Palette.graphite)

        // body
        let top = min(farY, baseY), len = abs(baseY - farY)
        ctx.fill(Path(CGRect(x: x0, y: top, width: w, height: len)), with: .color(color.body))
        ctx.fill(Path(CGRect(x: x0 + w * 0.36, y: top, width: w * 0.28, height: len)), with: .color(color.dark))
        var sides = Path()
        sides.move(to: CGPoint(x: x0, y: farY)); sides.addLine(to: CGPoint(x: x0, y: baseY))
        sides.move(to: CGPoint(x: x1, y: farY)); sides.addLine(to: CGPoint(x: x1, y: baseY))
        ctx.stroke(sides, with: ink, style: outline)

        // sharpened wood cone
        var cone = Path()
        cone.move(to: CGPoint(x: x0, y: baseY))
        cone.addLine(to: CGPoint(x: x - w * 0.14, y: tipY - dir * lead))
        cone.addLine(to: CGPoint(x: x + w * 0.14, y: tipY - dir * lead))
        cone.addLine(to: CGPoint(x: x1, y: baseY))
        cone.closeSubpath()
        ctx.fill(cone, with: .color(Palette.wood))
        ctx.stroke(cone, with: ink, style: outline)

        // graphite tip
        var lead_ = Path()
        lead_.move(to: CGPoint(x: x - w * 0.14, y: tipY - dir * lead))
        lead_.addLine(to: CGPoint(x: x, y: tipY))
        lead_.addLine(to: CGPoint(x: x + w * 0.14, y: tipY - dir * lead))
        lead_.closeSubpath()
        ctx.fill(lead_, with: ink)

        // scalloped edge where paint meets wood
        var scallops = Path()
        for i in 0..<3 {
            let cx = x0 + w * (Double(i) + 0.5) / 3
            scallops.move(to: CGPoint(x: cx - w / 6, y: baseY))
            scallops.addQuadCurve(to: CGPoint(x: cx + w / 6, y: baseY), control: CGPoint(x: cx, y: baseY + dir * w * 0.22))
        }
        ctx.fill(scallops, with: .color(color.body))
        ctx.stroke(scallops, with: ink, style: outline)
    }

    // MARK: Plane

    private func drawTrail(_ base: GraphicsContext) {
        guard game.trail.count >= 2 else { return }
        var ctx = base
        ctx.opacity = 0.55
        var p = Path()
        for (i, t) in game.trail.enumerated() {
            let pt = CGPoint(x: t.x - H * 0.03, y: t.y)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        ctx.stroke(p, with: .color(Palette.pencilLead), style: StrokeStyle(lineWidth: 1.5 * k, dash: [5 * k, 7 * k]))
    }

    private func drawPlane(_ base: GraphicsContext) {
        let P = game.plane
        let L = H * 0.036
        // blink while recovering
        if P.inv > 0 && game.state == .play && Int((P.inv * 10).rounded(.down)) % 2 == 0 { return }
        var ctx = base
        ctx.translateBy(x: P.x, y: P.y)
        ctx.rotate(by: .radians(P.angle))
        // Each crumple bends the wing corners a little.
        func j(_ v: Double, _ i: Int) -> Double {
            i < P.creases.count ? v + P.creases[i][0] * L * 0.18 : v
        }
        let outline = StrokeStyle(lineWidth: 1.8 * k, lineJoin: .round)
        let ink = GraphicsContext.Shading.color(Palette.graphite)

        // far wing
        var far = Path()
        far.move(to: CGPoint(x: L, y: 0))
        far.addLine(to: CGPoint(x: j(-L, 0), y: j(-L * 0.55, 1)))
        far.addLine(to: CGPoint(x: -L * 0.55, y: -L * 0.05))
        far.closeSubpath()
        ctx.fill(far, with: .color(Palette.farWing))
        ctx.stroke(far, with: ink, style: outline)

        // near wing
        var near = Path()
        near.move(to: CGPoint(x: L, y: 0))
        near.addLine(to: CGPoint(x: j(-L * 0.9, 2), y: j(-L * 0.12, 3)))
        near.addLine(to: CGPoint(x: j(-L * 0.75, 4), y: j(L * 0.38, 5)))
        near.closeSubpath()
        ctx.fill(near, with: .color(.white))
        ctx.stroke(near, with: ink, style: outline)

        // keel fold
        var keel = Path()
        keel.move(to: CGPoint(x: L, y: 0))
        keel.addLine(to: CGPoint(x: -L * 0.6, y: L * 0.12))
        ctx.stroke(keel, with: ink, style: outline)

        // crease lines from each crumple
        var creases = Path()
        for c in P.creases {
            creases.move(to: CGPoint(x: c[0] * L * 1.2, y: c[1] * L * 0.5))
            creases.addLine(to: CGPoint(x: c[2] * L * 1.2, y: c[3] * L * 0.5 + L * 0.05))
        }
        ctx.stroke(creases, with: .color(Palette.pencilLead), lineWidth: 1 * k)
    }

    // MARK: HUD

    private func drawHud(_ base: GraphicsContext) {
        guard game.state != .ready else { return }

        // score, inked in marker, pops on each point
        var ctx = base
        let s = 1 + game.pop * 0.25
        ctx.translateBy(x: W / 2, y: H * 0.1)
        ctx.scaleBy(x: s, y: s)
        ctx.rotate(by: .radians(-0.04))
        let label = Text("\(game.score)")
            .font(.custom(AppFont.marker, fixedSize: (H * 0.065).rounded()))
            .foregroundColor(Palette.graphite)
        ctx.draw(label, at: .zero, anchor: .center)

        // wings left, as little planes in the corner
        let size = H * 0.02
        for i in 0..<GameEngine.lives {
            let x = 16 + size + Double(i) * size * 2.6, y = H * 0.1
            let lost = i >= GameEngine.lives - game.plane.hits
            var icon = base
            icon.translateBy(x: x, y: y)
            icon.rotate(by: .radians(-0.2))
            icon.opacity = lost ? 0.25 : 0.9
            var p = Path()
            p.move(to: CGPoint(x: size, y: 0))
            p.addLine(to: CGPoint(x: -size, y: -size * 0.5))
            p.addLine(to: CGPoint(x: -size * 0.6, y: size * 0.4))
            p.closeSubpath()
            icon.fill(p, with: .color(.white))
            icon.stroke(p, with: .color(Palette.graphite), lineWidth: 1.4 * k)
            if lost {
                var slash = Path()
                slash.move(to: CGPoint(x: x - size, y: y - size * 0.7))
                slash.addLine(to: CGPoint(x: x + size, y: y + size * 0.7))
                base.stroke(slash, with: .color(Palette.redInk), lineWidth: 2 * k)
            }
        }
    }
}
