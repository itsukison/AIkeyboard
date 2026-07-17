import XCTest
@testable import JapaneseKeyboardAI

final class WholeInputCaptureTests: XCTestCase {
    func testBeforeOnly() throws {
        let capture = try WholeInputCapture.make(
            beforeCursor: "これはテストです",
            selectedText: "",
            afterCursor: "",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertEqual(capture.targetText, "これはテストです")
        XCTAssertEqual(capture.moveToEndCharacterCount, 0)
        XCTAssertEqual(capture.deleteBackwardCharacterCount, 8)
    }

    func testCursorInMiddle() throws {
        let capture = try WholeInputCapture.make(
            beforeCursor: "今日は",
            selectedText: "",
            afterCursor: "晴れです",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertEqual(capture.targetText, "今日は晴れです")
        XCTAssertEqual(capture.moveToEndCharacterCount, 4)
        XCTAssertEqual(capture.deleteBackwardCharacterCount, 7)
    }

    func testIncludesSelection() throws {
        let capture = try WholeInputCapture.make(
            beforeCursor: "今日は",
            selectedText: "とても",
            afterCursor: "晴れです",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertEqual(capture.targetText, "今日はとても晴れです")
        XCTAssertEqual(capture.moveToEndCharacterCount, 4)
        XCTAssertEqual(capture.deleteBackwardCharacterCount, 10)
    }

    func testRejectsWhitespace() {
        XCTAssertThrowsError(
            try WholeInputCapture.make(
                beforeCursor: "  ",
                selectedText: "\n",
                afterCursor: "",
                documentIdentifierString: "doc",
                maxCharacters: 2_000
            )
        ) { error in
            XCTAssertEqual(error as? WholeInputCaptureError, .empty)
        }
    }

    func testRejectsTooLongInput() {
        XCTAssertThrowsError(
            try WholeInputCapture.make(
                beforeCursor: String(repeating: "あ", count: 2_001),
                selectedText: "",
                afterCursor: "",
                documentIdentifierString: "doc",
                maxCharacters: 2_000
            )
        ) { error in
            XCTAssertEqual(error as? WholeInputCaptureError, .tooLong)
        }
    }

    func testAllowEmptyProducesZeroCountCapture() throws {
        let capture = try WholeInputCapture.make(
            beforeCursor: "",
            selectedText: "",
            afterCursor: "",
            documentIdentifierString: "doc",
            maxCharacters: 2_000,
            allowEmpty: true
        )

        XCTAssertEqual(capture.targetText, "")
        XCTAssertEqual(capture.moveToEndCharacterCount, 0)
        XCTAssertEqual(capture.deleteBackwardCharacterCount, 0)
    }

    func testAllowEmptyStillRejectsTooLong() {
        XCTAssertThrowsError(
            try WholeInputCapture.make(
                beforeCursor: String(repeating: "あ", count: 2_001),
                selectedText: "",
                afterCursor: "",
                documentIdentifierString: "doc",
                maxCharacters: 2_000,
                allowEmpty: true
            )
        ) { error in
            XCTAssertEqual(error as? WholeInputCaptureError, .tooLong)
        }
    }

    func testCountsComposedCharacters() throws {
        let capture = try WholeInputCapture.make(
            beforeCursor: "は",
            selectedText: "が",
            afterCursor: "😀",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertEqual(capture.targetText, "はが😀")
        XCTAssertEqual(capture.moveToEndCharacterCount, 1)
        XCTAssertEqual(capture.deleteBackwardCharacterCount, 3)
    }

    func testMakeProducesWholeInputMode() throws {
        let capture = try WholeInputCapture.make(
            beforeCursor: "今日は",
            selectedText: "",
            afterCursor: "",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertEqual(capture.mode, .wholeInput)
    }

    func testMakeSelectionTargetsSelectionOnly() throws {
        let capture = try WholeInputCapture.makeSelection(
            beforeCursor: "今日は",
            selectedText: "とても",
            afterCursor: "晴れです",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertEqual(capture.mode, .selection)
        XCTAssertEqual(capture.targetText, "とても")
        XCTAssertEqual(capture.beforeCursor, "今日は")
        XCTAssertEqual(capture.afterCursor, "晴れです")
        XCTAssertEqual(capture.moveToEndCharacterCount, 0)
        XCTAssertEqual(capture.deleteBackwardCharacterCount, 0)
    }

    func testMakeSelectionRejectsWhitespaceSelection() {
        XCTAssertThrowsError(
            try WholeInputCapture.makeSelection(
                beforeCursor: "今日は",
                selectedText: " \n",
                afterCursor: "晴れです",
                documentIdentifierString: "doc",
                maxCharacters: 2_000
            )
        ) { error in
            XCTAssertEqual(error as? WholeInputCaptureError, .empty)
        }
    }

    func testMakeSelectionRejectsTooLongSelection() {
        XCTAssertThrowsError(
            try WholeInputCapture.makeSelection(
                beforeCursor: "",
                selectedText: String(repeating: "あ", count: 2_001),
                afterCursor: "",
                documentIdentifierString: "doc",
                maxCharacters: 2_000
            )
        ) { error in
            XCTAssertEqual(error as? WholeInputCaptureError, .tooLong)
        }
    }

    func testMakeSelectionAllowsLongSurroundingContext() throws {
        // Only the selection counts against the cap — the surrounding text is
        // context, not the rewrite target.
        let capture = try WholeInputCapture.makeSelection(
            beforeCursor: String(repeating: "あ", count: 1_500),
            selectedText: "とても",
            afterCursor: String(repeating: "い", count: 1_500),
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertEqual(capture.targetText, "とても")
    }
}
