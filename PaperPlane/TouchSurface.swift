import SwiftUI
import UIKit

/// Full-screen touch layer: any finger down means "hold", all fingers up means "let go".
/// On an iPad (or Mac) with a keyboard, holding the spacebar counts as a finger too.
///
/// This replaces a SwiftUI DragGesture, which never reports the end of a touch that iOS
/// cancels (a thumb brushing the home-swipe edge, a second finger, an incoming alert).
/// The game then thought the finger was still down and ignored every new touch.
/// UIKit tells us about every touch, including cancelled ones.
struct TouchSurface: UIViewRepresentable {
    var onDown: () -> Void
    var onUp: () -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.onDown = onDown
        view.onUp = onUp
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.onDown = onDown
        view.onUp = onUp
    }
}

final class TouchView: UIView {
    var onDown: () -> Void = {}
    var onUp: () -> Void = {}
    private var active = Set<UITouch>()
    private var spaceDown = false
    private var isDown = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityLabel = "Paper Plane game. Hold to climb, let go to dive."
        accessibilityTraits = .allowsDirectInteraction
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { becomeFirstResponder() } // so the spacebar reaches us
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        active.formUnion(touches)
        sync()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lift(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lift(touches)
    }

    private func lift(_ touches: Set<UITouch>) {
        active.subtract(touches)
        // Drop any touch UIKit has finished with but never reported, so we can never get stuck.
        active = active.filter { $0.phase != .ended && $0.phase != .cancelled }
        sync()
    }

    // MARK: Keyboard

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.key?.keyCode == .keyboardSpacebar }) {
            spaceDown = true
            sync()
        } else {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if releaseSpace(presses) { sync() } else { super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if releaseSpace(presses) { sync() } else { super.pressesCancelled(presses, with: event) }
    }

    private func releaseSpace(_ presses: Set<UIPress>) -> Bool {
        guard presses.contains(where: { $0.key?.keyCode == .keyboardSpacebar }) else { return false }
        spaceDown = false
        return true
    }

    /// Fire onDown / onUp only when the combined state (any finger or the spacebar) changes.
    private func sync() {
        let down = !active.isEmpty || spaceDown
        guard down != isDown else { return }
        isDown = down
        if down { onDown() } else { onUp() }
    }
}
