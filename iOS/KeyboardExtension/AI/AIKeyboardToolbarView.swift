import JapaneseKeyboardAI
import JapaneseKeyboardCore
import JapaneseKeyboardUI
import KeyboardPreferences
import SwiftUI
import UIKit

/// Color tokens mirroring the container app's Bikey Design System
/// (see `keyboard/design.md` and `iOS/Container/Design/AppColor.swift`).
/// Defined locally because `AppColor` is in the container target and not
/// reachable from the keyboard extension.
private enum KeyboardPalette {
    /// Brand purple — used for selection strokes and focused card borders.
    static let accent = Color(red: 0.341, green: 0.258, blue: 0.656)
    /// Pale lavender fill for selected pills — reads as "selection state" without
    /// the visual weight of a saturated CTA, per design.md.
    static let accentSoft = Color(red: 0.950, green: 0.937, blue: 0.986)
    /// Warm near-black for primary text on light surfaces.
    static let ink = Color(red: 0.129, green: 0.129, blue: 0.155)
}

struct AIKeyboardToolbarView: View {
    @ObservedObject var inputManager: InputManager
    @ObservedObject var aiController: AIKeyboardController
    let onSelectCandidate: (Candidate) -> Void

    var body: some View {
        Group {
            if let isOverflow = mainBarMode {
                mainBar(isOverflow: isOverflow)
            } else {
                otherStatesBar
            }
        }
        .frame(height: KeyboardChromeMetrics.toolbarHeight)
        .clipped()
    }

    private var mainBarMode: Bool? {
        switch aiController.state {
        case .hidden: return false
        case .overflow: return true
        default: return nil
        }
    }

    @ViewBuilder
    private var otherStatesBar: some View {
        switch aiController.state {
        case .generating(let prompt, _, _, _):
            commandResultBar(prompt: prompt, isGenerating: true)
        case .result(let prompt, _, _, _):
            commandResultBar(prompt: prompt, isGenerating: false)
        case .error:
            errorBar
        case .hidden, .overflow:
            EmptyView()
        }
    }

    /// Unified bar for `.hidden` and `.overflow`. The `…` pill is unconditional
    /// so SwiftUI preserves its identity across the toggle; its position shifts
    /// implicitly when sibling conditional children appear/disappear inside the
    /// `withAnimation` block in `AIKeyboardController.toggleOverflow()`.
    private func mainBar(isOverflow: Bool) -> some View {
        HStack(spacing: 0) {
            if !isOverflow {
                pillButton(label: aiController.mainPrompt?.title ?? "AI", isSelected: false) {
                    aiController.runMain()
                }
                .accessibilityLabel(aiController.mainPrompt?.title ?? "AI")
                .opacity(aiController.canOpenAI() && aiController.mainPrompt != nil ? 1 : 0.35)
                .disabled(!aiController.canOpenAI() || aiController.mainPrompt == nil)
                .transition(.move(edge: .leading).combined(with: .opacity))

                Spacer()
                    .frame(width: 6)
                    .transition(.opacity)
            }

            pillButton(label: "…", isSelected: isOverflow) {
                aiController.toggleOverflow()
            }
            .accessibilityLabel(isOverflow ? "閉じる" : "その他")

            if !isOverflow {
                Spacer()
                    .frame(width: 3)
                    .transition(.opacity)

                Divider()
                    .frame(height: KeyboardChromeMetrics.toolbarDividerHeight)
                    .opacity(0.35)
                    .transition(.opacity)

                Spacer()
                    .frame(width: 3)
                    .transition(.opacity)

                CandidateBar(
                    inputManager: inputManager,
                    horizontalPadding: 0,
                    firstCandidateLeadingPadding: 7,
                    onSelect: onSelectCandidate
                )
                .transition(.opacity)
            } else {
                Spacer()
                    .frame(width: 6)
                    .transition(.opacity)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(aiController.subPrompts) { prompt in
                            commandPill(prompt: prompt)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.move(edge: .trailing).combined(with: .opacity))

                pillButton(label: "設定", isSelected: false) {
                    aiController.openSettings()
                }
                .accessibilityLabel("設定")
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 6)
    }

    private func commandPill(prompt: UserPrompt) -> some View {
        Button {
            aiController.runFromOverflow(prompt)
        } label: {
            Text(prompt.title)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(KeyboardPalette.ink)
                .padding(.horizontal, 11)
                .frame(height: KeyboardChromeMetrics.toolbarButtonHeight)
                .background(
                    Color.white.opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(prompt.title)
    }

    private func commandResultBar(prompt: UserPrompt, isGenerating: Bool) -> some View {
        HStack(spacing: 6) {
            // Same font weight + padding as `pillButton` so the pill keeps the
            // exact same width when transitioning from `mainBar` to here.
            Text(prompt.title)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(KeyboardPalette.ink)
                .padding(.horizontal, 12)
                .frame(height: KeyboardChromeMetrics.toolbarButtonHeight)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(KeyboardPalette.accentSoft)
                        if isGenerating {
                            PillShimmer()
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(KeyboardPalette.accent, lineWidth: 1)
                )
                .accessibilityLabel(prompt.title)

            Spacer(minLength: 8)

            Button {
                aiController.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: KeyboardChromeMetrics.toolbarButtonHeight, height: KeyboardChromeMetrics.toolbarButtonHeight)
                    .foregroundStyle(KeyboardPalette.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
        }
        .padding(.horizontal, 6)
    }

    private var errorBar: some View {
        HStack(spacing: 8) {
            if case .error(_, let message) = aiController.state {
                Text(message)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button {
                aiController.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: KeyboardChromeMetrics.toolbarButtonHeight, height: KeyboardChromeMetrics.toolbarButtonHeight)
                    .foregroundStyle(KeyboardPalette.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
        }
        .padding(.horizontal, 12)
    }

    private func pillButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        // Font weight + paddings + frame are identical across states so the
        // pill's geometry never changes. Selected state is conveyed by the
        // pale lavender fill plus a purple stroke (option A from design.md).
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KeyboardPalette.ink)
                .padding(.horizontal, 12)
                .frame(height: KeyboardChromeMetrics.toolbarButtonHeight)
                .background(
                    isSelected ? KeyboardPalette.accentSoft : Color.white.opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? KeyboardPalette.accent : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct AIResultOverlayView: View {
    @ObservedObject var aiController: AIKeyboardController
    @State private var centeredIndex: Int = 0

    private static let keyboardSurfaceColor = Color(
        red: 0xD2 / 255,
        green: 0xD3 / 255,
        blue: 0xD8 / 255
    )

    // Critical: `if let` (not `switch`) so the same `panel()` call site is
    // reused across `.generating ↔ .result`, preserving carousel identity
    // and scroll offset across the skeleton → real-card swap.
    var body: some View {
        if let model = panelModel {
            panel(model: model)
        }
    }

    private var panelModel: PanelModel? {
        switch aiController.state {
        case .generating(_, _, _, let existing):
            return PanelModel(existing: existing, showSkeletons: true, focusedIndex: nil)
        case .result(_, _, let candidates, let selectedIndex):
            return PanelModel(existing: candidates, showSkeletons: false, focusedIndex: selectedIndex)
        default:
            return nil
        }
    }

    @ViewBuilder
    private func panel(model: PanelModel) -> some View {
        VStack(spacing: 0) {
            cardsCarousel(
                candidates: model.existing,
                showSkeletons: model.showSkeletons,
                focusedIndex: model.focusedIndex
            )
            .padding(.top, 4)

            refinementRow(disabled: model.showSkeletons)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Self.keyboardSurfaceColor)
        .padding(.top, KeyboardChromeMetrics.toolbarHeight)
    }

    private func cardsCarousel(candidates: [RewriteCandidate], showSkeletons: Bool, focusedIndex: Int?) -> some View {
        SnapCarousel(
            centeredIndex: $centeredIndex,
            candidates: candidates,
            showSkeletons: showSkeletons,
            focusedIndex: focusedIndex,
            onTapCentered: { aiController.replaceFocusedCandidate() }
        )
        .frame(height: CandidateCardMetrics.size.height)
        .onChange(of: focusedIndex) { newFocused in
            guard let newFocused, candidates.indices.contains(newFocused), centeredIndex != newFocused else { return }
            centeredIndex = newFocused
        }
        // When a refinement batch begins (skeletons appended to the end of the
        // existing cards), jump focus to the first skeleton so the carousel
        // auto-scrolls there. Mirrors the pre-snap `proxy.scrollTo(_, .leading)`
        // behavior, just snap-style.
        .onChange(of: showSkeletons) { isShowing in
            guard isShowing, !candidates.isEmpty else { return }
            centeredIndex = candidates.count
        }
        .onChange(of: centeredIndex) { newCentered in
            guard candidates.indices.contains(newCentered) else { return }
            aiController.selectCandidate(index: newCentered)
        }
    }

    private func refinementRow(disabled: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                RefinementChip(icon: "arrow.clockwise", label: "再作成") {
                    aiController.regenerate()
                }
                ForEach(RefinementIntent.allCases, id: \.self) { intent in
                    RefinementChip(icon: intent.iconName, label: intent.title) {
                        aiController.refine(intent)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private struct PanelModel {
        let existing: [RewriteCandidate]
        let showSkeletons: Bool
        let focusedIndex: Int?
    }
}

/// Horizontal center-snap carousel for candidate cards. Built on `UIScrollView`
/// (via `UIViewRepresentable`) rather than SwiftUI's `scrollTargetBehavior` so
/// the snap experience is identical on iOS 16 and iOS 17+. Cards are rendered
/// as a single hosted SwiftUI `HStack` to keep the visual layer in SwiftUI.
private struct SnapCarousel: UIViewRepresentable {
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

private enum CandidateCardMetrics {
    static let size = CGSize(width: 330, height: 156)
    static let cornerRadius: CGFloat = 18
}

private struct CandidateCard: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundStyle(KeyboardPalette.ink)
            .lineLimit(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: CandidateCardMetrics.size.width, height: CandidateCardMetrics.size.height, alignment: .topLeading)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: CandidateCardMetrics.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CandidateCardMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? KeyboardPalette.accent.opacity(0.7) : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: CandidateCardMetrics.cornerRadius, style: .continuous))
    }
}

private struct CandidateSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShimmerSkeleton(shape: Capsule()).frame(height: 12)
            ShimmerSkeleton(shape: Capsule()).frame(height: 12)
            ShimmerSkeleton(shape: Capsule()).frame(width: 200, height: 12)
            ShimmerSkeleton(shape: Capsule()).frame(width: 120, height: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(width: CandidateCardMetrics.size.width, height: CandidateCardMetrics.size.height, alignment: .topLeading)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: CandidateCardMetrics.cornerRadius, style: .continuous)
        )
    }
}

/// Overlay-only shimmer for the active command pill. Renders a moving soft
/// purple band over the pill's pale-lavender background, conveying "loading"
/// without changing the pill's width.
private struct PillShimmer: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                stops: [
                    .init(color: KeyboardPalette.accent.opacity(0.0), location: 0.0),
                    .init(color: KeyboardPalette.accent.opacity(0.22), location: 0.5),
                    .init(color: KeyboardPalette.accent.opacity(0.0), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.55)
            .offset(x: phase * width)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 1.6
            }
        }
    }
}

private struct ShimmerSkeleton<S: Shape>: View {
    let shape: S
    @State private var phase: CGFloat = -1

    var body: some View {
        shape
            .fill(Color(uiColor: .systemGray5))
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.0), location: 0.0),
                            .init(color: .white.opacity(0.65), location: 0.5),
                            .init(color: .white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.6)
                    .offset(x: phase * width)
                    .blendMode(.plusLighter)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
    }
}

private struct RefinementChip: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                Text(label)
                    .font(.system(size: 14, weight: .regular))
            }
            .foregroundStyle(KeyboardPalette.ink)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                Color.white.opacity(0.92),
                in: Capsule()
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}
