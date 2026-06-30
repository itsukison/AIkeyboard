import XCTest
@testable import JapaneseKeyboardCore

final class NextWordPriorTests: XCTestCase {
    func testBundledTableLoads() {
        XCTAssertNotNil(NextWordPrior.shared, "bundled nextword_prior.bin should load")
    }

    func testNaturalContinuationsAfterTai() {
        guard let prior = NextWordPrior.shared else {
            return XCTFail("prior not loaded")
        }
        // たい (auxiliary, e.g. the tail of 食べたい) → grammatical continuations,
        // never rare nouns. This is the core fix for the ラー油 complaint.
        let s = prior.suggestions(after: "たい")
        XCTAssertFalse(s.isEmpty)
        XCTAssertTrue(s.contains("です") || s.contains("と") || s.contains("の"),
                      "expected natural continuations, got \(s)")
        XCTAssertFalse(s.contains("ラー油"))
    }

    func testKanjiInitialMorphemeHits() {
        guard let prior = NextWordPrior.shared else {
            return XCTFail("prior not loaded")
        }
        // Guards the sharded-build bug: kanji-initial keys sort into a later
        // shard, so a single-shard build would miss these.
        XCTAssertFalse(prior.suggestions(after: "食べ").isEmpty)
        XCTAssertFalse(prior.suggestions(after: "行き").isEmpty)
    }

    func testMissReturnsEmpty() {
        guard let prior = NextWordPrior.shared else {
            return XCTFail("prior not loaded")
        }
        XCTAssertTrue(prior.suggestions(after: "存在しない語そのもの").isEmpty)
        XCTAssertTrue(prior.suggestions(after: "").isEmpty)
    }

    // The bundled trigram table only exists after running the build script
    // against the corpus, so exercise the composite-key lookup against a
    // synthetic table in the same NWP1 format.
    func testTrigramCompositeLookup() throws {
        let sep = "\u{1f}"
        let url = try makeTable([
            ("私\(sep)は", ["元気", "学生"]),
            ("食べ\(sep)たい", ["です", "と"]),
        ])
        defer { try? FileManager.default.removeItem(at: url) }
        guard let prior = NextWordPrior(url: url) else {
            return XCTFail("synthetic table should load")
        }
        XCTAssertEqual(prior.suggestions(after: "食べ", "たい"), ["です", "と"])
        XCTAssertEqual(prior.suggestions(after: "私", "は"), ["元気", "学生"])
        XCTAssertTrue(prior.suggestions(after: "存在", "しない").isEmpty)
        XCTAssertTrue(prior.suggestions(after: "", "は").isEmpty)
    }

    /// Serialize a tiny NWP1 table (keys sorted by UTF-8 bytes) to a temp file.
    private func makeTable(_ pairs: [(String, [String])]) throws -> URL {
        let sorted = pairs.sorted { Array($0.0.utf8).lexicographicallyPrecedes(Array($1.0.utf8)) }
        var keysBlob = [UInt8]()
        var valsBlob = [UInt8]()
        var keyMeta: [(Int, Int)] = []
        var valMeta: [Int] = []
        for (key, nexts) in sorted {
            let kb = Array(key.utf8)
            keyMeta.append((keysBlob.count, kb.count))
            keysBlob += kb
            let start = valsBlob.count
            for n in nexts {
                let nb = Array(n.utf8)
                valsBlob.append(UInt8(nb.count))
                valsBlob += nb
                valsBlob.append(1) // weight
            }
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
            .appendingPathComponent("trigram-test-\(UUID().uuidString).bin")
        try Data(bytes).write(to: url)
        return url
    }
}
