import JapaneseKeyboardAI
import JapaneseKeyboardCore
import JapaneseKeyboardUI
import KeyboardPreferences
import SwiftUI
import UIKit

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
