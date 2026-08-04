import JapaneseKeyboardAI
import JapaneseKeyboardCore
import JapaneseKeyboardUI
import KeyboardPreferences
import SwiftUI
import UIKit

struct AIKeyboardToolbarView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var inputManager: InputManager
    @ObservedObject var aiController: AIKeyboardController
    let onSelectCandidate: (Candidate) -> Void
    let onSelectPrediction: (Candidate) -> Void
    let onTriggerHaptic: () -> Void

    var body: some View {
        Group {
            if let isOverflow = mainBarMode {
                mainBar(isOverflow: isOverflow)
            } else {
                otherStatesBar
            }
        }
        .frame(height: KeyboardChromeMetrics.toolbarHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        case .generating(let prompt, _, _, _, _):
            commandResultBar(prompt: prompt, isGenerating: true)
        case .result(let prompt, _, _, _):
            commandResultBar(prompt: prompt, isGenerating: false)
        case .error:
            errorBar
        case .consentRequired:
            consentRequiredBar
        case .fullAccessRequired:
            fullAccessRequiredBar
        case .hidden, .overflow:
            EmptyView()
        }
    }

    /// Unified bar for `.hidden` and `.overflow`. Signed-out users get a single
    /// login CTA; signed-in users get the prompt / overflow controls.
    @ViewBuilder
    private func mainBar(isOverflow: Bool) -> some View {
        // Practice mode (onboarding) presents the real buttons before sign-in;
        // taps are answered locally, so no auth is needed yet.
        if !aiController.isSignedInForAI() && !aiController.isPracticeModeActive {
            signedOutBar
        } else {
            signedInMainBar(isOverflow: isOverflow)
        }
    }

    private var signedOutBar: some View {
        HStack(spacing: 0) {
            if aiController.updateAvailable {
                updatePill()

                Spacer()
                    .frame(width: 6)
            }

            pillLink(label: "ログイン", url: AIKeyboardController.loginURL)
            .accessibilityLabel("ログインまたは登録")

            Spacer()
                .frame(width: 8)

            Divider()
                .frame(height: KeyboardChromeMetrics.toolbarDividerHeight)
                .opacity(0.35)

            Spacer()
                .frame(width: 8)

            CandidateBar(
                inputManager: inputManager,
                horizontalPadding: 0,
                firstCandidateLeadingPadding: 7,
                onTriggerHaptic: onTriggerHaptic,
                onSelect: onSelectCandidate,
                onSelectPrediction: onSelectPrediction
            )
        }
        .padding(.horizontal, 6)
    }

    private func signedInMainBar(isOverflow: Bool) -> some View {
        HStack(spacing: 0) {
            if !isOverflow && aiController.updateAvailable {
                updatePill()
                    .transition(.move(edge: .leading).combined(with: .opacity))

                Spacer()
                    .frame(width: 6)
                    .transition(.opacity)
            }

            if !isOverflow && aiController.replyAvailable {
                replyPill()
                    .transition(.move(edge: .leading).combined(with: .opacity))

                Spacer()
                    .frame(width: 6)
                    .transition(.opacity)
            }

            if !isOverflow {
                pillButton(label: aiController.mainPrompt?.title ?? "AI", isSelected: false) {
                    aiController.runMain()
                }
                .accessibilityLabel(aiController.mainPrompt?.title ?? "AI")
                .opacity(aiController.canOpenAI() && aiController.mainPrompt != nil ? 1 : 0.35)
                .disabled(!aiController.canOpenAI() || aiController.mainPrompt == nil)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            if !aiController.subPrompts.isEmpty {
                if !isOverflow {
                    Spacer()
                        .frame(width: 6)
                        .transition(.opacity)
                }

                pillButton(label: "…", isSelected: isOverflow) {
                    aiController.toggleOverflow()
                }
                .accessibilityLabel(isOverflow ? "閉じる" : "その他")
            }

            if !isOverflow {
                Spacer()
                    .frame(width: 8)

                Divider()
                    .frame(height: KeyboardChromeMetrics.toolbarDividerHeight)
                    .opacity(0.35)

                Spacer()
                    .frame(width: 8)

                CandidateBar(
                    inputManager: inputManager,
                    horizontalPadding: 0,
                    firstCandidateLeadingPadding: 7,
                    onTriggerHaptic: onTriggerHaptic,
                    onSelect: onSelectCandidate,
                    onSelectPrediction: onSelectPrediction
                )
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

                pillLink(label: "設定", url: AIKeyboardController.settingsURL)
                .accessibilityLabel("設定")
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 6)
    }

    /// Context-appearing reply CTA (white pill, accent reply icon + 返信 label).
    /// Tapping reads the clipboard, which triggers the iOS paste prompt. A
    /// prompt-free `UIPasteControl` variant is deferred — see docs/ai-rewrite.md.
    private func replyPill() -> some View {
        Button {
            onTriggerHaptic()
            aiController.runReplyFromClipboard()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.system(size: 12, weight: .semibold))
                Text("返信")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(KeyboardPalette.accent)
            .padding(.horizontal, 11)
            .frame(height: KeyboardChromeMetrics.toolbarButtonHeight)
            .background(
                KeyboardPalette.pillBackground,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("コピーしたメッセージに返信")
    }

    /// Update nudge (accent download icon + アップデート label, same construction
    /// as `replyPill`). Opens the container, which forces the App Store check
    /// and presents its update modal; dismissal there hides this pill too.
    private func updatePill() -> some View {
        Link(destination: AIKeyboardController.updateURL) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 12, weight: .semibold))
                Text("アップデート")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(KeyboardPalette.accent)
            .padding(.horizontal, 11)
            .frame(height: KeyboardChromeMetrics.toolbarButtonHeight)
            .background(
                KeyboardPalette.pillBackground,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { onTriggerHaptic() })
        .accessibilityLabel("アプリの新しいバージョンがあります")
    }

    private func commandPill(prompt: UserPrompt) -> some View {
        Button {
            onTriggerHaptic()
            aiController.runFromOverflow(prompt)
        } label: {
            Text(prompt.title)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(KeyboardPalette.ink)
                .padding(.horizontal, 11)
                .frame(height: KeyboardChromeMetrics.toolbarButtonHeight)
                .background(
                    KeyboardPalette.pillBackground,
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

            closeButton(side: KeyboardChromeMetrics.toolbarHeight)
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

            closeButton(side: KeyboardChromeMetrics.toolbarButtonHeight)
        }
        .padding(.horizontal, 12)
    }

    /// Shown when the user taps an AI command before granting consent in the
    /// container app. No text is sent; we point them to the app to enable it.
    private var consentRequiredBar: some View {
        HStack(spacing: 8) {
            Text("プライバシーの確認が必要です")
                .font(.system(size: 13))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            pillLink(label: "プライバシーを確認", url: AIKeyboardController.consentURL)
            .accessibilityLabel("アプリでプライバシーを確認する")

            closeButton(side: KeyboardChromeMetrics.toolbarButtonHeight)
        }
        .padding(.horizontal, 12)
    }

    /// Shown when the user taps an AI command without Full Access enabled.
    /// Full Access is an iOS system setting; we point them to the app's settings
    /// screen, where the Full Access row links out to iOS Settings.
    private var fullAccessRequiredBar: some View {
        HStack(spacing: 8) {
            Text("フルアクセスをオンにすると使えます")
                .font(.system(size: 13))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            pillLink(label: "フルアクセスを開く", url: AIKeyboardController.fullAccessURL)
            .accessibilityLabel("アプリでフルアクセスを有効にする")

            closeButton(side: KeyboardChromeMetrics.toolbarButtonHeight)
        }
        .padding(.horizontal, 12)
    }

    private func pillButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            onTriggerHaptic()
            action()
        } label: {
            pillLabel(label, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    /// A pill that opens a container-app URL. The URL still goes through
    /// SwiftUI's supported openURL path, but the tap is detected from raw UIKit
    /// touches because SwiftUI controls can drop toolbar presses on iOS 26.
    private func pillLink(label: String, url: URL) -> some View {
        pillLabel(label, isSelected: false)
            .contentShape(Rectangle())
            .overlay {
                KeyboardToolbarTapSurface(label: "url-\(label)") {
                    onTriggerHaptic()
                    // Temporary diagnostics (same investigation as the candidate
                    // expander): separates "tap never fired" from "openURL was
                    // rejected" when reading a device log.
                    openURL(url) { accepted in
                        NSLog("%@", "🔗 [url-\(label)] openURL accepted=\(accepted)")
                    }
                }
            }
            .accessibilityAddTraits(.isButton)
    }

    /// The ✕ close control. Same raw-touch tap surface as `pillLink`: a SwiftUI
    /// Button here drops presses in the keyboard's hosted toolbar on iOS 26.
    private func closeButton(side: CGFloat) -> some View {
        Image(systemName: "xmark")
            .font(.system(size: 13, weight: .medium))
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .foregroundStyle(KeyboardPalette.ink)
            .overlay {
                KeyboardToolbarTapSurface(label: "close") {
                    onTriggerHaptic()
                    aiController.close()
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("閉じる")
    }

    private struct KeyboardToolbarTapSurface: UIViewRepresentable {
        let label: String
        let onTap: () -> Void

        func makeUIView(context: Context) -> KeyboardToolbarTapSurfaceView {
            KeyboardToolbarTapSurfaceView(label: label, onTap: onTap)
        }

        func updateUIView(_ view: KeyboardToolbarTapSurfaceView, context: Context) {
            view.onTap = onTap
        }
    }

    // Font weight + paddings + frame are identical across states so the
    // pill's geometry never changes. Selected state is conveyed by the
    // pale lavender fill plus a purple stroke (option A from design.md).
    private func pillLabel(_ label: String, isSelected: Bool) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(KeyboardPalette.ink)
            .padding(.horizontal, 12)
            .frame(height: KeyboardChromeMetrics.toolbarButtonHeight)
            .background(
                isSelected ? KeyboardPalette.accentSoft : KeyboardPalette.pillBackground,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? KeyboardPalette.accent : Color.clear, lineWidth: 1)
            )
    }
}

private final class KeyboardToolbarTapSurfaceView: UIView {
    var onTap: () -> Void
    private let label: String
    private var touchStart: CGPoint?
    private static let maximumTapMovement: CGFloat = 12

    init(label: String, onTap: @escaping () -> Void) {
        self.label = label
        self.onTap = onTap
        super.init(frame: .zero)
        // Not .clear — same hit-test hardening as CandidateTapSurfaceView.
        backgroundColor = UIColor.white.withAlphaComponent(0.01)
        isMultipleTouchEnabled = false
        accessibilityIdentifier = "KeyboardToolbarTapSurface.\(label)"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
        NSLog("%@", "🫳 [\(label)] toolbar tap fired")
        onTap()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        touchStart = nil
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
