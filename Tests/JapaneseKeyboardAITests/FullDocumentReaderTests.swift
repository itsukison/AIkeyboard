import XCTest
@testable import JapaneseKeyboardAI

@MainActor
final class FullDocumentReaderTests: XCTestCase {
    private func read(_ proxy: WindowedFakeProxy, maxCharacters: Int = 2_000) async -> FullDocumentReadResult {
        await FullDocumentReader(
            proxy: proxy,
            maxCharacters: maxCharacters,
            settle: {}
        ).read()
    }

    func testStitchesLongSingleLineDocument() async throws {
        let text = String((0..<80).map { Character(UnicodeScalar(65 + ($0 % 26))!) })
        let proxy = WindowedFakeProxy(text: text, cursor: 40, maxWindow: 7, paragraphTruncation: false)

        let result = await read(proxy)

        XCTAssertEqual(
            result,
            .snapshot(beforeCursor: String(text.prefix(40)), afterCursor: String(text.suffix(40)))
        )
        // Cursor must be restored to where it started.
        XCTAssertEqual(proxy.cursor, 40)
    }

    func testPreservesParagraphNewlines() async throws {
        let text = "one\ntwo\nthree"
        let proxy = WindowedFakeProxy(text: text, cursor: text.count, maxWindow: 2)

        let result = await read(proxy)

        XCTAssertEqual(result, .snapshot(beforeCursor: text, afterCursor: ""))
        XCTAssertEqual(proxy.cursor, text.count)
    }

    func testStitchesWithCursorInsideMiddleParagraph() async throws {
        let text = "alpha\nbravo\ncharlie"
        // Cursor after "bra" inside the middle paragraph.
        let cursor = "alpha\nbra".count
        let proxy = WindowedFakeProxy(text: text, cursor: cursor, maxWindow: 3)

        let result = await read(proxy)

        XCTAssertEqual(
            result,
            .snapshot(beforeCursor: "alpha\nbra", afterCursor: "vo\ncharlie")
        )
        XCTAssertEqual(proxy.cursor, cursor)
    }

    func testDocumentStartAndEndDetected() async throws {
        let text = "short text"
        let proxy = WindowedFakeProxy(text: text, cursor: 0, maxWindow: 4, paragraphTruncation: false)

        let result = await read(proxy)

        XCTAssertEqual(result, .snapshot(beforeCursor: "", afterCursor: text))
        XCTAssertEqual(proxy.cursor, 0)
    }

    func testEmojiDocumentRoundTrips() async throws {
        let text = "あ😀い🎉うABC😀😀ん"
        let cursor = 4
        let proxy = WindowedFakeProxy(text: text, cursor: cursor, maxWindow: 3, paragraphTruncation: false)

        let result = await read(proxy)

        let chars = Array(text)
        XCTAssertEqual(
            result,
            .snapshot(
                beforeCursor: String(chars[0..<cursor]),
                afterCursor: String(chars[cursor...])
            )
        )
        XCTAssertEqual(proxy.cursor, cursor)
    }

    func testHostThatIgnoresAdjustFails() async throws {
        let text = String(repeating: "x", count: 60)
        let proxy = WindowedFakeProxy(text: text, cursor: 30, maxWindow: 5, paragraphTruncation: false, adjustBehavior: .ignore)

        let result = await read(proxy)

        XCTAssertEqual(result, .failed)
    }

    func testOverCapReturnsTooLong() async throws {
        // Varied text so overlap trimming doesn't false-match; the cap must be
        // what stops the walk.
        let text = String((0..<200).map { Character(UnicodeScalar(97 + ($0 % 26))!) })
        let proxy = WindowedFakeProxy(text: text, cursor: 200, maxWindow: 20, paragraphTruncation: false)

        let result = await read(proxy, maxCharacters: 50)

        XCTAssertEqual(result, .tooLong)
    }

    func testIterationCapFailsGracefully() async throws {
        // A document far larger than maxIterations * maxWindow can stitch.
        let text = String(repeating: "z", count: 500)
        let proxy = WindowedFakeProxy(text: text, cursor: 500, maxWindow: 2, paragraphTruncation: false)

        let result = await FullDocumentReader(
            proxy: proxy,
            maxCharacters: 2_000,
            maxIterationsPerDirection: 5,
            settle: {}
        ).read()

        XCTAssertEqual(result, .failed)
    }

    func testActiveSelectionIsNotWalked() async throws {
        let proxy = WindowedFakeProxy(text: "hello world", cursor: 0, selectionLength: 5, maxWindow: 4)

        let result = await read(proxy)

        XCTAssertEqual(result, .failed)
    }

    func testUndershootingHostFailsSafeWithoutCorruption() async throws {
        // A host that consistently moves one fewer character than requested
        // cannot be walked to completion, but overlap trimming must ensure it
        // fails cleanly rather than returning corrupted (duplicated) text.
        let text = String((0..<60).map { Character(UnicodeScalar(97 + ($0 % 26))!) })
        let proxy = WindowedFakeProxy(text: text, cursor: 60, maxWindow: 6, paragraphTruncation: false, adjustBehavior: .undershoot(1))

        let result = await read(proxy)

        if case .snapshot(let before, let after) = result {
            // If it does return a snapshot, it must be the truth — never corrupt.
            XCTAssertEqual(before, text)
            XCTAssertEqual(after, "")
        } else {
            XCTAssertEqual(result, .failed)
        }
    }
}
