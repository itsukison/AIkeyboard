import XCTest
@testable import JapaneseKeyboardCore

final class KanaKanjiAdapterTests: XCTestCase {

    private static let adapter = KanaKanjiAdapter()

    // The adapter is shared (static) for speed, so it carries the converter's
    // incremental lattice state between tests. Reset it after each test so a
    // test that re-converts the same kana as the previous one doesn't hit the
    // converter's zero-diff cache-restore path — mirrors production, which
    // calls stopComposition() on every commit.
    override func tearDown() async throws {
        await Self.adapter.stopComposition()
    }

    func testEmptyKanaReturnsEmpty() async {
        let results = await Self.adapter.convert(kana: "")
        XCTAssertEqual(results.count, 0)
    }

    func testKyouProducesKanji() async {
        let results = await Self.adapter.convert(kana: "きょう", maxCandidates: 10)
        XCTAssertFalse(results.isEmpty, "Expected at least one candidate for きょう")
        let texts = results.map(\.text)
        XCTAssertTrue(texts.contains("今日"), "Expected 今日 in candidates: \(texts)")
    }

    func testArigatouProducesKanji() async {
        let results = await Self.adapter.convert(kana: "ありがとう", maxCandidates: 10)
        XCTAssertFalse(results.isEmpty)
        let texts = results.map(\.text)
        XCTAssertTrue(
            texts.contains("ありがとう") || texts.contains("有難う") || texts.contains("有り難う"),
            "Expected ありがとう / 有難う in candidates: \(texts)"
        )
    }

    func testKonnichihaProducesGreeting() async {
        let results = await Self.adapter.convert(kana: "こんにちは", maxCandidates: 10)
        XCTAssertFalse(results.isEmpty)
        let texts = results.map(\.text)
        XCTAssertTrue(
            texts.contains("こんにちは") || texts.contains("今日は"),
            "Expected こんにちは / 今日は in candidates: \(texts)"
        )
    }

    func testRawKanaIsAlwaysIncluded() async {
        let results = await Self.adapter.convert(kana: "きょう", maxCandidates: 10)
        XCTAssertTrue(
            results.contains(where: { $0.text == "きょう" }),
            "Raw kana should always be in candidate list"
        )
    }
}
