import JapaneseKeyboardUI
import UIKit

enum ReplacementError: Error {
    case contextChanged
}

enum WholeInputReplacementEngine {
    @MainActor
    static func replace(
        capture: WholeInputCapture,
        with replacement: String,
        proxy: UITextDocumentProxy
    ) throws {
        let currentTarget = (proxy.documentContextBeforeInput ?? "")
            + (proxy.selectedText ?? "")
            + (proxy.documentContextAfterInput ?? "")
        guard currentTarget == capture.targetText else {
            throw ReplacementError.contextChanged
        }

        if capture.moveToEndCharacterCount > 0 {
            proxy.adjustTextPosition(byCharacterOffset: capture.moveToEndCharacterCount)
        }

        for _ in 0..<capture.deleteBackwardCharacterCount {
            proxy.deleteBackward()
        }

        proxy.insertText(replacement)
    }
}
