import JapaneseKeyboardAI
import JapaneseKeyboardUI
import SwiftUI

struct AIResultOverlayView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var aiController: AIKeyboardController
    let onTriggerHaptic: () -> Void
    let onSelectionHaptic: () -> Void
    @State private var centeredIndex: Int = 0

    // Critical: `if let` (not `switch`) so the same `panel()` call site is
    // reused across `.generating ↔ .result`, preserving carousel identity
    // and scroll offset across the skeleton → real-card swap.
    var body: some View {
        if let help = aiController.recoveryNavigation.help {
            recoveryPanel(help)
        } else if let model = panelModel {
            panel(model: model)
        }
    }

    private func recoveryPanel(_ help: AIRecoveryHelp) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: KeyboardChromeMetrics.toolbarHeight).allowsHitTesting(false)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(help.reason == .openingRejected ? String(localized: "アプリを開けませんでした") : String(localized: "フルアクセスを許可"))
                        .font(.headline)
                    Text(manualInstructions(help.reason == .fullAccessDisabled ? .fullaccess : help.destination))
                    HStack {
                        if help.reason == .openingRejected {
                            Button("もう一度開く") {
                                aiController.openDestination(help.destination) { url, completion in
                                    openURL(url, completion: completion)
                                }
                            }
                        }
                        Spacer()
                        Button("閉じる") { aiController.close() }
                    }
                    .buttonStyle(.bordered)
                }
                .font(.subheadline)
                .foregroundStyle(KeyboardPalette.ink)
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KeyboardPalette.surface)
        }
    }

    private func manualInstructions(_ destination: AIRecoveryDestination) -> String {
        switch destination {
        case .fullaccess:
            return String(localized: "設定で「敬語ボタン」を検索 → キーボード →「フルアクセスを許可」をオン")
        case .login:
            return String(localized: "敬語ボタンを開く → 設定 → サインイン / アカウントを作成")
        case .consent:
            return String(localized: "敬語ボタンを開く → 設定 → 敬語ボタンについて → AI変換とプライバシー")
        case .settings:
            return String(localized: "敬語ボタンを開く → 設定")
        case .update:
            return String(localized: "App Storeで「敬語ボタン」を検索してアップデート")
        }
    }

    private var panelModel: PanelModel? {
        switch aiController.state {
        case .generating(_, _, let refinement, let existing, let pending):
            return PanelModel(
                existing: existing,
                showSkeletons: pending > 0,
                skeletonCount: pending,
                focusedIndex: nil,
                // Streamed candidates land in `existing`, so a fresh generation
                // only resets while nothing has arrived yet.
                resetToFirstCard: refinement == nil && existing.isEmpty
            )
        case .result(_, _, let candidates, let selectedIndex):
            return PanelModel(
                existing: candidates,
                showSkeletons: false,
                skeletonCount: 0,
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
            Spacer()
                .frame(height: KeyboardChromeMetrics.toolbarHeight)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                cardsCarousel(
                    candidates: model.existing,
                    showSkeletons: model.showSkeletons,
                    skeletonCount: model.skeletonCount,
                    focusedIndex: model.focusedIndex,
                    resetToFirstCard: model.resetToFirstCard
                )
                .padding(.top, 4)

                refinementRow(disabled: model.showSkeletons)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(KeyboardPalette.surface)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func cardsCarousel(
        candidates: [RewriteCandidate],
        showSkeletons: Bool,
        skeletonCount: Int,
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
            skeletonCount: skeletonCount,
            focusedIndex: focusedIndex,
            animatesProgrammaticScroll: !resetToFirstCard,
            onSelectionChanged: onSelectionHaptic,
            onTapCentered: {
                onTriggerHaptic()
                aiController.replaceFocusedCandidate()
            }
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
        // Reported even when it lands on a shimmer placeholder — mid-generation
        // the controller needs that position to keep the user where they
        // scrolled. The controller ignores out-of-range indices once results
        // are in, so no guard is needed here.
        .onChange(of: centeredIndex) { newCentered in
            aiController.selectCandidate(index: newCentered)
        }
    }

    private func refinementRow(disabled: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                RefinementChip(icon: "arrow.clockwise", label: "再作成") {
                    onTriggerHaptic()
                    aiController.regenerate()
                }
                ForEach(RefinementIntent.allCases, id: \.self) { intent in
                    RefinementChip(icon: intent.iconName, label: intent.title) {
                        onTriggerHaptic()
                        aiController.refine(intent)
                    }
                }
                if !aiController.isPracticeModeActive {
                    Menu {
                        Button("役に立った") { aiController.submitUsefulness("useful") }
                        Button("言い回しが不自然") { aiController.submitUsefulness("wording") }
                        Button("意味が変わった") { aiController.submitUsefulness("meaning") }
                        Button("待ち時間が長い") { aiController.submitUsefulness("latency") }
                        Button("置き換えがうまくいかない") { aiController.submitUsefulness("replacement") }
                    } label: {
                        Label("感想を送る", systemImage: "bubble.left")
                            .font(.system(size: 13))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(KeyboardPalette.surface, in: Capsule())
                    }
                    .accessibilityLabel("この候補の感想を送る")
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
        let skeletonCount: Int
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
                KeyboardPalette.prominentPillBackground,
                in: Capsule()
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}
