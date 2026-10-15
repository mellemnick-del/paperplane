import SwiftUI
import QuartzCore

/// Drives the game from the screen's own refresh (CADisplayLink), once per display frame.
///
/// TimelineView(.animation) did not deliver frames reliably on device: the game only
/// advanced when a touch changed the view's state. A display link fires on every refresh
/// no matter what SwiftUI is doing, so the game steps here and `frame` then tells
/// SwiftUI to redraw.
final class FrameClock: ObservableObject {
    @Published private(set) var frame = 0
    private var link: CADisplayLink?
    private var onFrame: (Double) -> Void = { _ in }

    func start(onFrame: @escaping (Double) -> Void) {
        self.onFrame = onFrame
        guard link == nil else { return }
        let link = CADisplayLink(target: Ticker(self), selector: #selector(Ticker.tick(_:)))
        link.add(to: .main, forMode: .common) // keeps ticking while a finger is down
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    fileprivate func tick(_ link: CADisplayLink) {
        onFrame(link.targetTimestamp)
        frame &+= 1
    }
}

/// CADisplayLink needs an Objective-C target and holds it strongly; this keeps the
/// clock itself out of that retain loop.
private final class Ticker: NSObject {
    weak var clock: FrameClock?
    init(_ clock: FrameClock) { self.clock = clock }

    @objc func tick(_ link: CADisplayLink) {
        guard let clock else { link.invalidate(); return }
        clock.tick(link)
    }
}
