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

    func testReplyInsertsIntoEmptyField() throws {
        let proxy = FakeProxy(before: "", selected: "", after: "")
        let capture = try InputCapture.captureForReply(from: proxy)

        XCTAssertEqual(capture.targetText, "")

        try WholeInputReplacementEngine.replace(
            capture: capture,
            with: "承知しました。よろしくお願いします。",
            proxy: proxy
        )

        XCTAssertEqual(proxy.before, "承知しました。よろしくお願いします。")
        XCTAssertEqual(proxy.after, "")
        XCTAssertEqual(proxy.adjustCalls, 0)
        XCTAssertEqual(proxy.deleteCalls, 0)
    }

    func testReplyReplacesExistingDraft() throws {
        let proxy = FakeProxy(before: "金曜は無理", selected: "", after: "")
        let capture = try InputCapture.captureForReply(from: proxy)

        try WholeInputReplacementEngine.replace(
            capture: capture,
            with: "申し訳ありませんが、金曜日は都合がつきません。",
            proxy: proxy
        )

        XCTAssertEqual(proxy.before, "申し訳ありませんが、金曜日は都合がつきません。")
        XCTAssertEqual(proxy.deleteCalls, 5)
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

    func testSelectionReplacePreservesSurroundingText() throws {
        let proxy = FakeProxy(before: "今日は", selected: "とても", after: "晴れです")
        let capture = try InputCapture.captureSelection(from: proxy)

        XCTAssertEqual(capture.targetText, "とても")

        try WholeInputReplacementEngine.replace(
            capture: capture,
            with: "非常に",
            proxy: proxy
        )

        XCTAssertEqual(proxy.before, "今日は非常に")
        XCTAssertEqual(proxy.after, "晴れです")
        XCTAssertEqual(proxy.selected, "")
        XCTAssertEqual(proxy.adjustCalls, 0)
        XCTAssertEqual(proxy.deleteCalls, 0)
        XCTAssertEqual(proxy.insertCalls, 1)
    }

    func testSelectionReplaceAbortsWhenBeforeChanged() throws {
        let proxy = FakeProxy(before: "今日は", selected: "とても", after: "晴れです")
        let capture = try InputCapture.captureSelection(from: proxy)
        proxy.before = "昨日は"

        assertSelectionReplaceAborts(capture: capture, proxy: proxy)
        XCTAssertEqual(proxy.selected, "とても")
    }

    func testSelectionReplaceAbortsWhenAfterChanged() throws {
        let proxy = FakeProxy(before: "今日は", selected: "とても", after: "晴れです")
        let capture = try InputCapture.captureSelection(from: proxy)
        proxy.after = "雨です"

        assertSelectionReplaceAborts(capture: capture, proxy: proxy)
    }

    func testSelectionReplaceAbortsWhenSelectionChanged() throws {
        let proxy = FakeProxy(before: "今日は", selected: "とても", after: "晴れです")
        let capture = try InputCapture.captureSelection(from: proxy)
        proxy.selected = "すごく"

        assertSelectionReplaceAborts(capture: capture, proxy: proxy)
    }

    func testSelectionReplaceAbortsWhenSelectionCleared() throws {
        let proxy = FakeProxy(before: "今日は", selected: "とても", after: "晴れです")
        let capture = try InputCapture.captureSelection(from: proxy)
        // A cleared selection must abort: insertText would insert at the cursor
        // instead of replacing the selection.
        proxy.selected = ""

        assertSelectionReplaceAborts(capture: capture, proxy: proxy)
        XCTAssertEqual(proxy.before, "今日は")
        XCTAssertEqual(proxy.after, "晴れです")
    }

    private func assertSelectionReplaceAborts(capture: WholeInputCapture, proxy: FakeProxy) {
        XCTAssertThrowsError(
            try WholeInputReplacementEngine.replace(
                capture: capture,
                with: "非常に",
                proxy: proxy
            )
        ) { error in
            XCTAssertEqual(error as? ReplacementError, .contextChanged)
        }
        XCTAssertEqual(proxy.insertCalls, 0)
        XCTAssertEqual(proxy.deleteCalls, 0)
        XCTAssertEqual(proxy.adjustCalls, 0)
    }
}
