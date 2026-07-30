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

    // The expanded grid's data source: the full mainResults of the last
    // conversion, which the bar's maxCandidates slice was cut from. Must be
    // strictly deeper than the slice, deduplicated, include the raw kana,
    // and report the kana it was converted from (staleness check).
    func testAllCandidatesFromLastConversionExceedsBarSlice() async {
        let barResults = await Self.adapter.convert(kana: "きょう", maxCandidates: 20)
        let full = await Self.adapter.allCandidatesFromLastConversion()
        XCTAssertNotNil(full)
        guard let full else { return }
        XCTAssertEqual(full.kana, "きょう")
        XCTAssertGreaterThan(
            full.candidates.count, barResults.count,
            "Full list should be deeper than the bar's slice"
        )
        let texts = full.candidates.map(\.text)
        XCTAssertEqual(texts.count, Set(texts).count, "Full list must be deduplicated")
        XCTAssertTrue(texts.contains("きょう"), "Raw kana must be reachable in the grid")
    }

    func testAllCandidatesFromLastConversionIsNilBeforeAnyConversion() async {
        let freshAdapter = KanaKanjiAdapter()
        let full = await freshAdapter.allCandidatesFromLastConversion()
        XCTAssertNil(full)
    }

    // Gap-fill user dictionary (conversion_gapfill.tsv → user.louds): words
    // the bundled azooKey dictionary can't compose on its own. Also guards the
    // charID.chid bundle lookup — if that silently fails, these fail with it.
    func testGapFillWordConverts() async {
        let results = await Self.adapter.convert(kana: "なんごうしゃ", maxCandidates: 20)
        XCTAssertTrue(
            results.map(\.text).contains("何号車"),
            "Expected gap-fill entry 何号車 in candidates: \(results.map(\.text))"
        )
    }

    func testGapFillWordComposesMidSentence() async {
        let results = await Self.adapter.convert(kana: "なんごうしゃにのる", maxCandidates: 20)
        XCTAssertTrue(
            results.map(\.text).contains("何号車に乗る"),
            "Gap-fill entries must compose as lattice words: \(results.map(\.text))"
        )
    }

    func testGapFillStationNameConverts() async {
        let results = await Self.adapter.convert(kana: "きんしちょう", maxCandidates: 20)
        XCTAssertTrue(
            results.map(\.text).contains("錦糸町"),
            "Expected gap-fill station 錦糸町 in candidates: \(results.map(\.text))"
        )
    }

    func testGapFillLexicalWordConverts() async {
        let results = await Self.adapter.convert(kana: "かんこん", maxCandidates: 20)
        XCTAssertTrue(
            results.map(\.text).contains("冠婚"),
            "Expected gap-fill entry 冠婚 in candidates: \(results.map(\.text))"
        )
    }

    func testGapFillLowRankedCommonWordConverts() async {
        let results = await Self.adapter.convert(kana: "はつもう", maxCandidates: 20)
        XCTAssertTrue(
            results.map(\.text).contains("発毛"),
            "Expected promoted common word 発毛 in candidates: \(results.map(\.text))"
        )
    }

    func testGapFillPopularStationConverts() async {
        let results = await Self.adapter.convert(kana: "かみとばぐち", maxCandidates: 20)
        XCTAssertTrue(
            results.map(\.text).contains("上鳥羽口"),
            "Expected gap-fill station 上鳥羽口 in candidates: \(results.map(\.text))"
        )
    }

    func testGapFillCorrectedReadingConverts() async {
        let results = await Self.adapter.convert(kana: "こんかんちりょう", maxCandidates: 20)
        XCTAssertTrue(
            results.map(\.text).contains("根管治療"),
            "Expected corrected reading for 根管治療 in candidates: \(results.map(\.text))"
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
