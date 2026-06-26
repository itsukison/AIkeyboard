import JapaneseKeyboardCore
import JapaneseKeyboardUI
import KeyboardPreferences
import KeyboardKit
import SwiftUI
import UIKit

final class KeyboardViewController: KeyboardInputViewController {
    private var keyboardStyle: KeyboardPreferences.KeyboardStyle = KeyboardSettingsStore.readKeyboardStyle()
    var inputManager: InputManager = InputManager()
    private let keyboardHaptics = KeyboardHapticFeedback()
    private var manualKeyboardCase: Keyboard.KeyboardCase?
    private var hapticsEnabled = KeyboardSettingsStore.readHapticsEnabled()
    private var lastSyncedFullAccessStatus: Bool?
    private lazy var aiKeyboardController = AIKeyboardController(
        controller: self,
        inputManager: inputManager
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        configureInputManager(force: true)
        configureJapaneseKeyboardBehavior()
        syncFullAccessStatus()
    }

    private func configureInputManager(force: Bool = false) {
        let style = KeyboardSettingsStore.readKeyboardStyle()
        guard force || style != keyboardStyle else { return }
        keyboardStyle = style
        let buffer: any InputBuffer
        switch style {
        case .japaneseFlick:
            buffer = KanaInputBuffer()
        default:
            buffer = RomajiInputBuffer()
        }
        inputManager = InputManager(buffer: buffer)
        inputManager.onMarkedTextDidChange = { [weak self] text in
            self?.applyMarkedText(text)
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            let adapter = KanaKanjiAdapter()
            await adapter.prewarm()
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
            switch self.keyboardStyle {
            case .japaneseFlick:
                return AnyView(
                    FlickKeyboardView(
                        inputManager: manager,
                        onSelectCandidate: { [weak self] candidate in
                            self?.commitCandidate(candidate)
                        },
                        onSelectPrediction: { [weak self] candidate in
                            self?.commitPrediction(candidate)
                        },
                        onTriggerHaptic: { [weak self] in
                            self?.triggerKeyHaptic()
                        },
                        onBackspace: { [weak self] in
                            self?.handleBackspace()
                        },
                        onSpace: { [weak self] in
                            self?.cycleCandidate()
                        },
                        onReturn: { [weak self] in
                            self?.handleReturn()
                        },
                        onSwitchToRomaji: { [weak self] in
                            self?.switchKeyboardStyle(.japaneseRomaji)
                        },
                        toolbarContent: AnyView(
                            AIKeyboardToolbarView(
                                inputManager: manager,
                                aiController: self.aiKeyboardController,
                                onSelectCandidate: { [weak self] candidate in
                                    self?.commitCandidate(candidate)
                                },
                                onSelectPrediction: { [weak self] candidate in
                                    self?.commitPrediction(candidate)
                                },
                                onTriggerHaptic: { [weak self] in
                                    self?.triggerKeyHaptic()
                                }
                            )
                        ),
                        overlayContent: AnyView(
                            AIResultOverlayView(
                                aiController: self.aiKeyboardController,
                                onTriggerHaptic: { [weak self] in
                                    self?.triggerKeyHaptic()
                                },
                                onSelectionHaptic: { [weak self] in
                                    self?.triggerSelectionHaptic()
                                }
                            )
                        )
                    )
                )
            default:
                return AnyView(
                    QwertyKeyboardView(
                        services: controller.services,
                        keyboardContext: controller.state.keyboardContext,
                        inputManager: manager,
                        onSelectCandidate: { [weak self] candidate in
                            self?.commitCandidate(candidate)
                        },
                        onTriggerHaptic: { [weak self] in
                            self?.triggerKeyHaptic()
                        },
                        toolbarContent: AnyView(
                            AIKeyboardToolbarView(
                                inputManager: manager,
                                aiController: self.aiKeyboardController,
                                onSelectCandidate: { [weak self] candidate in
                                    self?.commitCandidate(candidate)
                                },
                                onSelectPrediction: { [weak self] candidate in
                                    self?.commitPrediction(candidate)
                                },
                                onTriggerHaptic: { [weak self] in
                                    self?.triggerKeyHaptic()
                                }
                            )
                        ),
                        overlayContent: AnyView(
                            AIResultOverlayView(
                                aiController: self.aiKeyboardController,
                                onTriggerHaptic: { [weak self] in
                                    self?.triggerKeyHaptic()
                                },
                                onSelectionHaptic: { [weak self] in
                                    self?.triggerSelectionHaptic()
                                }
                            )
                        ),
                        shouldForceLowercaseAlphabeticCharacters: { [weak self] in
                            self?.shouldForceLowercaseAlphabeticCharacters ?? false
                        },
                        manualKeyboardCase: { [weak self] in
                            self?.manualKeyboardCase
                        }
                    )
                )
            }
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
        configureInputManager()
        configureJapaneseKeyboardBehavior()
        syncFullAccessStatus()
        aiKeyboardController.refreshPrompts()
        aiKeyboardController.refreshReplyAvailabilityOnAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        aiKeyboardController.stopClipboardMonitoring()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        configureJapaneseKeyboardBehavior()
        syncFullAccessStatus()
        aiKeyboardController.documentDidChange()
        aiKeyboardController.refreshReplyAvailability()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        configureJapaneseKeyboardBehavior()
        syncFullAccessStatus()
        aiKeyboardController.documentDidChange()
        aiKeyboardController.refreshReplyAvailability()
    }

    @MainActor
    func handleRomajiInput(_ character: Character) {
        inputManager.appendRomaji(character)
        resetOneShotShiftIfNeeded()
    }

    @MainActor
    func triggerKeyHaptic() {
        keyboardHaptics.triggerKeyPress()
    }

    @MainActor
    func triggerSelectionHaptic() {
        keyboardHaptics.triggerSelection()
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

    /// Return key: confirm the composition (確定) while composing, otherwise
    /// insert a newline. Used by the flick keyboard's return key — the romaji
    /// keyboard routes through KeyboardKit's action handler instead.
    @MainActor
    func handleReturn() {
        if inputManager.isComposing {
            commitComposingForReturn()
        } else {
            textDocumentProxy.insertText("\n")
        }
    }

    /// Switch the keyboard style at runtime (romaji ↔ flick) and re-render.
    @MainActor
    func switchKeyboardStyle(_ style: KeyboardPreferences.KeyboardStyle) {
        KeyboardSettingsStore.writeKeyboardStyle(style)
        configureInputManager(force: true)
        viewWillSetupKeyboardView()
    }

    @MainActor
    func commitCandidate(_ candidate: Candidate) {
        guard inputManager.isComposing else { return }
        finalizeMarkedText(replacement: candidate.text)
        recordConversionSelection(input: candidate.reading, replacement: candidate.text)
        inputManager.reset()
        inputManager.requestPrediction(after: candidate.text)
    }

    /// Tapping a next-word (予測変換) suggestion: nothing is being composed, so
    /// just insert the word directly. v1 does not chain to a further prediction
    /// (a suggestion carries no rich left-side context to predict from).
    @MainActor
    func commitPrediction(_ candidate: Candidate) {
        textDocumentProxy.insertText(candidate.text)
        inputManager.clearPredictions()
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
        inputManager.requestPrediction(after: replacement)
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
        // iOS's keyboard haptic preference is private to UIKit and unreadable
        // from a keyboard extension, so users opt in through our setting. We
        // fire haptics in JapaneseActionHandler because custom-composed keys
        // return before KeyboardKit's standard feedback path.
        if hapticsEnabled && !state.keyboardContext.hasFullAccess {
            hapticsEnabled = false
            KeyboardSettingsStore.writeHapticsEnabled(false)
        }
        keyboardHaptics.setEnabled(hapticsEnabled && state.keyboardContext.hasFullAccess)
        state.feedbackContext.settings.isHapticFeedbackEnabled = false
        state.feedbackContext.hapticConfiguration = .disabled
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

@MainActor
private final class KeyboardHapticFeedback {
    private let keyPressGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private var isEnabled = false

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            keyPressGenerator.prepare()
            selectionGenerator.prepare()
        }
    }

    func triggerKeyPress() {
        guard isEnabled else { return }
        keyPressGenerator.impactOccurred(intensity: 0.65)
        keyPressGenerator.prepare()
    }

    func triggerSelection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
}
