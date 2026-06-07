import JapaneseKeyboardAI
import JapaneseKeyboardCore
import KeyboardPreferences
import KeyboardKit
import SwiftUI
import UIKit

@MainActor
final class AIKeyboardController: ObservableObject {
    static let settingsURL = URL(string: "aikeyboard://settings")!

    @Published private(set) var state: AIKeyboardState = .hidden
    @Published private(set) var mainPrompt: UserPrompt? = UserPromptStore.mainPrompt()
    @Published private(set) var subPrompts: [UserPrompt] = UserPromptStore.subPrompts()

    private weak var controller: KeyboardViewController?
    private let inputManager: InputManager
    private var rewriteTask: Task<Void, Never>?

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

    func close() {
        rewriteTask?.cancel()
        rewriteTask = nil
        state = .hidden
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
        fire(prompt: prompt, capture: capture, inputText: capture.targetText, refinement: nil, existing: candidates)
    }

    func refine(_ intent: RefinementIntent) {
        guard case .result(let prompt, let capture, let candidates, let selectedIndex) = state else { return }
        guard candidates.indices.contains(selectedIndex) else { return }
        let focused = candidates[selectedIndex].replacement
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
            state = .hidden
        } catch {
            state = .error(prompt: nil, message: "入力が変わりました。もう一度実行してください")
        }
    }

    func openSettings() {
        guard let controller else { return }
        let url = Self.settingsURL
        var responder: UIResponder? = controller
        let selector = sel_registerName("openURL:")
        while let current = responder {
            if current.responds(to: selector) {
                _ = current.perform(selector, with: url)
                state = .hidden
                return
            }
            responder = current.next
        }
        state = .error(prompt: nil, message: "設定を開けませんでした")
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
        existing: [RewriteCandidate]
    ) {
        rewriteTask?.cancel()

        guard let controller else { return }

        guard KeyboardSettingsStore.readCloudAIEnabled() else {
            state = .error(prompt: prompt, message: "Cloud AIを設定でオンにしてください")
            return
        }
        guard controller.state.keyboardContext.hasFullAccess else {
            state = .error(prompt: prompt, message: "フルアクセスを有効にしてください")
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
            return "AI rewrite failed."
        }
    }
}
