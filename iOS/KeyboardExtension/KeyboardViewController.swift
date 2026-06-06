import JapaneseKeyboardCore
import JapaneseKeyboardUI
import KeyboardPreferences
import KeyboardKit
import SwiftUI
import UIKit

final class KeyboardViewController: KeyboardInputViewController {
    let inputManager = InputManager()
    private lazy var aiKeyboardController = AIKeyboardController(
        controller: self,
        inputManager: inputManager
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        configureJapaneseKeyboardBehavior()
        syncFullAccessStatus()
        inputManager.onMarkedTextDidChange = { [weak self] text in
            self?.applyMarkedText(text)
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            let adapter = KanaKanjiAdapter()
            await MainActor.run {
                self?.inputManager.setAdapter(adapter)
            }
        }
    }

    override func viewWillSetupKeyboardKit() {
        setupKeyboardKit(for: .bikeyJP) { [weak self] _ in
            guard let self else { return }
            self.services.actionHandler = JapaneseActionHandler(controller: self)
        }
        configureJapaneseKeyboardBehavior()
        syncFullAccessStatus()
    }

    override func viewWillSetupKeyboardView() {
        setupKeyboardView { controller in
            let manager = self.inputManager
            return QwertyKeyboardView(
                services: controller.services,
                keyboardContext: controller.state.keyboardContext,
                inputManager: manager,
                onSelectCandidate: { [weak self] candidate in
                    self?.commitCandidate(candidate)
                },
                toolbarContent: AnyView(
                    AIKeyboardToolbarView(
                        inputManager: manager,
                        aiController: self.aiKeyboardController,
                        onSelectCandidate: { [weak self] candidate in
                            self?.commitCandidate(candidate)
                        }
                    )
                ),
                overlayContent: AnyView(
                    AIResultOverlayView(aiController: self.aiKeyboardController)
                )
            )
        }
    }

    /// KeyboardKit's `super.viewWillAppear` runs `KeyboardContext.sync(with:)`,
    /// which re-reads the host proxy's autocapitalization type and resets
    /// `keyboardCase` (chat fields report `.sentences`, so the sync flips us
    /// to `.uppercased` on first entry — that's why shift appeared highlighted
    /// the moment the keyboard opened). Re-applying our overrides after super
    /// runs is what makes the first render lowercase.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureJapaneseKeyboardBehavior()
        aiKeyboardController.refreshPrompts()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        configureJapaneseKeyboardBehavior()
        syncFullAccessStatus()
        aiKeyboardController.documentDidChange()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        configureJapaneseKeyboardBehavior()
        syncFullAccessStatus()
        aiKeyboardController.documentDidChange()
    }

    @MainActor
    func handleRomajiInput(_ character: Character) {
        inputManager.appendRomaji(character)
    }

    @MainActor
    @discardableResult
    func handleBackspace() -> Bool {
        guard inputManager.isComposing else { return false }
        inputManager.backspace()
        return true
    }

    /// 次候補: cycle to the next candidate. Does not insert a space — space
    /// during composition is consumed entirely by the cycle action, matching
    /// native Japanese IME behavior.
    @MainActor
    func cycleCandidate() {
        guard inputManager.isComposing else { return }
        inputManager.selectNextCandidate()
    }

    @MainActor
    func commitCandidate(_ candidate: Candidate) {
        guard inputManager.isComposing else { return }
        finalizeMarkedText(replacement: candidate.text)
        inputManager.reset()
    }

    /// 確定: commit the currently-displayed preview (selected candidate if the
    /// user cycled, otherwise the raw kana). Does NOT insert a newline; user
    /// presses return a second time (now non-composing) for that.
    @MainActor
    func commitComposingForReturn() {
        guard inputManager.isComposing else { return }
        finalizeMarkedText(replacement: inputManager.commitText)
        inputManager.reset()
    }

    @MainActor
    func flushBufferToHost() {
        guard inputManager.isComposing else { return }
        finalizeMarkedText(replacement: inputManager.commitText)
        inputManager.reset()
    }

    @MainActor
    private func applyMarkedText(_ text: String) {
        if text.isEmpty {
            textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
            textDocumentProxy.unmarkText()
        } else {
            let ns = text as NSString
            textDocumentProxy.setMarkedText(text, selectedRange: NSRange(location: ns.length, length: 0))
        }
    }

    @MainActor
    private func finalizeMarkedText(replacement: String) {
        textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
        textDocumentProxy.unmarkText()
        textDocumentProxy.insertText(replacement)
    }

    private func configureJapaneseKeyboardBehavior() {
        state.keyboardContext.autocapitalizationTypeOverride = .some(.none)
        state.keyboardContext.settings.isAutocapitalizationEnabled = false
        state.keyboardContext.keyboardCase = .lowercased
        state.keyboardContext.keyboardType = .alphabetic
    }

    private func syncFullAccessStatus() {
        KeyboardSettingsStore.writeLastKnownFullAccessEnabled(state.keyboardContext.hasFullAccess)
    }
}

private extension KeyboardApp {
    static var bikeyJP: KeyboardApp {
        .init(
            name: "AIキーボード",
            licenseKey: nil,
            appGroupId: "group.co.gastroduce-japan.bikey.japanese",
            locales: [Locale(identifier: "ja_JP")],
            autocomplete: .init(nextWordPredictionRequest: nil),
            deepLinks: nil,
            keyboardSettingsKeyPrefix: "BikeyJP"
        )
    }
}
