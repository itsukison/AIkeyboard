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

    /// Selection-only capture. Throws `.empty` when the host reports no
    /// selection (or a whitespace-only one).
    @MainActor
    public static func captureSelection(from proxy: TextDocumentProxying) throws -> WholeInputCapture {
        try WholeInputCapture.makeSelection(
            beforeCursor: proxy.documentContextBeforeInput ?? "",
            selectedText: proxy.selectedText ?? "",
            afterCursor: proxy.documentContextAfterInput ?? "",
            documentIdentifierString: String(describing: proxy.documentIdentifier),
            maxCharacters: maxCharacters
        )
    }

    /// Like `capture`, but tolerates an empty field. Reply mode inserts the
    /// generated reply at the cursor, so an empty draft is valid input.
    @MainActor
    public static func captureForReply(from proxy: TextDocumentProxying) throws -> WholeInputCapture {
        try WholeInputCapture.make(
            beforeCursor: proxy.documentContextBeforeInput ?? "",
            selectedText: proxy.selectedText ?? "",
            afterCursor: proxy.documentContextAfterInput ?? "",
            documentIdentifierString: String(describing: proxy.documentIdentifier),
            maxCharacters: maxCharacters,
            allowEmpty: true
        )
    }
}
