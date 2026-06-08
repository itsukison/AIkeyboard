import JapaneseKeyboardCore
import JapaneseKeyboardUI
import KeyboardPreferences
import KeyboardKit
import SwiftUI
import UIKit

final class KeyboardViewController: KeyboardInputViewController {
    let inputManager = InputManager()
    private var manualKeyboardCase: Keyboard.KeyboardCase?
    private var hapticsEnabled = KeyboardSettingsStore.readHapticsEnabled()
    private var lastSyncedFullAccessStatus: Bool?
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
                ),
                shouldForceLowercaseAlphabeticCharacters: { [weak self] in
                    self?.shouldForceLowercaseAlphabeticCharacters ?? false
                },
                manualKeyboardCase: { [weak self] in
                    self?.manualKeyboardCase
                }
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
        hapticsEnabled = KeyboardSettingsStore.readHapticsEnabled()
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
        resetOneShotShiftIfNeeded()
    }

    @MainActor
    func handleShift(_ gesture: Keyboard.Gesture) -> Bool {
        switch gesture {
        case .release:
            let next: Keyboard.KeyboardCase = manualKeyboardCase == nil ? .uppercased : .lowercased
            setManualKeyboardCase(next == .lowercased ? nil : next)
            return true
        case .doubleTap:
            setManualKeyboardCase(.capsLocked)
            return true
        default:
            return false
        }
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
        recordConversionSelection(input: candidate.reading, replacement: candidate.text)
        inputManager.reset()
    }

    /// 確定: commit the currently-displayed preview (selected candidate if the
    /// user cycled, otherwise the raw kana). Does NOT insert a newline; user
    /// presses return a second time (now non-composing) for that.
    @MainActor
    func commitComposingForReturn() {
        guard inputManager.isComposing else { return }
        let input = inputManager.currentConversionInput
        let replacement = inputManager.commitText
        finalizeMarkedText(replacement: replacement)
        recordConversionSelection(input: input, replacement: replacement)
        inputManager.reset()
    }

    @MainActor
    func flushBufferToHost() {
        guard inputManager.isComposing else { return }
        let input = inputManager.currentConversionInput
        let replacement = inputManager.commitText
        finalizeMarkedText(replacement: replacement)
        recordConversionSelection(input: input, replacement: replacement)
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

    private func recordConversionSelection(input: String, replacement: String) {
        ConversionPreferenceStore.recordSelection(
            scope: .japanese,
            input: input,
            candidate: replacement
        )
        inputManager.refreshConversionPreferenceEntries()
    }

    private func configureJapaneseKeyboardBehavior() {
        manualKeyboardCase = nil
        state.keyboardContext.autocapitalizationTypeOverride = .some(.none)
        state.keyboardContext.settings.isAutocapitalizationEnabled = false
        state.keyboardContext.keyboardCase = .lowercased
        state.keyboardContext.keyboardType = .alphabetic
        // iOS's "Settings → Sounds & Haptics → Keyboard Feedback → Haptic"
        // preference is private to UIKit and unreadable from a sandboxed
        // keyboard extension, so we can't mirror it directly. KeyboardKit
        // otherwise fires a haptic on every gesture by default; mirror Apple's
        // native default (haptic OFF) and let the user opt in via our setting.
        state.feedbackContext.hapticConfiguration = hapticsEnabled ? .standard : .disabled
    }

    private var shouldForceLowercaseAlphabeticCharacters: Bool {
        state.keyboardContext.keyboardType == .alphabetic && manualKeyboardCase == nil
    }

    private func setManualKeyboardCase(_ keyboardCase: Keyboard.KeyboardCase?) {
        manualKeyboardCase = keyboardCase
        state.keyboardContext.keyboardCase = keyboardCase ?? .lowercased
    }

    private func resetOneShotShiftIfNeeded() {
        guard manualKeyboardCase == .uppercased else { return }
        setManualKeyboardCase(nil)
    }

    private func syncFullAccessStatus() {
        let hasFullAccess = state.keyboardContext.hasFullAccess
        guard lastSyncedFullAccessStatus != hasFullAccess else { return }
        lastSyncedFullAccessStatus = hasFullAccess
        KeyboardSettingsStore.writeLastKnownFullAccessEnabled(hasFullAccess)
    }
}

private extension KeyboardApp {
    static var bikeyJP: KeyboardApp {
        .init(
            name: "敬語ボタン",
            licenseKey: nil,
            appGroupId: "group.com.core7.keigobutton",
            locales: [Locale(identifier: "ja_JP")],
            autocomplete: .init(nextWordPredictionRequest: nil),
            deepLinks: nil,
            keyboardSettingsKeyPrefix: "KeigoButton"
        )
    }
}
