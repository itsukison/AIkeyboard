import JapaneseKeyboardCore
import JapaneseKeyboardUI
import KeyboardPreferences
import SwiftUI

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

    private static let keyboardSurfaceColor = Color(
        red: 0xD2 / 255,
        green: 0xD3 / 255,
        blue: 0xD8 / 255
    )

    private static let cardGapWidth: CGFloat = 12

    // Critical: `if let` (not `switch`) so the same `panel()` call site is
    // reused across `.generating ↔ .result`, preserving ScrollView identity
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
                existing: model.existing,
                showSkeletons: model.showSkeletons,
                focusedIndex: model.focusedIndex
            )
            .padding(.top, 8)

            refinementRow(disabled: model.showSkeletons)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Self.keyboardSurfaceColor)
        .padding(.top, KeyboardChromeMetrics.toolbarHeight)
    }

    private func cardsCarousel(existing: [RewriteCandidate], showSkeletons: Bool, focusedIndex: Int?) -> some View {
        // Fires once per refinement: keyed on the index of the first card in the
        // pending batch, so `.task(id:)` doesn't re-trigger on the result swap.
        let scrollKey: String = (showSkeletons && !existing.isEmpty)
            ? "batch-\(existing.count)"
            : "none"

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(existing.enumerated()), id: \.element.id) { index, candidate in
                        if index > 0 {
                            if index.isMultiple(of: 3) {
                                batchAnchor(index: index)
                            } else {
                                cardGap
                            }
                        }
                        CandidateCard(
                            text: candidate.replacement,
                            isSelected: index == focusedIndex
                        )
                        .onTapGesture {
                            if index == focusedIndex {
                                aiController.replaceFocusedCandidate()
                            } else {
                                aiController.selectCandidate(index: index)
                            }
                        }
                        .id(ScrollTarget.card(candidate.id))
                    }
                    if showSkeletons {
                        if !existing.isEmpty {
                            batchAnchor(index: existing.count)
                        }
                        ForEach(0..<3, id: \.self) { offset in
                            if offset > 0 {
                                cardGap
                            }
                            CandidateSkeletonCard()
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .task(id: scrollKey) {
                guard showSkeletons, !existing.isEmpty else { return }
                // Let layout settle so the new anchor exists before scrolling.
                try? await Task.sleep(nanoseconds: 80_000_000)
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    proxy.scrollTo(ScrollTarget.batchStart(existing.count), anchor: .leading)
                }
            }
        }
    }

    private var cardGap: some View {
        Color.clear.frame(width: Self.cardGapWidth, height: 1)
    }

    /// 12pt invisible spacer that doubles as scroll target. Scrolling to it
    /// with `.leading` anchor puts its left edge at x=0 of the visible region,
    /// so the next card begins at x=12 — giving the new batch a uniform 12pt
    /// left margin from the visible edge.
    private func batchAnchor(index: Int) -> some View {
        Color.clear
            .frame(width: Self.cardGapWidth, height: 1)
            .id(ScrollTarget.batchStart(index))
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

    private enum ScrollTarget: Hashable {
        case card(UUID)
        case batchStart(Int)
    }
}

private enum CandidateCardMetrics {
    static let size = CGSize(width: 296, height: 156)
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
                    .strokeBorder(isSelected ? KeyboardPalette.accent : Color.clear, lineWidth: 2.5)
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
