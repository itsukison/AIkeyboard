import XCTest
@testable import JapaneseKeyboardCore

@MainActor
final class KanaInputBufferTests: XCTestCase {

    func testInitialEmpty() {
        let buf = KanaInputBuffer()
        XCTAssertTrue(buf.isEmpty)
        XCTAssertEqual(buf.displayKana, "")
        XCTAssertEqual(buf.finalKana, "")
    }

    func testAppendKana() {
        let buf = KanaInputBuffer()
        buf.append("あ")
        XCTAssertFalse(buf.isEmpty)
        XCTAssertEqual(buf.displayKana, "あ")
        XCTAssertEqual(buf.finalKana, "あ")
    }

    func testAppendMultipleKana() {
        let buf = KanaInputBuffer()
        buf.append("あ")
        buf.append("い")
        buf.append("う")
        XCTAssertEqual(buf.displayKana, "あいう")
        XCTAssertEqual(buf.finalKana, "あいう")
    }

    func testDisplayAndFinalAreSame() {
        let buf = KanaInputBuffer()
        buf.append("きょう")
        XCTAssertEqual(buf.displayKana, "きょう")
        XCTAssertEqual(buf.finalKana, "きょう")
    }

    func testBackspaceDeletesOneKana() {
        let buf = KanaInputBuffer()
        buf.append("あいう")
        XCTAssertTrue(buf.backspace())
        XCTAssertEqual(buf.displayKana, "あい")
        XCTAssertTrue(buf.backspace())
        XCTAssertEqual(buf.displayKana, "あ")
    }

    func testBackspaceOnEmptyReturnsFalse() {
        let buf = KanaInputBuffer()
        XCTAssertFalse(buf.backspace())
    }

    func testReset() {
        let buf = KanaInputBuffer()
        buf.append("あいう")
        buf.reset()
        XCTAssertTrue(buf.isEmpty)
        XCTAssertEqual(buf.displayKana, "")
    }
}
