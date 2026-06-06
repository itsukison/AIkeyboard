import XCTest
@testable import JapaneseKeyboardCore

@MainActor
final class InputManagerTests: XCTestCase {

    private func makeManagerWithAdapter() -> InputManager {
        let im = InputManager()
        im.setAdapter(KanaKanjiAdapter())
        return im
    }

    func testInitialEmpty() {
        let im = InputManager()
        XCTAssertFalse(im.isComposing)
        XCTAssertEqual(im.displayKana, "")
        XCTAssertEqual(im.candidates.count, 0)
        XCTAssertEqual(im.markedText, "")
    }

    func testTypingKyouProducesCandidates() async {
        let im = makeManagerWithAdapter()
        for ch in "kyou" {
            im.appendRomaji(ch)
        }
        XCTAssertTrue(im.isComposing)
        XCTAssertEqual(im.displayKana, "きょう")
        // Wait for async conversion
        await im.currentConversionTask()?.value
        XCTAssertFalse(im.candidates.isEmpty)
        XCTAssertTrue(im.candidates.map(\.text).contains("今日"))
    }

    func testTypingPartialRomajiHasNoCandidates() async {
        let im = makeManagerWithAdapter()
        im.appendRomaji("k")
        XCTAssertTrue(im.isComposing)
        XCTAssertEqual(im.displayKana, "k")
        await im.currentConversionTask()?.value
        XCTAssertTrue(im.candidates.isEmpty)
    }

    func testBackspaceShortensComposition() async {
        let im = makeManagerWithAdapter()
        for ch in "kyou" {
            im.appendRomaji(ch)
        }
        await im.currentConversionTask()?.value
        XCTAssertEqual(im.displayKana, "きょう")
        XCTAssertTrue(im.backspace())
        XCTAssertEqual(im.displayKana, "きょ")
    }

    func testResetClearsState() async {
        let im = makeManagerWithAdapter()
        for ch in "kyou" {
            im.appendRomaji(ch)
        }
        await im.currentConversionTask()?.value
        im.reset()
        XCTAssertFalse(im.isComposing)
        XCTAssertEqual(im.displayKana, "")
        XCTAssertTrue(im.candidates.isEmpty)
        XCTAssertEqual(im.markedText, "")
    }

    func testMarkedTextStaysAsKanaAfterConversion() async {
        let im = makeManagerWithAdapter()
        for ch in "kyou" {
            im.appendRomaji(ch)
        }
        XCTAssertEqual(im.markedText, "きょう")
        await im.currentConversionTask()?.value
        XCTAssertFalse(im.candidates.isEmpty)
        XCTAssertEqual(im.markedText, "きょう")
    }

    func testCallbackFiresOnTyping() {
        let im = InputManager()
        var notified: [String] = []
        im.onMarkedTextDidChange = { notified.append($0) }
        im.appendRomaji("k")
        XCTAssertEqual(notified, ["k"])
        im.appendRomaji("o")
        XCTAssertEqual(notified, ["k", "こ"])
    }

    // Space (次候補): selects the first candidate, then advances.
    func testSelectNextCandidateCycles() async {
        let im = makeManagerWithAdapter()
        for ch in "kyou" {
            im.appendRomaji(ch)
        }
        await im.currentConversionTask()?.value
        XCTAssertNil(im.selectedCandidateIndex)
        XCTAssertEqual(im.markedText, "きょう")

        im.selectNextCandidate()
        XCTAssertEqual(im.selectedCandidateIndex, 0)
        XCTAssertEqual(im.markedText, im.candidates[0].text)

        im.selectNextCandidate()
        XCTAssertEqual(im.selectedCandidateIndex, 1)
        XCTAssertEqual(im.markedText, im.candidates[1].text)
    }

    // Return when no candidate cycled: commit text is the raw kana, not the
    // top kanji guess. Matches native 確定 behavior.
    func testCommitTextIsKanaWhenNoSelection() async {
        let im = makeManagerWithAdapter()
        for ch in "kyou" {
            im.appendRomaji(ch)
        }
        await im.currentConversionTask()?.value
        XCTAssertFalse(im.candidates.isEmpty)
        XCTAssertNil(im.selectedCandidateIndex)
        XCTAssertEqual(im.commitText, "きょう")
    }

    // Return after cycling: commit text is the selected candidate.
    func testCommitTextIsSelectedCandidate() async {
        let im = makeManagerWithAdapter()
        for ch in "kyou" {
            im.appendRomaji(ch)
        }
        await im.currentConversionTask()?.value
        im.selectNextCandidate()
        XCTAssertEqual(im.commitText, im.candidates[0].text)
    }

    // Backspace first cancels candidate selection (reverts marked text to
    // kana); only a second backspace shrinks the buffer.
    func testBackspaceCancelsSelectionFirst() async {
        let im = makeManagerWithAdapter()
        for ch in "kyou" {
            im.appendRomaji(ch)
        }
        await im.currentConversionTask()?.value
        im.selectNextCandidate()
        XCTAssertNotNil(im.selectedCandidateIndex)

        XCTAssertTrue(im.backspace())
        XCTAssertNil(im.selectedCandidateIndex)
        XCTAssertEqual(im.markedText, "きょう")
        XCTAssertEqual(im.displayKana, "きょう")

        XCTAssertTrue(im.backspace())
        XCTAssertEqual(im.displayKana, "きょ")
    }

    // Typing more romaji clears selection; new keystrokes are not committed
    // against a stale candidate.
    func testAppendRomajiResetsSelection() async {
        let im = makeManagerWithAdapter()
        for ch in "kyou" {
            im.appendRomaji(ch)
        }
        await im.currentConversionTask()?.value
        im.selectNextCandidate()
        XCTAssertNotNil(im.selectedCandidateIndex)

        im.appendRomaji("a")
        XCTAssertNil(im.selectedCandidateIndex)
    }
}
