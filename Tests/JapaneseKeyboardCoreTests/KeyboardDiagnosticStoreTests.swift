import Foundation
import XCTest
import KeyboardPreferences

final class KeyboardDiagnosticStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        suite = "KeyboardDiagnosticsTests.\(UUID())"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    func testDrainPreservesNewlyAppendedEventsAndOccurrenceTime() {
        let occurred = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set("account-a", forKey: KeyboardDiagnosticStore.identityKey)
        KeyboardDiagnosticStore.record("ai_rewrite_attempt_blocked", properties: ["readiness_blocker": "full_access_required"], defaults: defaults, now: occurred)
        let pending = KeyboardDiagnosticStore.pending(defaults: defaults)
        KeyboardDiagnosticStore.record("ai_rewrite_attempted", properties: [:], defaults: defaults, now: occurred.addingTimeInterval(1))
        KeyboardDiagnosticStore.acknowledge(pending[0], defaults: defaults)
        XCTAssertEqual(pending[0].occurredAt, occurred)
        XCTAssertEqual(KeyboardDiagnosticStore.pending(defaults: defaults).count, 1)
        XCTAssertEqual(KeyboardDiagnosticStore.pending(defaults: defaults)[0].name, "ai_rewrite_attempted")
    }

    func testAccountSwitchDoesNotReassignPendingEvents() {
        defaults.set("account-a", forKey: KeyboardDiagnosticStore.identityKey)
        KeyboardDiagnosticStore.record("ai_rewrite_replacement", properties: ["event_id": "generation-a"], defaults: defaults)
        defaults.set("account-b", forKey: KeyboardDiagnosticStore.identityKey)
        let event = KeyboardDiagnosticStore.pending(defaults: defaults)[0]
        XCTAssertEqual(event.distinctId, "account-a")
        XCTAssertEqual(event.properties["event_id"], "generation-a")
    }

    func testMissingIdentityStaysUnattributed() {
        KeyboardDiagnosticStore.record("ai_rewrite_attempted", properties: [:], defaults: defaults)
        defaults.set("later-account", forKey: KeyboardDiagnosticStore.identityKey)
        XCTAssertNil(KeyboardDiagnosticStore.pending(defaults: defaults)[0].distinctId)
    }

    func testBoundedQueueRetainsLatestEvents() {
        let now = Date()
        for i in 0...KeyboardDiagnosticStore.limit {
            KeyboardDiagnosticStore.record("ai_rewrite_attempted", properties: ["attempt_id": String(i)], defaults: defaults, now: now.addingTimeInterval(Double(i)))
        }
        let events = KeyboardDiagnosticStore.pending(defaults: defaults)
        XCTAssertEqual(events.count, KeyboardDiagnosticStore.limit)
        XCTAssertEqual(events.first?.properties["attempt_id"], "1")
        XCTAssertEqual(events.last?.properties["attempt_id"], String(KeyboardDiagnosticStore.limit))
        XCTAssertEqual(Set(events.map(\.id)).count, KeyboardDiagnosticStore.limit)
    }
}
