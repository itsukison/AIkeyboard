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

    func testUsageStatsRecordAcceptedRewriteIncrementsTotalAndStartsStreak() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)

        let snapshot = KeyboardUsageStatsStore.recordAcceptedRewrite(defaults: defaults, now: now)

        XCTAssertEqual(snapshot.conversionsTotal, 1)
        XCTAssertEqual(snapshot.streakDays, 1)
        XCTAssertEqual(KeyboardUsageStatsStore.snapshot(defaults: defaults, now: now), snapshot)
    }

    func testUsageStatsSameDayKeepsSingleStreakDay() {
        let first = Date(timeIntervalSince1970: 1_780_000_000)
        let second = first.addingTimeInterval(60 * 60)

        _ = KeyboardUsageStatsStore.recordAcceptedRewrite(defaults: defaults, now: first)
        let snapshot = KeyboardUsageStatsStore.recordAcceptedRewrite(defaults: defaults, now: second)

        XCTAssertEqual(snapshot.conversionsTotal, 2)
        XCTAssertEqual(snapshot.streakDays, 1)
    }

    func testUsageStatsNextDayAdvancesStreak() {
        let first = Date(timeIntervalSince1970: 1_780_000_000)
        let second = first.addingTimeInterval(60 * 60 * 24)

        _ = KeyboardUsageStatsStore.recordAcceptedRewrite(defaults: defaults, now: first)
        let snapshot = KeyboardUsageStatsStore.recordAcceptedRewrite(defaults: defaults, now: second)

        XCTAssertEqual(snapshot.conversionsTotal, 2)
        XCTAssertEqual(snapshot.streakDays, 2)
    }

    func testUsageStatsSnapshotExpiresStaleStreak() {
        let first = Date(timeIntervalSince1970: 1_780_000_000)
        let stale = first.addingTimeInterval(60 * 60 * 24 * 2)

        _ = KeyboardUsageStatsStore.recordAcceptedRewrite(defaults: defaults, now: first)
        let snapshot = KeyboardUsageStatsStore.snapshot(defaults: defaults, now: stale)

        XCTAssertEqual(snapshot.conversionsTotal, 1)
        XCTAssertEqual(snapshot.streakDays, 0)
    }
}
