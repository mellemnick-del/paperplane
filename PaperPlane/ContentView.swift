import SwiftUI
import StoreKit

struct ContentView: View {
    @State private var game = GameEngine()
    @State private var sound = SoundFX()
    @State private var haptics = Haptics()
    @State private var ads = AdsManager()
    @State private var gameCenter = GameCenter()
    @StateObject private var store = Store()
    @StateObject private var clock = FrameClock()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    private static let reviewPromptKey = "paperplane.reviewPromptedVersion"

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
                AppDelegate.refreshOrientations() // a foldable may have just opened or closed
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        // Hold anywhere to climb, let go to dive. Covers the whole screen, edges included.
        .overlay(
            TouchSurface(onDown: fingerDown, onUp: { game.release() })
                .ignoresSafeArea()
        )
        // Buttons sit above the touch layer so tapping them doesn't also start a game.
        .overlay(
            MenuButtons(
                game: game,
                canContinue: canContinue,
                adsRemoved: store.adsRemoved,
                price: store.price,
                onContinue: smoothACrease,
                onBuy: { Task { await store.buy() } },
                onRestore: { Task { await store.restore() } }
            )
        )
        .onChange(of: game.state, initial: true) { _, state in
            gameCenter.showAccessPoint(state != .play)
        }
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
        let ads = self.ads
        let gameCenter = self.gameCenter
        let requestReview = self.requestReview
        game.onGameOver = {
            ads.noteGameOver()
            ads.startIfNeeded() // consent and tracking prompts wait until after the first game
            gameCenter.submit(score: game.score)
            Self.askForReviewIfDue(game: game, requestReview: requestReview)
        }
        clock.start { time in
            game.step(to: time)
        }
        gameCenter.authenticate()
        if game.gamesPlayed > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { ads.startIfNeeded() }
        }
    }

    /// A finger came down. After a game over this either starts the next game or, now and
    /// then, shows an interstitial ad first (the next tap then starts the game).
    private func fingerDown() {
        if game.canRestart && ads.shouldShowInterstitial(gamesPlayed: game.gamesPlayed, adsRemoved: store.adsRemoved) {
            ads.showInterstitial()
        } else {
            game.press()
        }
    }

    /// The "smooth a crease" continue: once per game, after scoring at least 3.
    private var canContinue: Bool {
        game.state == .over && !game.revivedThisGame && game.score >= 3
            && (store.adsRemoved || ads.rewardedReady)
    }

    private func smoothACrease() {
        if store.adsRemoved {
            game.revive()
        } else {
            let game = self.game
            ads.showRewarded { game.revive() }
        }
    }

    /// Apple's rating prompt after a new best, from the 5th game on, once per app version.
    /// (iOS also limits it to a few times a year on its own.)
    private static func askForReviewIfDue(game: GameEngine, requestReview: RequestReviewAction) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1"
        guard game.newBest, game.gamesPlayed >= 5,
              UserDefaults.standard.string(forKey: reviewPromptKey) != version else { return }
        UserDefaults.standard.set(version, forKey: reviewPromptKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { requestReview() }
    }
}

/// Small handwritten buttons: "Remove ads" and "Restore purchase" on the start screen, and on
/// the game over screen the "smooth a crease" continue plus "Remove ads".
private struct MenuButtons: View {
    let game: GameEngine
    let canContinue: Bool
    let adsRemoved: Bool
    let price: String?
    let onContinue: () -> Void
    let onBuy: () -> Void
    let onRestore: () -> Void

    private var k: Double { max(1, game.H / 956) }

    var body: some View {
        ZStack {
            if game.state == .ready {
                HStack(spacing: 16 * k) {
                    if !adsRemoved { link("Remove ads", action: onBuy) }
                    link("Restore purchase", action: onRestore)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 16)
                .padding(.top, 10)
            }
            if game.state == .over {
                VStack(spacing: 12 * k) {
                    if canContinue { continueButton }
                    if !adsRemoved {
                        link(price.map { "Remove ads (\($0))" } ?? "Remove ads", action: onBuy)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 150 * k)
            }
        }
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    if !adsRemoved { Image(systemName: "play.rectangle") }
                    Text("Smooth a crease")
                }
                .font(.custom(AppFont.marker, fixedSize: 22 * k))
                .foregroundStyle(Palette.redInk)
                Text(adsRemoved ? "keep flying with one wing" : "watch a video, keep flying")
                    .font(.custom(AppFont.hand, fixedSize: 16 * k))
                    .foregroundStyle(Palette.pencilLead)
            }
            .padding(.horizontal, 22 * k)
            .padding(.vertical, 10 * k)
            .background(
                RoundedRectangle(cornerRadius: 14 * k)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 14 * k).stroke(Palette.graphite, lineWidth: 2 * k))
            )
            .rotationEffect(.degrees(-2))
        }
        .buttonStyle(.plain)
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom(AppFont.hand, fixedSize: 17 * k))
                .foregroundStyle(Palette.pencilLead)
                .underline()
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

/// The handwritten lines at the bottom of the page.
private struct Caption: View {
    let game: GameEngine
    let time: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 1 on every iPhone, larger on iPads (same scale as the renderer's lines).
    private var k: Double { max(1, game.H / 956) }
    private var eyebrowSize: Double { 27.2 * k }   // 1.7rem
    private var lineSize: Double { 21.6 * k }      // 1.35rem
    private var hintSize: Double { 17.6 * k }      // 1.1rem

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
        case .ready: return "Hold anywhere to take off"
        case .play: return nil
        case .over:
            let pencils = game.score == 1 ? "1 pencil" : "\(game.score) pencils"
            return "\(pencils)   ·   best \(game.best)"
        }
    }

    private var hint: String? {
        switch game.state {
        case .ready: return nil
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

