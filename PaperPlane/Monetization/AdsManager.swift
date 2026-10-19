import UIKit
import StoreKit
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

/// Google AdMob: one interstitial between rounds and one optional rewarded video.
///
/// Order at start-up, as Google and Apple recommend: Google's consent form (shown only where
/// the law requires it, like Europe), then Apple's "Allow tracking?" prompt, then the ads SDK.
/// This waits until after the player's first game so the first thing they see is the game.
final class AdsManager: NSObject, FullScreenContentDelegate {
    /// Real ad units from Nick's AdMob account (app ID is in Info.plist, GADApplicationIdentifier).
    /// Only App Store downloads use these. Builds from Xcode and TestFlight use Google's test
    /// units, so testing can never count as invalid clicks on the real account.
    enum Unit {
        static let rewarded = "ca-app-pub-5409507532746127/6115955318"
        static let interstitial: String? = nil // TODO: real "Between rounds" ID from AdMob

        static let testRewarded = "ca-app-pub-3940256099942544/1712485313"
        static let testInterstitial = "ca-app-pub-3940256099942544/4411468910"
    }

    private var rewardedUnit = Unit.testRewarded
    private var interstitialUnit = Unit.testInterstitial

    /// Interstitial pacing: never in a player's first few games, at most every 3rd game over,
    /// and at least 2 minutes apart.
    static let gameOversBetweenAds = 3
    static let minSecondsBetweenAds: TimeInterval = 120
    static let firstGameWithAds = GameEngine.learnerGames + 2

    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var started = false
    private var sdkReady = false
    private var gameOversSinceAd = 0
    private var lastInterstitial = Date.distantPast
    private var earnedReward = false
    private var onReward: (() -> Void)?

    var rewardedReady: Bool { rewarded != nil }

    // MARK: Start-up

    func startIfNeeded() {
        guard !started else { return }
        started = true
        let parameters = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let vc = UIApplication.shared.topViewController else {
                    self.afterConsent()
                    return
                }
                ConsentForm.loadAndPresentIfRequired(from: vc) { [weak self] _ in
                    DispatchQueue.main.async { self?.afterConsent() }
                }
            }
        }
    }

    private func afterConsent() {
        guard ConsentInformation.shared.canRequestAds else { return }
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            ATTrackingManager.requestTrackingAuthorization { [weak self] _ in
                DispatchQueue.main.async { self?.startSDK() }
            }
        } else {
            startSDK()
        }
    }

    private func startSDK() {
        guard !sdkReady else { return }
        sdkReady = true
        Task { @MainActor in
            if await Self.isAppStoreDownload() {
                rewardedUnit = Unit.rewarded
                interstitialUnit = Unit.interstitial ?? Unit.testInterstitial
            }
            MobileAds.shared.start(completionHandler: nil)
            loadInterstitial()
            loadRewarded()
        }
    }

    /// True only for copies downloaded from the App Store. Xcode and TestFlight builds are not.
    private static func isAppStoreDownload() async -> Bool {
        #if DEBUG
        return false
        #else
        guard let result = try? await AppTransaction.shared else { return false }
        switch result {
        case .verified(let transaction):
            return transaction.environment == .production
        case .unverified(let transaction, _):
            return transaction.environment == .production
        }
        #endif
    }

    // MARK: Interstitial

    func noteGameOver() { gameOversSinceAd += 1 }

    func shouldShowInterstitial(gamesPlayed: Int, adsRemoved: Bool) -> Bool {
        !adsRemoved
            && interstitial != nil
            && gamesPlayed >= Self.firstGameWithAds
            && gameOversSinceAd >= Self.gameOversBetweenAds
            && Date().timeIntervalSince(lastInterstitial) >= Self.minSecondsBetweenAds
    }

    func showInterstitial() {
        guard let ad = interstitial, let vc = UIApplication.shared.topViewController else { return }
        interstitial = nil
        gameOversSinceAd = 0
        lastInterstitial = Date()
        ad.present(from: vc)
    }

    private func loadInterstitial() {
        InterstitialAd.load(with: interstitialUnit, request: Request()) { [weak self] ad, _ in
            DispatchQueue.main.async {
                ad?.fullScreenContentDelegate = self
                self?.interstitial = ad
            }
        }
    }

    // MARK: Rewarded

    /// Plays the rewarded video; `reward` runs after the video is closed, only if it was earned.
    func showRewarded(reward: @escaping () -> Void) {
        guard let ad = rewarded, let vc = UIApplication.shared.topViewController else { return }
        rewarded = nil
        earnedReward = false
        onReward = reward
        ad.present(from: vc) { [weak self] in
            self?.earnedReward = true
        }
    }

    private func loadRewarded() {
        RewardedAd.load(with: rewardedUnit, request: Request()) { [weak self] ad, _ in
            DispatchQueue.main.async {
                ad?.fullScreenContentDelegate = self
                self?.rewarded = ad
            }
        }
    }

    // MARK: FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        DispatchQueue.main.async { self.finished(ad) }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        DispatchQueue.main.async { self.finished(ad) }
    }

    private func finished(_ ad: FullScreenPresentingAd) {
        if ad is RewardedAd {
            if earnedReward { onReward?() }
            onReward = nil
            earnedReward = false
            loadRewarded()
        } else {
            loadInterstitial()
        }
    }
}

extension UIApplication {
    /// The view controller currently on screen, to present ads, consent and Game Center from.
    var topViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? connectedScenes.first as? UIWindowScene
        var vc = scene?.windows.first { $0.isKeyWindow }?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}
