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

    func testConvertWithLeftContextProducesCandidates() async {
        let results = await Self.adapter.convert(kana: "きょう", maxCandidates: 10, leftContext: "明日は雨だが、")
        XCTAssertTrue(results.map(\.text).contains("今日"), "Left context must not break conversion")
    }

    // Tapping an azooKey-born prediction must extend the chain so the next
    // prediction round still has rich morpheme context (instead of returning
    // [] as it did before recordPredictionCommit existed).
    func testPredictionChainSurvivesPredictionTap() async {
        _ = await Self.adapter.convert(kana: "きょう", maxCandidates: 10)
        let first = await Self.adapter.predictNextWords(after: "今日")
        XCTAssertFalse(first.isEmpty, "Expected next-word predictions after 今日")
        XCTAssertLessThanOrEqual(first.count, 10)

        var chained = false
        for candidate in first {
            await Self.adapter.recordPredictionCommit(candidate.text)
            let next = await Self.adapter.predictNextWords(after: candidate.text)
            if !next.isEmpty {
                chained = true
                break
            }
        }
        XCTAssertTrue(chained, "No tapped prediction produced a chained follow-up")
    }

    func testRecordPredictionCommitWithUnknownTextIsNoOp() async {
        await Self.adapter.recordPredictionCommit("存在しない候補")
        let results = await Self.adapter.predictNextWords(after: "存在しない候補")
        XCTAssertTrue(results.isEmpty)
    }

    // A commit with no rich azooKey candidate (raw-kana commit, tapped
    // corpus-prior suggestion) falls back to the bigram prior keyed on the
    // committed surface, so the bar stays populated and chains survive.
    func testFallbackPredictionForUnmatchedCommit() async {
        let results = await Self.adapter.predictNextWords(after: "はい")
        XCTAssertFalse(results.isEmpty, "Expected bigram-prior fallback for はい")
    }
}
