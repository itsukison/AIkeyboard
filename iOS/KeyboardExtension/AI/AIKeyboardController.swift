import JapaneseKeyboardAI
import JapaneseKeyboardCore
import KeyboardPreferences
import KeyboardKit
import SwiftUI
import UIKit

@MainActor
final class AIKeyboardController: ObservableObject {
    static let settingsURL = URL(string: "keigobutton://settings")!
    static let loginURL = URL(string: "keigobutton://login")!
    static let fullAccessURL = URL(string: "keigobutton://fullaccess")!
    static let consentURL = URL(string: "keigobutton://consent")!

    @Published private(set) var state: AIKeyboardState = .hidden
    @Published private(set) var mainPrompt: UserPrompt? = UserPromptStore.mainPrompt()
    @Published private(set) var subPrompts: [UserPrompt] = UserPromptStore.subPrompts()
    /// True when the clipboard holds a freshly copied message the user can reply
    /// to. Detected from pasteboard metadata only (no content read, no banner).
    @Published private(set) var replyAvailable: Bool = false

    private weak var controller: KeyboardViewController?
    private let inputManager: InputManager
    private var rewriteTask: Task<Void, Never>?
    /// The copied message for the active reply session. Set on `runReply`, reused
    /// by `regenerate`, cleared by `runFresh` and `close`.
    private var replyContext: String?
    /// Polls the pasteboard while the keyboard is visible. iOS delivers no
    /// notification when another app copies, so a freshly copied message would
    /// otherwise not surface the 返信 pill until the next text/selection change.
    private var clipboardMonitor: Timer?

    init(controller: KeyboardViewController, inputManager: InputManager) {
        self.controller = controller
        self.inputManager = inputManager
    }

    var isActive: Bool {
        if case .hidden = state { return false }
        return true
    }

    func refreshPrompts() {
        mainPrompt = UserPromptStore.mainPrompt()
        subPrompts = UserPromptStore.subPrompts()
    }

    func canOpenAI() -> Bool {
        guard !inputManager.isComposing else { return true }
        guard let controller else { return false }
        return (try? InputCapture.capture(from: controller.textDocumentProxy.ai)) != nil
    }

    func isSignedInForAI() -> Bool {
        AIAuthStore.readAccessToken() != nil
    }

    func close() {
        rewriteTask?.cancel()
        rewriteTask = nil
        replyContext = nil
        state = .hidden
    }

    /// Re-evaluates the reply pill on keyboard appearance: a fresh copy since the
    /// last appearance shows the pill, a stale clipboard hides it. Also starts
    /// polling so a copy made while the keyboard stays open surfaces the pill.
    func refreshReplyAvailabilityOnAppear() {
        replyAvailable = false
        promoteReplyIfFreshCopy()
        startClipboardMonitoring()
    }

    private func startClipboardMonitoring() {
        clipboardMonitor?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.promoteReplyIfFreshCopy() }
        }
        timer.tolerance = 0.2
        clipboardMonitor = timer
    }

    func stopClipboardMonitoring() {
        clipboardMonitor?.invalidate()
        clipboardMonitor = nil
    }

    /// Promotes the reply pill if something new was copied while the keyboard is
    /// already visible. Never hides an already-shown pill within a session.
    func refreshReplyAvailability() {
        promoteReplyIfFreshCopy()
    }

    /// Detects a freshly copied message using pasteboard metadata only
    /// (`changeCount` / `hasStrings`) — no content access, so iOS shows no paste
    /// banner. Updates `replyAvailable` only when the clipboard changed since we
    /// last looked.
    private func promoteReplyIfFreshCopy() {
        let pasteboard = UIPasteboard.general
        let current = pasteboard.changeCount
        guard current != KeyboardSettingsStore.readLastSeenPasteboardChangeCount() else { return }
        KeyboardSettingsStore.writeLastSeenPasteboardChangeCount(current)
        replyAvailable = pasteboard.hasStrings
    }

    /// Called with the message text delivered by the system paste control (a
    /// `UIPasteControl` tap grants clipboard access with no permission prompt).
    func runReply(withCopiedText text: String) {
        guard let controller else { return }
        let copied = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copied.isEmpty else {
            state = .error(prompt: UserPromptDefaults.replyPrompt(), message: "返信元のメッセージをコピーしてください")
            return
        }

        if inputManager.isComposing {
            controller.flushBufferToHost()
        }

        let capture: WholeInputCapture
        do {
            capture = try InputCapture.captureForReply(from: controller.textDocumentProxy.ai)
        } catch WholeInputCaptureError.tooLong {
            state = .error(prompt: UserPromptDefaults.replyPrompt(), message: "入力が長すぎます")
            return
        } catch {
            state = .error(prompt: UserPromptDefaults.replyPrompt(), message: "返信を作成できませんでした")
            return
        }

        replyContext = copied
        fire(
            prompt: UserPromptDefaults.replyPrompt(),
            capture: capture,
            inputText: capture.targetText,
            refinement: nil,
            existing: [],
            replyTo: copied
        )
    }

    func toggleOverflow() {
        withAnimation(.easeInOut(duration: 0.28)) {
            if case .overflow = state {
                state = .hidden
            } else {
                state = .overflow
            }
        }
    }

    func runMain() {
        guard let prompt = mainPrompt else {
            state = .error(prompt: nil, message: "プロンプトが設定されていません")
            return
        }
        runFresh(prompt: prompt)
    }

    func runFromOverflow(_ prompt: UserPrompt) {
        runFresh(prompt: prompt)
    }

    func selectCandidate(index: Int) {
        guard case .result(let prompt, let capture, let candidates, _) = state else { return }
        guard candidates.indices.contains(index) else { return }
        state = .result(prompt: prompt, capture: capture, candidates: candidates, selectedIndex: index)
    }

    func selectCandidate(id: UUID) {
        guard case .result(_, _, let candidates, _) = state else { return }
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        selectCandidate(index: index)
    }

    func regenerate() {
        guard case .result(let prompt, let capture, let candidates, _) = state else { return }
        fire(prompt: prompt, capture: capture, inputText: capture.targetText, refinement: nil, existing: candidates, replyTo: replyContext)
    }

    func refine(_ intent: RefinementIntent) {
        guard case .result(let prompt, let capture, let candidates, let selectedIndex) = state else { return }
        guard candidates.indices.contains(selectedIndex) else { return }
        let focused = candidates[selectedIndex].replacement
        // Refinement operates on the chosen candidate as a plain rewrite, so it
        // does not re-reply (no `replyTo`).
        fire(prompt: prompt, capture: capture, inputText: focused, refinement: intent, existing: candidates)
    }

    func replaceFocusedCandidate() {
        guard let controller else { return }
        guard case .result(_, let capture, let candidates, let selectedIndex) = state else { return }
        guard candidates.indices.contains(selectedIndex) else { return }
        let replacement = candidates[selectedIndex].replacement
        do {
            inputManager.reset()
            try WholeInputReplacementEngine.replace(
                capture: capture,
                with: replacement,
                proxy: controller.textDocumentProxy.ai
            )
            KeyboardUsageStatsStore.recordAcceptedRewrite()
            state = .hidden
        } catch {
            state = .error(prompt: nil, message: "入力が変わりました。もう一度実行してください")
        }
    }

    func documentDidChange() {
        guard let controller else { return }
        let current = String(describing: controller.textDocumentProxy.documentIdentifier)
        switch state {
        case .generating(_, let capture, _, _), .result(_, let capture, _, _):
            if capture.documentIdentifierString != current {
                close()
            }
        default:
            break
        }
    }

    private func runFresh(prompt: UserPrompt) {
        guard let controller else { return }
        replyContext = nil
        if inputManager.isComposing {
            controller.flushBufferToHost()
        }

        let capture: WholeInputCapture
        do {
            capture = try InputCapture.capture(from: controller.textDocumentProxy.ai)
        } catch WholeInputCaptureError.tooLong {
            state = .error(prompt: prompt, message: "入力が長すぎます")
            return
        } catch {
            state = .error(prompt: prompt, message: "入力してからAIを使えます")
            return
        }
        fire(prompt: prompt, capture: capture, inputText: capture.targetText, refinement: nil, existing: [])
    }

    private func fire(
        prompt: UserPrompt,
        capture: WholeInputCapture,
        inputText: String,
        refinement: RefinementIntent?,
        existing: [RewriteCandidate],
        replyTo: String? = nil
    ) {
        rewriteTask?.cancel()

        guard let controller else { return }

        guard KeyboardSettingsStore.readAIConsentGranted() else {
            state = .consentRequired(prompt: prompt)
            return
        }
        guard KeyboardSettingsStore.readCloudAIEnabled() else {
            state = .error(prompt: prompt, message: "Cloud AIを設定でオンにしてください")
            return
        }
        guard controller.state.keyboardContext.hasFullAccess else {
            state = .fullAccessRequired(prompt: prompt)
            return
        }
        guard AIAuthStore.readAccessToken() != nil else {
            state = .error(prompt: prompt, message: "アプリでサインインしてください")
            return
        }

        let configuration = CloudRewriteConfiguration(appVersion: Self.appVersion)
        let request = RewriteRequest(
            prompt: prompt.prompt,
            text: inputText,
            replyTo: replyTo,
            commandKey: prompt.builtinKey,
            title: prompt.title,
            locale: Self.locale(for: prompt),
            appVersion: configuration.appVersion,
            candidateCount: 3,
            refinement: refinement
        )
        let service = CloudRewriteService(configuration: configuration)
        state = .generating(prompt: prompt, capture: capture, refinement: refinement, existing: existing)

        rewriteTask = Task { [weak self] in
            do {
                let result = try await service.rewrite(request)
                guard !Task.isCancelled else { return }
                let newCandidates = result.candidates.isEmpty
                    ? [RewriteCandidate(replacement: inputText, changed: false)]
                    : result.candidates
                await MainActor.run {
                    let combined = existing + newCandidates
                    self?.state = .result(
                        prompt: prompt,
                        capture: capture,
                        candidates: combined,
                        selectedIndex: existing.count
                    )
                    self?.rewriteTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.state = .error(prompt: prompt, message: Self.message(for: error))
                    self?.rewriteTask = nil
                }
            }
        }
    }

    private static let appVersion: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    private static func locale(for prompt: UserPrompt) -> String {
        switch prompt.builtinKey {
        case UserPromptDefaults.translateToEnglishKey: return "en-US"
        default: return "ja-JP"
        }
    }

    private static func message(for error: Error) -> String {
        switch error {
        case CloudRewriteError.notSignedIn:
            return "アプリでサインインしてください"
        case CloudRewriteError.backend(let message):
            return message
        default:
            return "通信に失敗しました。電波の良い場所で、もう一度お試しください。"
        }
    }
}
