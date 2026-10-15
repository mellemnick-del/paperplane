import SwiftUI
import UIKit

/// Full-screen touch layer: any finger down means "hold", all fingers up means "let go".
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

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let wasUp = active.isEmpty
        active.formUnion(touches)
        if wasUp { onDown() }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lift(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lift(touches)
    }

    private func lift(_ touches: Set<UITouch>) {
        guard !active.isEmpty else { return }
        active.subtract(touches)
        // Drop any touch UIKit has finished with but never reported, so we can never get stuck.
        active = active.filter { $0.phase != .ended && $0.phase != .cancelled }
        if active.isEmpty { onUp() }
    }
}
