import SwiftUI
import CoreText

@main
struct PaperPlaneApp: App {
    init() {
        Self.registerFontsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    /// The fonts are registered in Info.plist (UIAppFonts). This is only a safety net
    /// in case that ever fails, so the marker and handwriting never fall back to system.
    private static func registerFontsIfNeeded() {
        for name in [AppFont.marker, AppFont.hand] where UIFont(name: name, size: 12) == nil {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
