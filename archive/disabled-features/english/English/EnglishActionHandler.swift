import KeyboardKit
import UIKit

/// English-mode action handler. It behaves exactly like KeyboardKit's standard
/// handler — letters insert directly, backspace/space/return work natively —
/// except that on space it first autocorrects the word the user just finished.
///
/// Only installed when `KeyboardLanguage` is `.english`; the Japanese path keeps
/// using `JapaneseActionHandler`.
final class EnglishActionHandler: KeyboardAction.StandardActionHandler {
    private weak var enController: KeyboardViewController?

    @MainActor
    init(controller: KeyboardViewController) {
        self.enController = controller
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

    override func handle(_ gesture: Keyboard.Gesture, on action: KeyboardAction) {
        // Autocorrect the finished word before the space is inserted by super.
        if gesture == .release, case .space = action {
            let controller = enController
            MainActor.assumeIsolated {
                controller?.englishController.finishWordOnSpace()
            }
        }
        super.handle(gesture, on: action)
    }
}
