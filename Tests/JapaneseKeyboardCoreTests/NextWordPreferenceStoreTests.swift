import XCTest
@testable import KeyboardPreferences

final class NextWordPreferenceStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "NextWordPreferenceStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRecordTransitionIncrementsExistingEntry() {
        let first = Date(timeIntervalSince1970: 1_000)
        let second = Date(timeIntervalSince1970: 2_000)

        NextWordPreferenceStore.recordTransition(previous: "食べたい", next: "ラーメン", defaults: defaults, now: first)
        NextWordPreferenceStore.recordTransition(previous: "食べたい", next: "ラーメン", defaults: defaults, now: second)

        let entries = NextWordPreferenceStore.readEntries(defaults: defaults)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].acceptedCount, 2)
        XCTAssertEqual(entries[0].lastUsedAt, second)
    }

    func testSuggestionsRankByCountThenRecency() {
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 5_000)

        // "ラーメン" typed twice, "そば" once (but more recently).
        NextWordPreferenceStore.recordTransition(previous: "食べたい", next: "ラーメン", defaults: defaults, now: early)
        NextWordPreferenceStore.recordTransition(previous: "食べたい", next: "ラーメン", defaults: defaults, now: early)
        NextWordPreferenceStore.recordTransition(previous: "食べたい", next: "そば", defaults: defaults, now: late)

        let suggestions = NextWordPreferenceStore.suggestions(after: "食べたい", defaults: defaults)
        XCTAssertEqual(suggestions, ["ラーメン", "そば"])
    }

    func testSuggestionsScopedToPreviousWord() {
        NextWordPreferenceStore.recordTransition(previous: "食べたい", next: "ラーメン", defaults: defaults)
        NextWordPreferenceStore.recordTransition(previous: "飲みたい", next: "ビール", defaults: defaults)

        XCTAssertEqual(NextWordPreferenceStore.suggestions(after: "食べたい", defaults: defaults), ["ラーメン"])
        XCTAssertEqual(NextWordPreferenceStore.suggestions(after: "飲みたい", defaults: defaults), ["ビール"])
        XCTAssertEqual(NextWordPreferenceStore.suggestions(after: "知らない", defaults: defaults), [])
    }

    func testSuggestionsRespectLimit() {
        for next in ["ラーメン", "そば", "うどん", "カレー"] {
            NextWordPreferenceStore.recordTransition(previous: "食べたい", next: next, defaults: defaults)
        }
        let suggestions = NextWordPreferenceStore.suggestions(after: "食べたい", limit: 2, defaults: defaults)
        XCTAssertEqual(suggestions.count, 2)
    }

    func testEmptyKeysAreIgnored() {
        NextWordPreferenceStore.recordTransition(previous: "  ", next: "ラーメン", defaults: defaults)
        NextWordPreferenceStore.recordTransition(previous: "食べたい", next: "  ", defaults: defaults)
        XCTAssertTrue(NextWordPreferenceStore.readEntries(defaults: defaults).isEmpty)
    }
}
