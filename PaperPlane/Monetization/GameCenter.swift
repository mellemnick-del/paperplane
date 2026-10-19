import GameKit

/// Game Center: signs the player in quietly, posts their best score to the leaderboard, and
/// shows Apple's small Game Center button on the start and game over screens.
final class GameCenter {
    static let leaderboardID = "paperplane.best"

    private(set) var signedIn = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            DispatchQueue.main.async {
                if let viewController, let top = UIApplication.shared.topViewController {
                    top.present(viewController, animated: true)
                    return
                }
                self?.signedIn = GKLocalPlayer.local.isAuthenticated
                GKAccessPoint.shared.location = .topTrailing
            }
        }
    }

    /// Show Apple's Game Center button only when the player isn't flying.
    func showAccessPoint(_ show: Bool) {
        let active = show && signedIn
        if GKAccessPoint.shared.isActive != active {
            GKAccessPoint.shared.isActive = active
        }
    }

    func submit(score: Int) {
        guard signedIn, score > 0 else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [Self.leaderboardID]) { _ in }
    }
}
