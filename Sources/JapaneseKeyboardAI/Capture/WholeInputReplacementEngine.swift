import Foundation

public enum ReplacementError: Error, Equatable {
    case contextChanged
}

public enum WholeInputReplacementEngine {
    @MainActor
    public static func replace(
        capture: WholeInputCapture,
        with replacement: String,
        proxy: TextDocumentProxying
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
