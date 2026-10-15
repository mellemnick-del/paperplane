import UIKit

/// A light tap on each point, a heavier thump on each crumple.
final class Haptics {
    private let tap = UIImpactFeedbackGenerator(style: .light)
    private let thump = UIImpactFeedbackGenerator(style: .heavy)

    init() {
        tap.prepare()
        thump.prepare()
    }

    func point() {
        tap.impactOccurred()
        tap.prepare()
    }

    func crumple() {
        thump.impactOccurred()
        thump.prepare()
    }
}
