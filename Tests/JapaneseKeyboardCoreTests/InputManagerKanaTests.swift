import XCTest
import KeyboardPreferences
@testable import JapaneseKeyboardCore

@MainActor
final class InputManagerKanaTests: XCTestCase {

    private func makeManagerWithAdapter() -> InputManager {
        let im = InputManager(buffer: KanaInputBuffer())
        im.setAdapter(KanaKanjiAdapter())
        return im
    }

    func testAppendKanaBuildsComposition() {
        let im = InputManager(buffer: KanaInputBuffer())
        im.appendKana("あ")
        XCTAssertTrue(im.isComposing)
        XCTAssertEqual(im.displayKana, "あ")
    }

    func testAppendMultipleKana() {
        let im = InputManager(buffer: KanaInputBuffer())
        im.appendKana("き")
        im.appendKana("ょ")
        im.appendKana("う")
        XCTAssertEqual(im.displayKana, "きょう")
    }

    func testTypingKyouProducesCandidates() async {
        let im = makeManagerWithAdapter()
        im.appendKana("き")
        im.appendKana("ょ")
        im.appendKana("う")
        await im.currentConversionTask()?.value
        XCTAssertFalse(im.candidates.isEmpty)
        XCTAssertTrue(im.candidates.map(\.text).contains("今日"))
    }

    func testCommitTextIsKanaWhenNoSelection() async {
        let im = makeManagerWithAdapter()
        im.appendKana("き")
        im.appendKana("ょ")
        im.appendKana("う")
        await im.currentConversionTask()?.value
        XCTAssertEqual(im.commitText, "きょう")
    }

    func testBackspaceShortensComposition() async {
        let im = makeManagerWithAdapter()
        im.appendKana("き")
        im.appendKana("ょ")
        im.appendKana("う")
        await im.currentConversionTask()?.value
        XCTAssertTrue(im.backspace())
        XCTAssertEqual(im.displayKana, "きょ")
    }

    func testBackspaceOnEmptyReturnsFalse() {
        let im = InputManager(buffer: KanaInputBuffer())
        XCTAssertFalse(im.backspace())
    }

    func testResetClearsState() async {
        let im = makeManagerWithAdapter()
        im.appendKana("あ")
        await im.currentConversionTask()?.value
        im.reset()
        XCTAssertFalse(im.isComposing)
        XCTAssertEqual(im.displayKana, "")
        XCTAssertTrue(im.candidates.isEmpty)
    }

    func testSelectNextCandidateCycles() async {
        let im = makeManagerWithAdapter()
        im.appendKana("き")
        im.appendKana("ょ")
        im.appendKana("う")
        await im.currentConversionTask()?.value
        XCTAssertNil(im.selectedCandidateIndex)
        im.selectNextCandidate()
        XCTAssertEqual(im.selectedCandidateIndex, 0)
        XCTAssertEqual(im.markedText, im.candidates[0].text)
    }

    func testToggleDakutenOnKa() {
        let im = InputManager(buffer: KanaInputBuffer())
        im.appendKana("か")
        im.toggleLastKanaCharacterType()
        XCTAssertEqual(im.displayKana, "が")
    }

    func testToggleHaRowCycles() {
        let im = InputManager(buffer: KanaInputBuffer())
        im.appendKana("は")
        im.toggleLastKanaCharacterType()
        XCTAssertEqual(im.displayKana, "ば")
        im.toggleLastKanaCharacterType()
        XCTAssertEqual(im.displayKana, "ぱ")
        im.toggleLastKanaCharacterType()
        XCTAssertEqual(im.displayKana, "は")
    }

    func testToggleSmallKana() {
        let im = InputManager(buffer: KanaInputBuffer())
        im.appendKana("つ")
        im.toggleLastKanaCharacterType()
        XCTAssertEqual(im.displayKana, "っ")
        im.toggleLastKanaCharacterType()
        XCTAssertEqual(im.displayKana, "つ")
    }

    func testToggleOnEmptyIsNoOp() {
        let im = InputManager(buffer: KanaInputBuffer())
        im.toggleLastKanaCharacterType()
        XCTAssertEqual(im.displayKana, "")
    }

    func testToggleOnKanaWithNoAlternateIsNoOp() {
        let im = InputManager(buffer: KanaInputBuffer())
        im.appendKana("ん")
        im.toggleLastKanaCharacterType()
        XCTAssertEqual(im.displayKana, "ん")
    }

    func testToggleAfterMultipleKanaTogglesLastOnly() {
        let im = InputManager(buffer: KanaInputBuffer())
        im.appendKana("き")
        im.appendKana("ょ")
        im.appendKana("う")
        im.toggleLastKanaCharacterType()
        XCTAssertEqual(im.displayKana, "きょう".dropLast() + "ぅ")
    }

    func testCallbackFiresOnKanaInput() {
        let im = InputManager(buffer: KanaInputBuffer())
        var notified: [String] = []
        im.onMarkedTextDidChange = { notified.append($0) }
        im.appendKana("あ")
        XCTAssertEqual(notified, ["あ"])
        im.appendKana("い")
        XCTAssertEqual(notified, ["あ", "あい"])
    }
}
