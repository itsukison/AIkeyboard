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
    /// When the keyboard last became visible, used to tally active seconds on
    /// disappear. In-memory only — never persisted.
    private var keyboardAppearedAt: Date?
    /// The day we last marked typing activity, so `textDidChange` writes to the
    /// App Group at most once per day instead of on every keystroke.
    private var typedDayMarker: String?
    /// The previous committed word, so the next commit can be recorded as a
    /// next-word (予測変換) transition in `NextWordPreferenceStore`.
    private var lastCommittedWord: String?
    private lazy var aiKeyboardController = AIKeyboardController(
        controller: self,
        inputManager: inputManager
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        autoEnableHapticsDefaultIfNeeded()
        hapticsEnabled = KeyboardSettingsStore.readHapticsEnabled()
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
            // Persist learning in the App Group so it survives keyboard
            // restarts; the default temp dir would be purged by iOS.
            let adapter = KanaKanjiAdapter(
                supportDirectoryURL: AppGroup.sharedContainerURL?
                    .appendingPathComponent("conversion-learning", isDirectory: true)
            )
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
                            self?.handleSpace()
                        },
                        onReturn: { [weak self] in
                            self?.handleReturn()
                        },
                        onMoveCursorRight: { [weak self] in
                            self?.moveCursorRight()
                        },
                        onUndo: { [weak self] in
                            self?.undoLastInput()
                        },
                        onNextKeyboard: { [weak self] in
                            self?.switchToNextKeyboard()
                        },
                        onInsertText: { [weak self] text in
                            self?.insertLiteralText(text)
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
                            ZStack {
                                AIResultOverlayView(
                                    aiController: self.aiKeyboardController,
                                    onTriggerHaptic: { [weak self] in
                                        self?.triggerKeyHaptic()
                                    },
                                    onSelectionHaptic: { [weak self] in
                                        self?.triggerSelectionHaptic()
                                    }
                                )
                                ExpandedCandidateView(
                                    inputManager: manager,
                                    onSelect: { [weak self] candidate in
                                        self?.commitCandidate(candidate)
                                    },
                                    onTriggerHaptic: { [weak self] in
                                        self?.triggerKeyHaptic()
                                    }
                                )
                            }
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
                            ZStack {
                                AIResultOverlayView(
                                    aiController: self.aiKeyboardController,
                                    onTriggerHaptic: { [weak self] in
                                        self?.triggerKeyHaptic()
                                    },
                                    onSelectionHaptic: { [weak self] in
                                        self?.triggerSelectionHaptic()
                                    }
                                )
                                ExpandedCandidateView(
                                    inputManager: manager,
                                    onSelect: { [weak self] candidate in
                                        self?.commitCandidate(candidate)
                                    },
                                    onTriggerHaptic: { [weak self] in
                                        self?.triggerKeyHaptic()
                                    }
                                )
                            }
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
        autoEnableHapticsDefaultIfNeeded()
        hapticsEnabled = KeyboardSettingsStore.readHapticsEnabled()
        configureInputManager()
        configureJapaneseKeyboardBehavior()
        syncFullAccessStatus()
        aiKeyboardController.refreshPrompts()
        aiKeyboardController.refreshReplyAvailabilityOnAppear()
        KeyboardUsageDailyStore.recordKeyboardOpen()
        keyboardAppearedAt = Date()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Flush learned conversions to disk off the typing path.
        inputManager.persistLearning()
        aiKeyboardController.stopClipboardMonitoring()
        if let appearedAt = keyboardAppearedAt {
            let elapsed = Int(Date().timeIntervalSince(appearedAt))
            if elapsed > 0 && elapsed < 3600 {
                KeyboardUsageDailyStore.addActiveSeconds(elapsed)
            }
            keyboardAppearedAt = nil
        }
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
        markTypedActivityIfNeeded()
    }

    /// Marks the user active for today at most once per day; the in-memory guard
    /// keeps the hot text-change path off the App Group on every keystroke.
    private func markTypedActivityIfNeeded() {
        let today = Self.dayString(Date())
        guard typedDayMarker != today else { return }
        typedDayMarker = today
        KeyboardUsageDailyStore.markTyped()
    }

    private static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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

    /// Backspace. While composing, shrink the kana buffer; otherwise delete a
    /// character from the host. (The QWERTY action handler only calls this while
    /// composing — KeyboardKit handles the non-composing case there — but the
    /// flick keyboard has no such fallback, so it must delete here.)
    @MainActor
    @discardableResult
    func handleBackspace() -> Bool {
        if inputManager.isComposing {
            inputManager.backspace()
        } else {
            textDocumentProxy.deleteBackward()
        }
        return true
    }

    /// Space. While composing, cycle to the next candidate (次候補) and never
    /// forward to the host. Otherwise insert a full-width space, matching the
    /// native Japanese keyboard. (As with backspace, QWERTY only reaches the
    /// composing branch; the flick keyboard relies on the insert here.)
    @MainActor
    func handleSpace() {
        if inputManager.isComposing {
            inputManager.selectNextCandidate()
        } else {
            textDocumentProxy.insertText("　")
        }
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

    /// → key: move the caret one character to the right. Only when not
    /// composing — moving the caret through marked text is not meaningful.
    @MainActor
    func moveCursorRight() {
        guard !inputManager.isComposing else { return }
        textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
    }

    /// 🌐 key: advance to the next system keyboard.
    @MainActor
    func switchToNextKeyboard() {
        advanceToNextInputMode()
    }

    /// Insert a literal string (kaomoji, or an ABC/number page character). If a
    /// kana composition is active, commit it first so marked text isn't
    /// disturbed, then insert.
    @MainActor
    func insertLiteralText(_ text: String) {
        if inputManager.isComposing {
            commitComposingForReturn()
        }
        textDocumentProxy.insertText(text)
    }

    /// ↺ key: "元に戻す". TODO(M2): real undo needs an input/undo stack; the
    /// exact semantics (revert last flick vs last conversion) are still open,
    /// so this is intentionally a no-op until that's specified.
    @MainActor
    func undoLastInput() {}

    @MainActor
    func commitCandidate(_ candidate: Candidate) {
        guard inputManager.isComposing else { return }
        finalizeMarkedText(replacement: candidate.text)
        recordNextWord(candidate.text)
        inputManager.recordCommitForLearning(candidate.text)
        inputManager.reset()
        inputManager.requestPrediction(after: candidate.text)
    }

    /// Tapping a next-word (予測変換) suggestion: nothing is being composed, so
    /// insert the word directly. Records the transition and chains to the next
    /// prediction, which surfaces the user's learned next-words for this word
    /// (azooKey has no rich context to add here).
    @MainActor
    func commitPrediction(_ candidate: Candidate) {
        textDocumentProxy.insertText(candidate.text)
        recordNextWord(candidate.text)
        inputManager.requestPrediction(after: candidate.text)
    }

    /// 確定: commit the currently-displayed preview (selected candidate if the
    /// user cycled, otherwise the raw kana). Does NOT insert a newline; user
    /// presses return a second time (now non-composing) for that.
    @MainActor
    func commitComposingForReturn() {
        guard inputManager.isComposing else { return }
        let replacement = inputManager.commitText
        finalizeMarkedText(replacement: replacement)
        recordNextWord(replacement)
        inputManager.recordCommitForLearning(replacement)
        inputManager.reset()
        inputManager.requestPrediction(after: replacement)
    }

    @MainActor
    func flushBufferToHost() {
        guard inputManager.isComposing else { return }
        let replacement = inputManager.commitText
        finalizeMarkedText(replacement: replacement)
        inputManager.recordCommitForLearning(replacement)
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

    /// Learn the just-committed word as the next word after the previous one,
    /// then carry it forward as the new "previous" for the following commit.
    private func recordNextWord(_ committed: String) {
        let word = committed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        if let previous = lastCommittedWord {
            NextWordPreferenceStore.recordTransition(previous: previous, next: word)
        }
        lastCommittedWord = word
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
        // return before KeyboardKit's standard feedback path. The preference
        // is runtime-gated on Full Access below; we never persist a downgrade
        // so haptics auto-resume if Full Access is toggled back on.
        keyboardHaptics.setEnabled(hapticsEnabled && state.keyboardContext.hasFullAccess)
        state.feedbackContext.settings.isHapticFeedbackEnabled = false
        state.feedbackContext.hapticConfiguration = .disabled
    }

    /// One-time default seeding: the first time the keyboard loads with Full
    /// Access on, opt the user into haptics. After this write the preference
    /// key is explicitly set, so later manual toggles are respected and this
    /// no-ops. Stays off if the user never grants Full Access.
    private func autoEnableHapticsDefaultIfNeeded() {
        guard !KeyboardSettingsStore.isHapticsEnabledSet(),
              state.keyboardContext.hasFullAccess else { return }
        KeyboardSettingsStore.writeHapticsEnabled(true)
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
        keyPressGenerator.impactOccurred(intensity: 0.6)
        keyPressGenerator.prepare()
    }

    func triggerSelection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
}
