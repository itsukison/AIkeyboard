import KeyboardKit
import UIKit

final class JapaneseActionHandler: KeyboardAction.StandardActionHandler {
    private weak var jpController: KeyboardViewController?
    /// True while a backspace press/repeat sequence has at least once been
    /// consumed by our composing buffer. Tracked so the matching `.release`
    /// can be swallowed (KeyboardKit's release-side state cleanup pairs with
    /// the press it never saw).
    private var backspaceSequenceConsumed = false

    @MainActor
    init(controller: KeyboardViewController) {
        self.jpController = controller
        super.init(
            controller: controller,
            keyboardContext: controller.state.keyboardContext,
            keyboardBehavior: controller.services.keyboardBehavior,
            autocompleteContext: controller.state.autocompleteContext,
            autocompleteService: controller.services.autocompleteService,
            emojiContext: controller.state.emojiContext,
            feedbackContext: controller.state.feedbackContext,
            feedbackService: controller.services.feedbackService,
            keyboardAppContext: controller.state.keyboardAppContext,
            spacebarDragGestureHandler: controller.services.spacebarDragGestureHandler
        )
    }

    /// Japanese romaji keyboard never auto-changes case. KeyboardKit's default
    /// action handler runs this after every gesture, asks the behavior for a
    /// preferred case (which can return `.uppercased` at sentence start even
    /// with the autocap override set to `.none`), and clobbers our
    /// `keyboardCase = .lowercased`. Override to a no-op so the initial state
    /// set in `configureJapaneseKeyboardBehavior` stays put. The buffer
    /// already lowercases any incoming character (`InputManager.appendRomaji`),
    /// so kana conversion is unaffected.
    override func tryChangeKeyboardCase(after gesture: Keyboard.Gesture, on action: KeyboardAction) {
        // intentionally empty
    }

    override func handle(_ gesture: Keyboard.Gesture, on action: KeyboardAction) {
        if gesture == .press || gesture == .repeatPress {
            let controller = jpController
            MainActor.assumeIsolated {
                controller?.triggerKeyHaptic()
            }
        }

        if gesture == .press, case .backspace = action {
            backspaceSequenceConsumed = false
        }

        // Composing-time backspace must run on press / repeatPress, not release.
        // Otherwise KeyboardKit's super.handle would call deleteBackward() on
        // the host on `.press`, racing with our `setMarkedText` and causing the
        // marked text to flicker / appear to delete one character at a time.
        if case .backspace = action, gesture == .press || gesture == .repeatPress {
            let controller = jpController
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let controller, controller.inputManager.isComposing else { return false }
                _ = controller.handleBackspace()
                return true
            }
            if consumed {
                backspaceSequenceConsumed = true
                return
            }
        }

        // If we consumed any press/repeatPress of this backspace sequence,
        // swallow the matching release so we don't trigger super's pair work
        // (which would race with our marked-text state).
        if case .backspace = action, gesture == .release, backspaceSequenceConsumed {
            backspaceSequenceConsumed = false
            return
        }

        if gesture == .release {
            let controller = jpController
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let controller else { return false }
                switch action {
                case .character(let s):
                    if let ch = Self.singleRomajiCharacter(s) {
                        controller.handleRomajiInput(ch)
                        return true
                    }
                    controller.flushBufferToHost()
                    return false
                case .space:
                    // 次候補: while composing, space cycles candidates and is
                    // never forwarded to the host. Only when not composing
                    // does it fall through to KeyboardKit and insert a space.
                    if controller.inputManager.isComposing {
                        controller.handleSpace()
                        return true
                    }
                    return false
                case .backspace:
                    // Sequence was non-composing throughout — let super handle.
                    return false
                case .primary:
                    if controller.inputManager.isComposing {
                        controller.commitComposingForReturn()
                        return true
                    }
                    return false
                case .shift:
                    return controller.handleShift(gesture)
                default:
                    return false
                }
            }
            if handled { return }
        }

        if gesture == .doubleTap {
            let controller = jpController
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let controller else { return false }
                if case .shift = action {
                    return controller.handleShift(gesture)
                }
                return false
            }
            if handled { return }
        }

        super.handle(gesture, on: action)
    }

    /// Returns the character if `s` is a single romaji-buffer-accepting input:
    /// an ASCII letter (a-z / A-Z) or the chōonpu shortcut `-` (which the
    /// romaji table maps to `ー`).
    private static func singleRomajiCharacter(_ s: String) -> Character? {
        guard s.count == 1, let ch = s.first else { return nil }
        if ch == "-" { return ch }
        if ch.isLetter, ch.isASCII { return ch }
        return nil
    }
}
