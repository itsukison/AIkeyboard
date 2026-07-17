import XCTest
@testable import JapaneseKeyboardAI

@MainActor
final class FullDocumentReplacementEngineTests: XCTestCase {
    private func makeFullCapture(before: String, after: String) throws -> WholeInputCapture {
        try WholeInputCapture.makeFullDocument(
            beforeCursor: before,
            afterCursor: after,
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )
    }

    func testReplacesWholeDocumentWithCursorInMiddle() async throws {
        let text = "The quick brown fox jumps over the lazy dog."
        let cursor = 20
        let proxy = WindowedFakeProxy(text: text, cursor: cursor, maxWindow: 6, paragraphTruncation: false)
        let capture = try makeFullCapture(
            before: String(text.prefix(cursor)),
            after: String(text.suffix(text.count - cursor))
        )

        try await WholeInputReplacementEngine.replaceFullDocument(
            capture: capture,
            with: "REPLACED",
            proxy: proxy,
            settle: {}
        )

        XCTAssertEqual(proxy.text, "REPLACED")
    }

    func testAbortsWhenBeforePrefixNoLongerMatches() async throws {
        let proxy = WindowedFakeProxy(text: "completely different text now", cursor: 5, maxWindow: 6, paragraphTruncation: false)
        let capture = try makeFullCapture(before: "original before", after: "original after")

        await assertThrowsContextChanged {
            try await WholeInputReplacementEngine.replaceFullDocument(
                capture: capture,
                with: "X",
                proxy: proxy,
                settle: {}
            )
        }
    }

    func testAbortsWhenSelectionActive() async throws {
        let text = "hello world here"
        let proxy = WindowedFakeProxy(text: text, cursor: 0, selectionLength: 5, maxWindow: 6, paragraphTruncation: false)
        let capture = try makeFullCapture(before: "", after: text)

        await assertThrowsContextChanged {
            try await WholeInputReplacementEngine.replaceFullDocument(
                capture: capture,
                with: "X",
                proxy: proxy,
                settle: {}
            )
        }
    }

    func testSyncReplaceRejectsFullDocumentCapture() throws {
        let proxy = FakeProxy(before: "abc", selected: "", after: "")
        let capture = try makeFullCapture(before: "abc", after: "")

        XCTAssertThrowsError(
            try WholeInputReplacementEngine.replace(capture: capture, with: "X", proxy: proxy)
        ) { error in
            XCTAssertEqual(error as? ReplacementError, .unsupportedCaptureMode)
        }
    }

    private func assertThrowsContextChanged(
        _ block: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await block()
            XCTFail("expected ReplacementError.contextChanged", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ReplacementError, .contextChanged, file: file, line: line)
        }
    }
}
