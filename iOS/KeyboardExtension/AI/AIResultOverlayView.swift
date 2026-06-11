import JapaneseKeyboardAI
import JapaneseKeyboardUI
import SwiftUI

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
        case .generating(_, _, let refinement, let existing):
            return PanelModel(
                existing: existing,
                showSkeletons: true,
                focusedIndex: nil,
                resetToFirstCard: refinement == nil && existing.isEmpty
            )
        case .result(_, _, let candidates, let selectedIndex):
            return PanelModel(
                existing: candidates,
                showSkeletons: false,
                focusedIndex: selectedIndex,
                resetToFirstCard: false
            )
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
                focusedIndex: model.focusedIndex,
                resetToFirstCard: model.resetToFirstCard
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

    private func cardsCarousel(
        candidates: [RewriteCandidate],
        showSkeletons: Bool,
        focusedIndex: Int?,
        resetToFirstCard: Bool
    ) -> some View {
        let carouselIndex = Binding<Int>(
            get: { resetToFirstCard ? 0 : centeredIndex },
            set: { centeredIndex = resetToFirstCard ? 0 : $0 }
        )

        return SnapCarousel(
            centeredIndex: carouselIndex,
            candidates: candidates,
            showSkeletons: showSkeletons,
            focusedIndex: focusedIndex,
            animatesProgrammaticScroll: !resetToFirstCard,
            onTapCentered: { aiController.replaceFocusedCandidate() }
        )
        .frame(height: CandidateCardMetrics.size.height)
        .onAppear {
            guard resetToFirstCard else { return }
            centeredIndex = 0
        }
        .onChange(of: resetToFirstCard) { shouldReset in
            guard shouldReset else { return }
            centeredIndex = 0
        }
        .onChange(of: focusedIndex) { newFocused in
            guard let newFocused, candidates.indices.contains(newFocused), centeredIndex != newFocused else { return }
            centeredIndex = newFocused
        }
        // Fresh generations start from the first skeleton; refinement batches
        // append skeletons to the end so users can compare with existing cards.
        .onChange(of: showSkeletons) { isShowing in
            guard isShowing else { return }
            centeredIndex = resetToFirstCard ? 0 : candidates.count
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
        let resetToFirstCard: Bool
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
