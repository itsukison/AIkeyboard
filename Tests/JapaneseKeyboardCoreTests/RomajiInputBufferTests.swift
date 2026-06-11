import XCTest
@testable import JapaneseKeyboardCore

@MainActor
final class RomajiInputBufferTests: XCTestCase {

    func testInitialEmpty() {
        let buf = RomajiInputBuffer()
        XCTAssertTrue(buf.isEmpty)
        XCTAssertEqual(buf.displayKana, "")
        XCTAssertEqual(buf.finalKana, "")
    }

    func testAppendBuildsKonnichiha() {
        let buf = RomajiInputBuffer()
        for ch in "kon'nichiha" {
            buf.append(ch)
        }
        XCTAssertEqual(buf.finalKana, "こんにちは")
    }

    func testProgressiveDisplay() {
        let buf = RomajiInputBuffer()
        buf.append("k")
        XCTAssertEqual(buf.displayKana, "k")
        buf.append("o")
        XCTAssertEqual(buf.displayKana, "こ")
        buf.append("n")
        XCTAssertEqual(buf.displayKana, "こn")
        buf.append("n")
        XCTAssertEqual(buf.displayKana, "こん")
        buf.append("i")
        // Strict nn rule: the second `n` already committed ん, so the trailing
        // `i` starts a fresh syllable — `い`, not `に`.
        XCTAssertEqual(buf.displayKana, "こんい")
    }

    // "ko" → "こ" (one kana from two romaji). Backspace deletes the whole
    // kana, not just one romaji — matches native Japanese IME behavior.
    func testBackspaceDeletesOneKanaUnit() {
        let buf = RomajiInputBuffer()
        buf.append("k")
        buf.append("o")
        XCTAssertTrue(buf.backspace())
        XCTAssertEqual(buf.pendingRomaji, "")
        XCTAssertEqual(buf.displayKana, "")
    }

    // "kon" → "こn" (kana + deferred trailing latin). Backspace removes only
    // the visible "n", leaving "こ".
    func testBackspaceRemovesTrailingLatinFirst() {
        let buf = RomajiInputBuffer()
        for ch in "kon" {
            buf.append(ch)
        }
        XCTAssertEqual(buf.displayKana, "こn")
        XCTAssertTrue(buf.backspace())
        XCTAssertEqual(buf.pendingRomaji, "ko")
        XCTAssertEqual(buf.displayKana, "こ")
    }

    // Strict nn: "konni" → "こんい". Backspace deletes the trailing kana and
    // the buffer shrinks to "konn", so the committed ん stays rendered.
    func testBackspaceAfterNNCommit() {
        let buf = RomajiInputBuffer()
        for ch in "konni" {
            buf.append(ch)
        }
        XCTAssertEqual(buf.displayKana, "こんい")
        XCTAssertTrue(buf.backspace())
        XCTAssertEqual(buf.pendingRomaji, "konn")
        XCTAssertEqual(buf.displayKana, "こん")
    }

    func testBackspaceDeletesSmallYoonKanaOnly() {
        let cases: [(romaji: String, expectedRomaji: String, expectedKana: String)] = [
            ("nya", "ni", "に"),
            ("kya", "ki", "き"),
            ("sha", "shi", "し"),
            ("cha", "chi", "ち"),
        ]

        for testCase in cases {
            let buf = RomajiInputBuffer()
            for ch in testCase.romaji {
                buf.append(ch)
            }

            XCTAssertTrue(buf.backspace(), testCase.romaji)
            XCTAssertEqual(buf.pendingRomaji, testCase.expectedRomaji, testCase.romaji)
            XCTAssertEqual(buf.displayKana, testCase.expectedKana, testCase.romaji)
        }
    }

    func testBackspaceDeletesSmallVowelKanaOnly() {
        let buf = RomajiInputBuffer()
        for ch in "fa" {
            buf.append(ch)
        }

        XCTAssertTrue(buf.backspace())
        XCTAssertEqual(buf.pendingRomaji, "fu")
        XCTAssertEqual(buf.displayKana, "ふ")
    }

    func testBackspaceAfterSokuonLeavesSokuon() {
        let buf = RomajiInputBuffer()
        for ch in "kko" {
            buf.append(ch)
        }

        XCTAssertTrue(buf.backspace())
        XCTAssertEqual(buf.displayKana, "っ")
    }

    func testBackspaceOnEmptyReturnsFalse() {
        let buf = RomajiInputBuffer()
        XCTAssertFalse(buf.backspace())
    }

    func testReset() {
        let buf = RomajiInputBuffer()
        buf.append("k")
        buf.append("o")
        buf.reset()
        XCTAssertTrue(buf.isEmpty)
    }
}
