import XCTest
@testable import JapaneseKeyboardCore

final class EnglishSuggestionEngineTests: XCTestCase {
    // MARK: Bundled tables

    func testBundledEnglishTablesLoad() {
        XCTAssertNotNil(NextWordPrior.englishUnigram, "english_unigram.bin should load")
        XCTAssertNotNil(NextWordPrior.englishBigram, "english_bigram.bin should load")
    }

    func testCompletionRanksFrequentWordsFirst() {
        let completions = EnglishSuggestionEngine.completions(forPartialWord: "th", limit: 6)
        XCTAssertFalse(completions.isEmpty)
        // "the" is the most frequent English word; it must lead "th…" completions.
        XCTAssertEqual(completions.first, "the", "got \(completions)")
        XCTAssertTrue(completions.contains("that") || completions.contains("this"))
    }

    func testCompletionIsCaseInsensitiveOnInput() {
        XCTAssertEqual(
            EnglishSuggestionEngine.completions(forPartialWord: "TH", limit: 3),
            EnglishSuggestionEngine.completions(forPartialWord: "th", limit: 3)
        )
    }

    func testNextWordAfterCommonWord() {
        let next = EnglishSuggestionEngine.nextWords(after: "thank", limit: 4)
        // "thank you" dominates the bigram table.
        XCTAssertTrue(next.contains("you"), "got \(next)")
    }

    // MARK: Correction

    func testCorrectsCommonTypos() {
        XCTAssertEqual(EnglishSuggestionEngine.correction(for: "teh"), "the")
        XCTAssertEqual(EnglishSuggestionEngine.correction(for: "adn"), "and")
        XCTAssertEqual(EnglishSuggestionEngine.correction(for: "recieve"), "receive")
    }

    func testKnownWordIsNotCorrected() {
        XCTAssertNil(EnglishSuggestionEngine.correction(for: "the"))
        XCTAssertNil(EnglishSuggestionEngine.correction(for: "hello"))
    }

    func testNonAlphabeticIsNotCorrected() {
        XCTAssertNil(EnglishSuggestionEngine.correction(for: "a1b2"))
        XCTAssertNil(EnglishSuggestionEngine.correction(for: "x"))
    }

    // MARK: Deterministic ranking against a synthetic unigram table

    func testCompletionRankingByWeightThenLength() throws {
        // Same UTF-8-sorted NWP1 layout the build script emits: value = one entry
        // (empty next, weight). Higher weight wins; ties break shorter-first.
        let url = try makeUnigram([
            ("car", 200),
            ("care", 200),
            ("cargo", 90),
            ("cat", 255),
        ])
        defer { try? FileManager.default.removeItem(at: url) }
        guard let table = NextWordPrior(url: url) else {
            return XCTFail("synthetic table should load")
        }
        XCTAssertEqual(table.completions(prefix: "ca", limit: 4), ["cat", "car", "care", "cargo"])
        XCTAssertEqual(table.completions(prefix: "car", limit: 4), ["car", "care", "cargo"])
        XCTAssertEqual(table.weight(for: "cat"), 255)
        XCTAssertNil(table.weight(for: "dog"))
    }

    /// Serialize a unigram NWP1 table: key=word, value=(empty next, weight).
    private func makeUnigram(_ pairs: [(String, Int)]) throws -> URL {
        let sorted = pairs.sorted { Array($0.0.utf8).lexicographicallyPrecedes(Array($1.0.utf8)) }
        var keysBlob = [UInt8]()
        var valsBlob = [UInt8]()
        var keyMeta: [(Int, Int)] = []
        var valMeta: [Int] = []
        for (key, weight) in sorted {
            let kb = Array(key.utf8)
            keyMeta.append((keysBlob.count, kb.count))
            keysBlob += kb
            let start = valsBlob.count
            valsBlob.append(0)               // nextLen = 0 (empty next)
            valsBlob.append(UInt8(weight))   // weight
            valMeta.append(valsBlob.count - start)
        }
        let count = sorted.count
        let keysBase = 8 + count * 12
        let valsBase = keysBase + keysBlob.count
        func le32(_ v: Int) -> [UInt8] { (0..<4).map { UInt8((v >> ($0 * 8)) & 0xff) } }
        func le16(_ v: Int) -> [UInt8] { (0..<2).map { UInt8((v >> ($0 * 8)) & 0xff) } }
        var bytes = Array("NWP1".utf8) + le32(count)
        var voff = 0
        for ((koff, klen), vlen) in zip(keyMeta, valMeta) {
            bytes += le32(keysBase + koff) + le16(klen) + le32(valsBase + voff) + le16(vlen)
            voff += vlen
        }
        bytes += keysBlob + valsBlob
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("unigram-test-\(UUID().uuidString).bin")
        try Data(bytes).write(to: url)
        return url
    }
}
