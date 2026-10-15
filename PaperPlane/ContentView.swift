import SwiftUI

struct ContentView: View {
    @State private var game = GameEngine()
    @State private var sound = SoundFX()
    @State private var haptics = Haptics()
    @StateObject private var clock = FrameClock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // Reading the frame counter makes SwiftUI redraw on every display refresh.
        let _ = clock.frame
        GeometryReader { geo in
            let full = CGSize(
                width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            )
            ZStack(alignment: .bottom) {
                Canvas { ctx, _ in
                    GameRenderer.draw(game, in: ctx)
                }
                .ignoresSafeArea()

                Caption(game: game, time: game.clock)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 26)
                    .allowsHitTesting(false)
            }
            .onChange(of: full, initial: true) { _, size in
                game.viewSize = size
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        // Hold anywhere to climb, let go to dive. Covers the whole screen, edges included.
        .overlay(
            TouchSurface(onDown: { game.press() }, onUp: { game.release() })
                .ignoresSafeArea()
        )
        .statusBarHidden(true)
        // Ask iOS to let the game have the first swipe at the screen edges, so a thumb
        // near the home bar or the top does not get stolen by a system gesture mid-flight.
        .defersSystemGestures(on: .all)
        .onAppear(perform: wire)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                sound.start()
            } else {
                game.release()
            }
        }
    }

    private func wire() {
        let game = self.game
        let sound = self.sound
        let haptics = self.haptics
        game.onScore = {
            sound.point()
            haptics.point()
        }
        game.onCrumple = {
            sound.crumple()
            haptics.crumple()
        }
        clock.start { time in
            game.step(to: time)
        }
    }
}

/// The handwritten lines at the bottom of the page.
private struct Caption: View {
    let game: GameEngine
    let time: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let eyebrowSize = 27.2   // 1.7rem
    private let lineSize = 21.6      // 1.35rem
    private let hintSize = 17.6      // 1.1rem

    var body: some View {
        VStack(spacing: 2) {
            Text(eyebrow)
                .font(.custom(AppFont.marker, fixedSize: eyebrowSize))
                .foregroundStyle(Palette.redInk)
                .rotationEffect(.degrees(-3))
                .frame(minHeight: eyebrowSize * 1.2)

            if let line {
                Text(line)
                    .font(.custom(AppFont.hand, fixedSize: lineSize))
                    .foregroundStyle(Palette.graphite)
                    .frame(maxWidth: lineSize * 0.5 * 22)
            }

            if let hint {
                Text(hint)
                    .font(.custom(AppFont.hand, fixedSize: hintSize))
                    .foregroundStyle(Palette.pencilLead)
                    .opacity(hintOpacity)
            }
        }
        .multilineTextAlignment(.center)
        .lineSpacing(lineSize * 0.05)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var eyebrow: String {
        guard game.state == .over else { return " " }
        return game.newBest ? "New best!" : "Crumpled!"
    }

    private var line: String? {
        switch game.state {
        case .ready: return "Hold to climb. Let go to dive."
        case .play: return nil
        case .over:
            let pencils = game.score == 1 ? "1 pencil" : "\(game.score) pencils"
            return "\(pencils)   ·   best \(game.best)"
        }
    }

    private var hint: String? {
        switch game.state {
        case .ready: return "Clip a pencil and your wing crumples. Three strikes."
        case .play: return nil
        case .over: return "Tap to fly again"
        }
    }

    /// The prototype's 1.4 s ease-in-out blink down to 35%, only on "Tap to fly again".
    private var hintOpacity: Double {
        guard game.state == .over, !reduceMotion else { return 1 }
        let phase = time.truncatingRemainder(dividingBy: 1.4) / 1.4
        let wave = 0.5 - 0.5 * cos(phase * 2 * .pi)   // 0 -> 1 -> 0
        return 1 - 0.65 * wave
    }
}

