import SwiftUI
import UIKit

/// Touch gesture recognizer for flick input. Reports touch-down, touch-move
/// (with cumulative drag distance from the start point and elapsed time), and
/// touch-up. Ported from azooKey's `TouchDownAndTouchUpGestureView` (MIT).
///
/// The custom `UIGestureRecognizer` subclass is needed because SwiftUI's
/// built-in gestures don't give reliable down/up timing or absolute drag
/// distance in one callback — both are required for flick direction detection.
struct FlickGesture: UIViewRepresentable {
    let onTouchDown: () -> Void
    let onTouchMove: (CGFloat, CGFloat, TimeInterval) -> Void
    let onTouchUp: (CGFloat, CGFloat, TimeInterval) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let recognizer = FlickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTouchDown = onTouchDown
        context.coordinator.onTouchMove = onTouchMove
        context.coordinator.onTouchUp = onTouchUp
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTouchDown: onTouchDown, onTouchMove: onTouchMove, onTouchUp: onTouchUp)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTouchDown: () -> Void
        var onTouchMove: (CGFloat, CGFloat, TimeInterval) -> Void
        var onTouchUp: (CGFloat, CGFloat, TimeInterval) -> Void
        private var startTime: Date = .init()

        init(onTouchDown: @escaping () -> Void, onTouchMove: @escaping (CGFloat, CGFloat, TimeInterval) -> Void, onTouchUp: @escaping (CGFloat, CGFloat, TimeInterval) -> Void) {
            self.onTouchDown = onTouchDown
            self.onTouchMove = onTouchMove
            self.onTouchUp = onTouchUp
        }

        @objc func handle(_ gesture: FlickGestureRecognizer) {
            switch gesture.state {
            case .began:
                startTime = .init()
                onTouchDown()
            case .changed:
                onTouchMove(gesture.dx, gesture.dy, Date().timeIntervalSince(startTime))
            case .ended:
                onTouchUp(gesture.dx, gesture.dy, Date().timeIntervalSince(startTime))
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

/// A simple gesture recognizer that tracks the drag vector from the start
/// point. Unlike `UIPanGestureRecognizer`, it begins immediately (no minimum
/// distance) and reports the dx/dy offset, which is what flick direction
/// detection needs.
final class FlickGestureRecognizer: UIGestureRecognizer {
    private var startLocation: CGPoint = .zero
    private(set) var dx: CGFloat = 0
    private(set) var dy: CGFloat = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible {
            startLocation = touches.first?.location(in: nil) ?? .zero
            state = .began
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .changed
        let location = touches.first?.location(in: nil) ?? .zero
        dx = location.x - startLocation.x
        dy = location.y - startLocation.y
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .ended
        let location = touches.first?.location(in: nil) ?? .zero
        dx = location.x - startLocation.x
        dy = location.y - startLocation.y
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}
