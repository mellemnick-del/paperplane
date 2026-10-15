import Foundation
import CoreGraphics

/// All the game rules, ported line for line from prototype/index.html.
/// Sizes and speeds are in screen heights (H) so it plays the same on any iPhone.
/// No SwiftUI in here: the view calls `step(to:size:)` once per frame and the
/// renderer reads the public state to draw it.
final class GameEngine {
    enum State { case ready, play, over }

    struct Pencil {
        var x: Double
        var top: Double
        var bot: Double
        var passed = false
        var topColor: Int
        var botColor: Int
    }

    enum DoodleKind: CaseIterable { case stain, star, spiral, heart, x, smiley }

    struct Doodle {
        var x: Double
        var y: Double
        var kind: DoodleKind
        var size: Double
        var rot: Double
    }

    struct Plane {
        var x = 0.0, y = 0.0, vy = 0.0, angle = 0.0
        var hits = 0
        var inv = 0.0
        var spin = 0.0
        /// Four values in -0.5...0.5 per crease; three creases per crumple.
        var creases: [[Double]] = []
    }

    // Tuning knobs, in screen heights (H)
    static let gravity = 1.5        // H/s² when you let go
    static let lift = 1.75          // H/s² when you hold
    static let maxUp = 0.62, maxDown = 0.8
    static let speed = 0.33         // scroll speed, H/s
    static let spacing = 0.40       // distance between pencil pairs, H
    static let gapStart = 0.31, gapMin = 0.21
    static let lives = 3
    static let pencilColorCount = 5 // yellow twice, so it is the most common

    private static let bestKey = "paperplane.best"

    // Screen size in points
    private(set) var W = 0.0
    private(set) var H = 0.0

    private(set) var plane = Plane()
    private(set) var pencils: [Pencil] = []
    private(set) var doodles: [Doodle] = []
    private(set) var trail: [(x: Double, y: Double)] = []
    private(set) var state: State = .ready
    private(set) var score = 0
    private(set) var best = 0
    private(set) var newBest = false
    private(set) var worldX = 0.0
    private(set) var shake = 0.0
    private(set) var pop = 0.0

    private var holding = false
    var isHolding: Bool { holding }
    /// Smoothed frames per second, for the debug readout.
    private(set) var fps = 0.0
    private var needRelease = false
    private var untilNext = 0.0
    private var untilDoodle = 0.0
    private var overAt = 0.0
    private var trailClock = 0.0

    /// Seconds since the engine started; drives the bob and the wobble.
    private(set) var clock = 0.0
    private var lastTime: Double?
    private var configured = false

    var onScore: () -> Void = {}
    var onCrumple: () -> Void = {}

    init() {
        best = UserDefaults.standard.integer(forKey: Self.bestKey)
    }

    var pencilWidth: Double { H * 0.066 }

    // MARK: Frame

    /// Full screen size in points, set by the view whenever it changes.
    var viewSize: CGSize = .zero

    /// Called once per display frame by FrameClock.
    func step(to time: Double) {
        step(to: time, size: viewSize)
    }

    func step(to time: Double, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        W = Double(size.width)
        H = Double(size.height)
        if !configured {
            configured = true
            reset()
            seedDoodles()
        }
        let dt = lastTime.map { min(0.04, max(0, time - $0)) } ?? 0
        lastTime = time
        if dt > 0 { fps = fps * 0.9 + (1 / dt) * 0.1 }
        clock += dt
        update(dt)
    }

    // MARK: Input

    /// Finger down anywhere.
    func press() {
        holding = true
        if state == .ready { start(); return }
        if state == .over && !needRelease && clock - overAt > 0.7 { start() }
    }

    /// Finger up, or the app lost focus.
    func release() {
        holding = false
        needRelease = false
    }

    // MARK: Rules

    private func reset() {
        plane = Plane(x: W * 0.28, y: H * 0.45)
        pencils = []
        trail = []
        score = 0
        newBest = false
        untilNext = H * 0.55
    }

    private func currentSpeed() -> Double {
        Self.speed * H * min(1.6, 1 + Double(score) * 0.02)
    }

    private func spawnPencil() {
        let gap = max(Self.gapMin, Self.gapStart - Double(score) * 0.004) * H
        let margin = H * 0.12
        let center = margin + gap / 2 + Double.random(in: 0..<1) * (H - 2 * margin - gap)
        pencils.append(Pencil(
            x: W + pencilWidth, top: center - gap / 2, bot: center + gap / 2,
            topColor: Int.random(in: 0..<Self.pencilColorCount),
            botColor: Int.random(in: 0..<Self.pencilColorCount)
        ))
    }

    private func spawnDoodle(at x: Double) {
        doodles.append(Doodle(
            x: x,
            y: H * (0.12 + Double.random(in: 0..<1) * 0.76),
            kind: DoodleKind.allCases.randomElement()!,
            size: H * (0.02 + Double.random(in: 0..<1) * 0.025),
            rot: Double.random(in: 0..<(2 * .pi))
        ))
    }

    private func seedDoodles() {
        doodles = []
        var x = 0.0
        while x < W + H * 0.3 {
            spawnDoodle(at: x + Double.random(in: 0..<1) * H * 0.15)
            x += H * 0.25
        }
        untilDoodle = H * 0.25
    }

    private func start() {
        reset()
        state = .play
    }

    private func crumple(bounce: Double) {
        plane.hits += 1
        plane.inv = 1.3
        plane.vy = bounce
        shake = 1
        for _ in 0..<3 {
            plane.creases.append((0..<4).map { _ in Double.random(in: 0..<1) - 0.5 })
        }
        onCrumple()
        if plane.hits >= Self.lives { gameOver() }
    }

    private func gameOver() {
        state = .over
        overAt = clock
        plane.spin = 7
        if score > best {
            best = score
            newBest = true
            UserDefaults.standard.set(best, forKey: Self.bestKey)
        }
        needRelease = holding
    }

    /// Circle vs rectangle.
    private func hitsRect(_ cx: Double, _ cy: Double, _ r: Double,
                          _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> Bool {
        let nx = max(x0, min(cx, x1))
        let ny = max(y0, min(cy, y1))
        let dx = cx - nx, dy = cy - ny
        return dx * dx + dy * dy < r * r
    }

    private func update(_ dt: Double) {
        let sp = currentSpeed()

        if state == .ready {
            plane.x = W * 0.28
            plane.y = H * 0.45 + sin(clock / 0.32) * H * 0.012
            plane.angle = cos(clock / 0.32) * 0.12
        }

        if state == .play {
            worldX += sp * dt
            let lift = Self.lift * (1 - 0.12 * Double(plane.hits))
            var acc = (holding ? -lift : Self.gravity) * H
            if plane.hits > 0 {
                acc += sin(clock / 0.09) * H * 0.35 * Double(plane.hits) // crumpled wings wobble
            }
            plane.vy = max(-Self.maxUp * H, min(Self.maxDown * H, plane.vy + acc * dt))
            plane.y += plane.vy * dt
            plane.angle = atan2(plane.vy, sp) * 0.8
            plane.inv = max(0, plane.inv - dt)

            untilNext -= sp * dt
            if untilNext <= 0 {
                spawnPencil()
                untilNext += Self.spacing * H
            }

            let r = H * 0.018, w = pencilWidth, tip = w * 1.1
            for i in pencils.indices {
                pencils[i].x -= sp * dt
                let o = pencils[i]
                if !o.passed && o.x + w / 2 < plane.x {
                    pencils[i].passed = true
                    score += 1
                    pop = 1
                    onScore()
                }
                if plane.inv > 0 || state != .play { continue }
                if hitsRect(plane.x, plane.y, r, o.x - w / 2, -H, o.x + w / 2, o.top - tip * 0.35) {
                    crumple(bounce: 0.4 * H)
                } else if hitsRect(plane.x, plane.y, r, o.x - w / 2, o.bot + tip * 0.35, o.x + w / 2, H * 2) {
                    crumple(bounce: -0.5 * H)
                }
            }
            pencils.removeAll { $0.x <= -w * 2 }

            if state == .play && plane.inv <= 0 {
                if plane.y < r {
                    plane.y = r
                    crumple(bounce: 0.35 * H)
                } else if plane.y > H - r {
                    plane.y = H - r
                    crumple(bounce: -0.55 * H)
                }
            }
            plane.y = max(-H * 0.1, min(H * 1.1, plane.y))

            // The prototype adds one trail point per 60 Hz frame; sample at the
            // same rate so the trail is the same length on any display.
            trailClock += dt
            while trailClock >= 1.0 / 60 {
                trailClock -= 1.0 / 60
                trail.append((x: plane.x, y: plane.y))
                if trail.count > 40 { trail.removeFirst() }
            }
            for i in trail.indices { trail[i].x -= sp * dt }
        }

        if state == .over {
            // tumble to the bottom of the page
            plane.vy = min(Self.maxDown * H, plane.vy + Self.gravity * H * dt)
            plane.y = min(H * 1.2, plane.y + plane.vy * dt)
            plane.angle += plane.spin * dt
            plane.spin *= pow(0.98, dt * 60) // prototype slows 2% per 60 Hz frame
        }

        if state != .over {
            let drift = (state == .play ? sp : sp * 0.35) * dt
            for i in doodles.indices { doodles[i].x -= drift }
            untilDoodle -= drift
            if untilDoodle <= 0 {
                spawnDoodle(at: W + H * 0.1)
                untilDoodle += H * (0.2 + Double.random(in: 0..<1) * 0.15)
            }
            doodles.removeAll { $0.x <= -H * 0.2 }
            if state == .ready { worldX += sp * 0.35 * dt }
        }

        shake = max(0, shake - dt * 3)
        pop = max(0, pop - dt * 4)
    }
}
