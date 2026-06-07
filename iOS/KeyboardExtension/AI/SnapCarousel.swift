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
    let focusedIndex: Int?
    let onTapCentered: () -> Void

    private var totalCount: Int {
        candidates.count + (showSkeletons ? 3 : 0)
    }

    func makeUIView(context: Context) -> SnapCarouselView {
        let view = SnapCarouselView()
        view.scrollView.delegate = context.coordinator
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: SnapCarouselView, context: Context) {
        context.coordinator.indexBinding = $centeredIndex

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
                    .onTapGesture {
                        guard isCentered else { return }
                        onTap()
                    }
                    .allowsHitTesting(isCentered)
                }
                if showSkeletons {
                    ForEach(0..<3, id: \.self) { _ in
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
                view.scroll(toIndex: centered, animated: true) { [weak coord] _ in
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
        var isProgrammaticallyScrolling = false
        private let haptic = UISelectionFeedbackGenerator()

        override init() {
            super.init()
            haptic.prepare()
        }

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
            haptic.selectionChanged()
            haptic.prepare()
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
