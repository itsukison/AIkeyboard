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

    /// A center tap: press and release without moving. Flick input is live, so
    /// every character goes in on touch-down and settles on touch-up.
    private func tap(_ im: InputManager, _ key: FlickKanaTable.FlickKey, now: Date) {
        im.beginFlickInput(key, now: now)
        im.endFlickInput()
    }

    /// A flick: press, move onto `direction`, release.
    private func flick(
        _ im: InputManager,
        _ key: FlickKanaTable.FlickKey,
        _ direction: FlickKanaTable.FlickDirection,
        now: Date
    ) {
        im.beginFlickInput(key, now: now)
        im.updateFlickInput(key, direction: direction)
        im.endFlickInput()
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

    func testTapCycleReplacesLastKanaWithinTimeout() {
        let im = InputManager(buffer: KanaInputBuffer())
        let start = Date(timeIntervalSince1970: 1_000)
        tap(im, FlickKanaTable.a, now: start)
        XCTAssertEqual(im.displayKana, "あ")
        tap(im, FlickKanaTable.a, now: start.addingTimeInterval(0.2))
        XCTAssertEqual(im.displayKana, "い")
        tap(im, FlickKanaTable.a, now: start.addingTimeInterval(0.4))
        XCTAssertEqual(im.displayKana, "う")
    }

    func testTapCycleAfterTimeoutStartsNewKana() {
        let im = InputManager(buffer: KanaInputBuffer())
        let start = Date(timeIntervalSince1970: 1_000)
        tap(im, FlickKanaTable.a, now: start)
        tap(im, FlickKanaTable.a, now: start.addingTimeInterval(0.9))
        XCTAssertEqual(im.displayKana, "ああ")
    }

    func testTapCycleDifferentKeyAppends() {
        let im = InputManager(buffer: KanaInputBuffer())
        let start = Date(timeIntervalSince1970: 1_000)
        tap(im, FlickKanaTable.a, now: start)
        tap(im, FlickKanaTable.ka, now: start.addingTimeInterval(0.2))
        XCTAssertEqual(im.displayKana, "あか")
    }

    func testTapCycleWraps() {
        let im = InputManager(buffer: KanaInputBuffer())
        let start = Date(timeIntervalSince1970: 1_000)
        for offset in stride(from: 0.0, through: 1.0, by: 0.2) {
            tap(im, FlickKanaTable.a, now: start.addingTimeInterval(offset))
        }
        XCTAssertEqual(im.displayKana, "あ")
    }

    func testDirectKanaAppendResetsTapCycle() {
        let im = InputManager(buffer: KanaInputBuffer())
        let start = Date(timeIntervalSince1970: 1_000)
        tap(im, FlickKanaTable.a, now: start)
        im.appendKana("お")
        tap(im, FlickKanaTable.a, now: start.addingTimeInterval(0.2))
        XCTAssertEqual(im.displayKana, "あおあ")
    }

    func testBackspaceResetsTapCycle() {
        let im = InputManager(buffer: KanaInputBuffer())
        let start = Date(timeIntervalSince1970: 1_000)
        tap(im, FlickKanaTable.a, now: start)
        XCTAssertTrue(im.backspace())
        tap(im, FlickKanaTable.a, now: start.addingTimeInterval(0.2))
        XCTAssertEqual(im.displayKana, "あ")
    }

    func testToggleLastKanaResetsTapCycle() {
        let im = InputManager(buffer: KanaInputBuffer())
        let start = Date(timeIntervalSince1970: 1_000)
        tap(im, FlickKanaTable.ta, now: start)
        tap(im, FlickKanaTable.ta, now: start.addingTimeInterval(0.2))
        XCTAssertEqual(im.displayKana, "ち")
        im.toggleLastKanaCharacterType()
        XCTAssertEqual(im.displayKana, "ぢ")
        tap(im, FlickKanaTable.ta, now: start.addingTimeInterval(0.4))
        XCTAssertEqual(im.displayKana, "ぢた")
    }

    // MARK: - Live flick input

    func testCharacterEntersTheCompositionOnTouchDown() {
        let im = InputManager(buffer: KanaInputBuffer())
        im.beginFlickInput(FlickKanaTable.a, now: Date(timeIntervalSince1970: 1_000))

        // Still under the finger — but already composing and already visible.
        XCTAssertTrue(im.isComposing)
        XCTAssertEqual(im.displayKana, "あ")
    }

    func testMovingBetweenDirectionsReplacesInPlace() {
        let im = InputManager(buffer: KanaInputBuffer())
        let key = FlickKanaTable.a
        im.beginFlickInput(key, now: Date(timeIntervalSince1970: 1_000))

        im.updateFlickInput(key, direction: .left)
        XCTAssertEqual(im.displayKana, "い")
        im.updateFlickInput(key, direction: .right)
        XCTAssertEqual(im.displayKana, "え")
        // Back to the center tile restores the touch-down character.
        im.updateFlickInput(key, direction: nil)
        XCTAssertEqual(im.displayKana, "あ")

        im.endFlickInput()
        XCTAssertEqual(im.displayKana, "あ")
    }

    func testCentreTileRestoresTheTapCyclePositionNotTheKeyCentre() {
        let im = InputManager(buffer: KanaInputBuffer())
        let key = FlickKanaTable.a
        let start = Date(timeIntervalSince1970: 1_000)
        tap(im, key, now: start)

        // Second press advances the cycle to い; sliding out to お and back
        // must return to い, not to あ.
        im.beginFlickInput(key, now: start.addingTimeInterval(0.2))
        XCTAssertEqual(im.displayKana, "い")
        im.updateFlickInput(key, direction: .bottom)
        XCTAssertEqual(im.displayKana, "お")
        im.updateFlickInput(key, direction: nil)
        XCTAssertEqual(im.displayKana, "い")
        im.endFlickInput()
    }

    func testFlickEndsTheTapCycleSoTheNextPressStartsANewKana() {
        let im = InputManager(buffer: KanaInputBuffer())
        let key = FlickKanaTable.a
        let start = Date(timeIntervalSince1970: 1_000)

        flick(im, key, .left, now: start)
        XCTAssertEqual(im.displayKana, "い")
        tap(im, key, now: start.addingTimeInterval(0.2))
        XCTAssertEqual(im.displayKana, "いあ")
    }

    func testCancelledTouchTakesTheProvisionalCharacterBackOut() {
        let im = InputManager(buffer: KanaInputBuffer())
        let key = FlickKanaTable.ka
        im.appendKana("あ")

        im.beginFlickInput(key, now: Date(timeIntervalSince1970: 1_000))
        im.updateFlickInput(key, direction: .top)
        XCTAssertEqual(im.displayKana, "あく")

        im.cancelFlickInput()
        XCTAssertEqual(im.displayKana, "あ")
    }

    func testCancelledTapCycleAdvanceRestoresThePreviousKana() {
        let im = InputManager(buffer: KanaInputBuffer())
        let key = FlickKanaTable.a
        let start = Date(timeIntervalSince1970: 1_000)
        tap(im, key, now: start)

        // This press consumed あ to show い; cancelling must not lose あ.
        im.beginFlickInput(key, now: start.addingTimeInterval(0.2))
        XCTAssertEqual(im.displayKana, "い")
        im.cancelFlickInput()
        XCTAssertEqual(im.displayKana, "あ")
    }

    func testConversionIsDeferredUntilTheFingerLifts() async {
        let im = makeManagerWithAdapter()
        let key = FlickKanaTable.ka

        im.beginFlickInput(key, now: Date(timeIntervalSince1970: 1_000))
        im.updateFlickInput(key, direction: .left)
        // Nothing scheduled while the finger is down, however many directions
        // it passes through.
        XCTAssertNil(im.currentConversionTask())

        im.endFlickInput()
        await im.currentConversionTask()?.value
        XCTAssertFalse(im.candidates.isEmpty)
    }

    func testMarkedTextUpdatesWhileTheFingerIsStillDown() {
        let im = InputManager(buffer: KanaInputBuffer())
        let key = FlickKanaTable.a
        var notified: [String] = []
        im.onMarkedTextDidChange = { notified.append($0) }

        im.beginFlickInput(key, now: Date(timeIntervalSince1970: 1_000))
        im.updateFlickInput(key, direction: .left)
        im.endFlickInput()

        XCTAssertEqual(notified, ["あ", "い"])
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

    func testCallbackFiresOnTapCycleReplacement() {
        let im = InputManager(buffer: KanaInputBuffer())
        let start = Date(timeIntervalSince1970: 1_000)
        var notified: [String] = []
        im.onMarkedTextDidChange = { notified.append($0) }
        tap(im, FlickKanaTable.a, now: start)
        tap(im, FlickKanaTable.a, now: start.addingTimeInterval(0.2))
        XCTAssertEqual(notified, ["あ", "い"])
    }
}
