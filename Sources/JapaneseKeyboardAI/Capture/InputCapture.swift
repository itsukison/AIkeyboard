import Foundation

public enum InputCapture {
    public static let maxCharacters = 2_000

    @MainActor
    public static func capture(from proxy: TextDocumentProxying) throws -> WholeInputCapture {
        try WholeInputCapture.make(
            beforeCursor: proxy.documentContextBeforeInput ?? "",
            selectedText: proxy.selectedText ?? "",
            afterCursor: proxy.documentContextAfterInput ?? "",
            documentIdentifierString: String(describing: proxy.documentIdentifier),
            maxCharacters: maxCharacters
        )
    }
}
