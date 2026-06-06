import JapaneseKeyboardUI
import UIKit

enum InputCapture {
    static let maxCharacters = 2_000

    @MainActor
    static func capture(from proxy: UITextDocumentProxy) throws -> WholeInputCapture {
        try WholeInputCapture.make(
            beforeCursor: proxy.documentContextBeforeInput ?? "",
            selectedText: proxy.selectedText ?? "",
            afterCursor: proxy.documentContextAfterInput ?? "",
            documentIdentifierString: String(describing: proxy.documentIdentifier),
            maxCharacters: maxCharacters
        )
    }
}
