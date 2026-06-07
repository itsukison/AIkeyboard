import XCTest
@testable import JapaneseKeyboardAI

@MainActor
final class WholeInputReplacementEngineTests: XCTestCase {
    func testReplaceFromEndOfInput() throws {
        let proxy = FakeProxy(before: "今日は晴れです", selected: "", after: "")
        let capture = try WholeInputCapture.make(
            beforeCursor: "今日は晴れです",
            selectedText: "",
            afterCursor: "",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        try WholeInputReplacementEngine.replace(
            capture: capture,
            with: "本日は晴天なり。",
            proxy: proxy
        )

        XCTAssertEqual(proxy.before, "本日は晴天なり。")
        XCTAssertEqual(proxy.after, "")
        XCTAssertEqual(proxy.adjustCalls, 0)
        XCTAssertEqual(proxy.deleteCalls, 7)
    }

    func testReplaceFromCursorInMiddleMovesToEndFirst() throws {
        let proxy = FakeProxy(before: "今日は", selected: "", after: "晴れです")
        let capture = try WholeInputCapture.make(
            beforeCursor: "今日は",
            selectedText: "",
            afterCursor: "晴れです",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        try WholeInputReplacementEngine.replace(
            capture: capture,
            with: "本日は晴天なり。",
            proxy: proxy
        )

        XCTAssertEqual(proxy.before, "本日は晴天なり。")
        XCTAssertEqual(proxy.after, "")
        XCTAssertEqual(proxy.adjustCalls, 1)
        XCTAssertEqual(proxy.adjustOffsetTotal, 4)
        XCTAssertEqual(proxy.deleteCalls, 7)
    }

    func testReplaceWithSelection() throws {
        let proxy = FakeProxy(before: "今日は", selected: "とても", after: "晴れです")
        let capture = try WholeInputCapture.make(
            beforeCursor: "今日は",
            selectedText: "とても",
            afterCursor: "晴れです",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        try WholeInputReplacementEngine.replace(
            capture: capture,
            with: "本日は晴天なり。",
            proxy: proxy
        )

        XCTAssertEqual(proxy.before, "本日は晴天なり。")
        XCTAssertEqual(proxy.after, "")
        XCTAssertEqual(proxy.deleteCalls, 10)
    }

    func testReplaceAbortsWhenContextChanged() throws {
        let proxy = FakeProxy(before: "別のテキスト", selected: "", after: "")
        let capture = try WholeInputCapture.make(
            beforeCursor: "今日は晴れです",
            selectedText: "",
            afterCursor: "",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertThrowsError(
            try WholeInputReplacementEngine.replace(
                capture: capture,
                with: "本日は晴天なり。",
                proxy: proxy
            )
        ) { error in
            XCTAssertEqual(error as? ReplacementError, .contextChanged)
        }

        // Proxy state must not be mutated when validation fails.
        XCTAssertEqual(proxy.before, "別のテキスト")
        XCTAssertEqual(proxy.adjustCalls, 0)
        XCTAssertEqual(proxy.deleteCalls, 0)
    }

    func testCapturedThroughInputCaptureRoundTrips() throws {
        let proxy = FakeProxy(before: "あ", selected: "い", after: "う😀")
        let capture = try InputCapture.capture(from: proxy)

        XCTAssertEqual(capture.targetText, "あいう😀")

        try WholeInputReplacementEngine.replace(
            capture: capture,
            with: "OK",
            proxy: proxy
        )

        XCTAssertEqual(proxy.before, "OK")
        XCTAssertEqual(proxy.after, "")
    }
}

@MainActor
private final class FakeProxy: TextDocumentProxying {
    var before: String
    var selected: String
    var after: String

    var adjustCalls = 0
    var adjustOffsetTotal = 0
    var deleteCalls = 0

    init(before: String, selected: String, after: String) {
        self.before = before
        self.selected = selected
        self.after = after
    }

    var documentContextBeforeInput: String? { before }
    var documentContextAfterInput: String? { after }
    var selectedText: String? { selected.isEmpty ? nil : selected }
    var documentIdentifier: UUID? { nil }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        adjustCalls += 1
        adjustOffsetTotal += offset
        // Model: positive offset moves cursor right, pulling text from `after` into `before`.
        if offset > 0 {
            let n = min(offset, after.count)
            let idx = after.index(after.startIndex, offsetBy: n)
            before += String(after[..<idx])
            after = String(after[idx...])
        }
        // Selection is preserved as-is per UITextDocumentProxy semantics for adjustTextPosition.
    }

    func deleteBackward() {
        deleteCalls += 1
        // If selection exists, first delete clears the selection without touching before/after.
        if !selected.isEmpty {
            selected = ""
            return
        }
        guard !before.isEmpty else { return }
        before.removeLast()
    }

    func insertText(_ text: String) {
        if !selected.isEmpty {
            selected = ""
        }
        before += text
    }
}
