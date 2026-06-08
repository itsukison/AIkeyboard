import XCTest
@testable import KeyboardPreferences

final class ConversionPreferenceStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ConversionPreferenceStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRecordSelectionIncrementsExistingEntry() {
        let first = Date(timeIntervalSince1970: 1_000)
        let second = Date(timeIntervalSince1970: 2_000)

        ConversionPreferenceStore.recordSelection(
            scope: .japanese,
            input: "きょう",
            candidate: "今日",
            defaults: defaults,
            now: first
        )
        ConversionPreferenceStore.recordSelection(
            scope: .japanese,
            input: "きょう",
            candidate: "今日",
            defaults: defaults,
            now: second
        )

        let entries = ConversionPreferenceStore.readEntries(defaults: defaults)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].acceptedCount, 2)
        XCTAssertEqual(entries[0].lastUsedAt, second)
    }

    func testRerankMovesFrequentlySelectedCandidateEarlier() {
        let now = Date()
        let entries = [
            ConversionPreferenceEntry(
                scope: .japanese,
                inputKey: "きょう",
                candidateKey: "京",
                displayText: "京",
                acceptedCount: 3,
                lastUsedAt: now,
                updatedAt: now
            )
        ]

        let ranked = ConversionPreferenceStore.rerank(
            scope: .japanese,
            input: "きょう",
            candidates: ["今日", "きょう", "京"],
            entries: entries,
            now: now
        )

        XCTAssertEqual(ranked, ["京", "今日", "きょう"])
    }
}
