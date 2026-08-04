import JapaneseKeyboardAI
import SwiftUI
import UIKit

/// Horizontal center-snap carousel for candidate cards. Built on `UIScrollView`
/// (via `UIViewRepresentable`) rather than SwiftUI's `scrollTargetBehavior` so
/// the snap experience is identical on iOS 16 and iOS 17+. Cards are rendered
/// as a single hosted SwiftUI `HStack` to keep the visual layer in SwiftUI.
struct SnapCarousel: UIViewRepresentable {
    @Binding var centeredIndex: Int
    let candidates: [RewriteCandidate]
    let showSkeletons: Bool
    /// Shrinks as streamed candidates arrive, so a placeholder is replaced by
    /// its real card rather than sitting alongside it.
    let skeletonCount: Int
    let focusedIndex: Int?
    let animatesProgrammaticScroll: Bool
    let onSelectionChanged: () -> Void
    let onTapCentered: () -> Void

    private var totalCount: Int {
        candidates.count + (showSkeletons ? skeletonCount : 0)
    }

    func makeUIView(context: Context) -> SnapCarouselView {
        let view = SnapCarouselView()
        view.scrollView.delegate = context.coordinator
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: SnapCarouselView, context: Context) {
        context.coordinator.indexBinding = $centeredIndex
        context.coordinator.onSelectionChanged = onSelectionChanged

        let count = totalCount
        let centered = max(0, min(max(count - 1, 0), centeredIndex))
        let onTap = onTapCentered

        // Skeletons never participate in selection — only render-time hit testing
        // gates the tap on real candidates. We rebuild the hosted root view each
        // update; SwiftUI diffs internally so this stays cheap for ~6 cards.
        let content = AnyView(
            HStack(spacing: SnapCarouselView.cardSpacing) {
                ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                    let isCentered = index == centered
                    CandidateCard(
                        text: candidate.replacement,
                        isSelected: index == focusedIndex
                    )
                    // Raw-touch surface rather than `.onTapGesture`: iOS 26 drops
                    // SwiftUI taps on hosted cells like these cards, and this tap
                    // is the only way to accept a rewrite. Same pattern (and same
                    // reason) as `CandidateTapSurface` in the candidate bar; the
                    // scroll pan cancelling the touch is what rejects a swipe.
                    .overlay {
                        CandidateCardTapSurface(label: "ai-card") {
                            guard isCentered else { return }
                            onTap()
                        }
                    }
                    .allowsHitTesting(isCentered)
                }
                if showSkeletons {
                    ForEach(0..<skeletonCount, id: \.self) { _ in
                        CandidateSkeletonCard()
                    }
                }
            }
        )

        view.updateContent(rootView: content, count: count)

        if view.currentCenteredIndex != centered {
            if view.bounds.width > 0 {
                let coord = context.coordinator
                coord.isProgrammaticallyScrolling = true
                view.currentCenteredIndex = centered
                view.scroll(toIndex: centered, animated: animatesProgrammaticScroll) { [weak coord] _ in
                    coord?.isProgrammaticallyScrolling = false
                }
            } else {
                // First layout hasn't happened yet — defer until layoutSubviews
                view.pendingScrollIndex = centered
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var view: SnapCarouselView?
        var indexBinding: Binding<Int>?
        var onSelectionChanged: (() -> Void)?
        var isProgrammaticallyScrolling = false

        func scrollViewWillEndDragging(
            _ scrollView: UIScrollView,
            withVelocity velocity: CGPoint,
            targetContentOffset: UnsafeMutablePointer<CGPoint>
        ) {
            guard let view else { return }
            targetContentOffset.pointee.x = view.snappedOffset(forPredictedOffset: targetContentOffset.pointee.x)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Skip during programmatic scroll — otherwise the intermediate
            // contentOffsets fired by the animation would race against the
            // target index we just wrote to `currentCenteredIndex`, snapping
            // the SwiftUI binding back to the wrong card mid-animation.
            guard !isProgrammaticallyScrolling else { return }
            guard let view, scrollView.bounds.width > 0, view.cardCount > 0 else { return }
            let newIndex = view.computedCenteredIndex
            guard newIndex != view.currentCenteredIndex else { return }
            view.currentCenteredIndex = newIndex
            onSelectionChanged?()
            indexBinding?.wrappedValue = newIndex
        }

        // A user touch should immediately cancel the programmatic-scroll guard
        // so their drag is reflected in the binding right away.
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isProgrammaticallyScrolling = false
        }
    }
}

/// `UIView` host for `SnapCarousel`. Owns the `UIScrollView` and a single
/// `UIHostingController` whose `rootView` is swapped on each update.
final class SnapCarouselView: UIView {
    static let cardWidth: CGFloat = CandidateCardMetrics.size.width
    static let cardHeight: CGFloat = CandidateCardMetrics.size.height
    static let cardSpacing: CGFloat = 12

    let scrollView = UIScrollView()
    private var hostingController: UIHostingController<AnyView>?
    fileprivate var cardCount: Int = 0
    fileprivate var currentCenteredIndex: Int = 0
    fileprivate var pendingScrollIndex: Int?

    fileprivate var sidePadding: CGFloat {
        max(0, (bounds.width - Self.cardWidth) / 2)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        // `.fast` decel + custom snap math gives a wheel-pick feel without
        // overshoot when flicking across multiple cards.
        scrollView.decelerationRate = .fast
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = false
        clipsToBounds = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    fileprivate func updateContent(rootView: AnyView, count: Int) {
        cardCount = count
        if let host = hostingController {
            host.rootView = rootView
        } else {
            let host = UIHostingController(rootView: rootView)
            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = true
            scrollView.addSubview(host.view)
            hostingController = host
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutContent()
        if let pending = pendingScrollIndex, bounds.width > 0 {
            pendingScrollIndex = nil
            scroll(toIndex: pending, animated: false)
            currentCenteredIndex = pending
        }
    }

    private func layoutContent() {
        guard let host = hostingController, cardCount > 0, bounds.width > 0 else {
            scrollView.contentSize = .zero
            return
        }
        let pad = sidePadding
        let cardsWidth = CGFloat(cardCount) * Self.cardWidth + CGFloat(max(0, cardCount - 1)) * Self.cardSpacing
        let contentWidth = pad * 2 + cardsWidth
        scrollView.contentSize = CGSize(width: contentWidth, height: bounds.height)
        host.view.frame = CGRect(x: pad, y: 0, width: cardsWidth, height: bounds.height)
    }

    fileprivate func scroll(toIndex index: Int, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard cardCount > 0, bounds.width > 0 else {
            completion?(false)
            return
        }
        let target = CGPoint(x: contentOffsetX(forCenteredIndex: index), y: 0)
        guard animated else {
            scrollView.contentOffset = target
            completion?(true)
            return
        }
        // Spring animation mirroring the pre-snap `.spring(response: 0.55,
        // dampingFraction: 0.85)` so the auto-scroll on a new refinement batch
        // feels coherent with the rest of the keyboard.
        UIView.animate(
            withDuration: 0.55,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: { [weak self] in
                self?.scrollView.contentOffset = target
            },
            completion: completion
        )
    }

    fileprivate func snappedOffset(forPredictedOffset offsetX: CGFloat) -> CGFloat {
        guard cardCount > 0, bounds.width > 0 else { return offsetX }
        return contentOffsetX(forCenteredIndex: indexForCenter(inContent: offsetX + bounds.width / 2))
    }

    fileprivate var computedCenteredIndex: Int {
        guard cardCount > 0, bounds.width > 0 else { return 0 }
        return indexForCenter(inContent: scrollView.contentOffset.x + bounds.width / 2)
    }

    private func indexForCenter(inContent x: CGFloat) -> Int {
        let approx = (x - sidePadding - Self.cardWidth / 2) / (Self.cardWidth + Self.cardSpacing)
        return max(0, min(cardCount - 1, Int(approx.rounded())))
    }

    private func contentOffsetX(forCenteredIndex index: Int) -> CGFloat {
        let cardCenter = sidePadding + CGFloat(index) * (Self.cardWidth + Self.cardSpacing) + Self.cardWidth / 2
        return cardCenter - bounds.width / 2
    }
}

/// Accept-tap surface for a candidate card. Third copy of the raw-touch pattern
/// (`CandidateTapSurface` in the candidate bar, `KeyboardToolbarTapSurface` in
/// the toolbar) because both existing ones are private to their file/module —
/// worth hoisting into one shared type if a fourth ever shows up.
private struct CandidateCardTapSurface: UIViewRepresentable {
    let label: String
    let onTap: () -> Void

    func makeUIView(context: Context) -> CandidateCardTapSurfaceView {
        CandidateCardTapSurfaceView(label: label, onTap: onTap)
    }

    func updateUIView(_ view: CandidateCardTapSurfaceView, context: Context) {
        view.onTap = onTap
    }
}

private final class CandidateCardTapSurfaceView: UIView {
    var onTap: () -> Void
    private let label: String
    private var touchStart: CGPoint?
    private static let maximumTapMovement: CGFloat = 12

    init(label: String, onTap: @escaping () -> Void) {
        self.label = label
        self.onTap = onTap
        super.init(frame: .zero)
        // Not .clear — fully transparent views have been observed dropping
        // touches in keyboard extensions (Apple forums 702798).
        backgroundColor = UIColor.white.withAlphaComponent(0.01)
        isMultipleTouchEnabled = false
        accessibilityIdentifier = "CandidateCardTapSurface.\(label)"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        touchStart = touches.first?.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        defer { touchStart = nil }
        guard let start = touchStart,
              let point = touches.first?.location(in: self) else { return }
        guard hypot(point.x - start.x, point.y - start.y) <= Self.maximumTapMovement else { return }
        onTap()
    }

    // The carousel's pan claiming the touch lands here — a swipe must not accept.
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        touchStart = nil
    }
}
