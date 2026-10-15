import UIKit

/// Decides which orientations the game allows, screen by screen.
///
/// Regular iPhones stay portrait only, so turning the phone does not flip the game. Big screens
/// (iPads, and foldable iPhones when opened) allow every orientation so the notebook fills the
/// whole display instead of sitting in a portrait box with black bars on both sides.
/// Info.plist lists every orientation; this narrows it down at run time.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad { return .all }
        return Self.isLargeScreen(window?.windowScene?.screen) ? .allButUpsideDown : .portrait
    }

    /// True when the physical screen's short side is at least 600 points. Every regular iPhone
    /// is well under that (the Pro Max is 440), so only opened foldables and the like qualify.
    static func isLargeScreen(_ screen: UIScreen?) -> Bool {
        guard let screen, screen.nativeScale > 0 else { return false }
        let size = screen.nativeBounds.size
        return min(size.width, size.height) / screen.nativeScale >= 600
    }

    /// Ask iOS to check the allowed orientations again, for example after the phone unfolds.
    static func refreshOrientations() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}
