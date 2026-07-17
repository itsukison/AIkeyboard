import XCTest
@testable import KeyboardPreferences

final class AppUpdateNudgeTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AppUpdateNudgeTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testVersionCompare() {
        XCTAssertTrue(AppUpdateNudge.isVersion("1.0.10", newerThan: "1.0.9"))
        XCTAssertTrue(AppUpdateNudge.isVersion("1.1", newerThan: "1.0.9"))
        XCTAssertTrue(AppUpdateNudge.isVersion("2.0", newerThan: "1.9.9"))
        XCTAssertFalse(AppUpdateNudge.isVersion("1.0.9", newerThan: "1.0.9"))
        XCTAssertFalse(AppUpdateNudge.isVersion("1.0", newerThan: "1.0.0"))
        XCTAssertFalse(AppUpdateNudge.isVersion("1.0.9", newerThan: "1.0.10"))
    }

    func testNoRelayedVersionShowsNoNudge() {
        XCTAssertFalse(AppUpdateNudge.shouldShowNudge(currentVersion: "1.0.9", defaults: defaults))
    }

    func testNewerRelayedVersionShowsNudge() {
        AppUpdateNudge.writeAvailableVersion("1.0.10", defaults: defaults)

        XCTAssertTrue(AppUpdateNudge.shouldShowNudge(currentVersion: "1.0.9", defaults: defaults))
    }

    func testNudgeSelfClearsOnceInstalledVersionCatchesUp() {
        AppUpdateNudge.writeAvailableVersion("1.0.10", defaults: defaults)

        XCTAssertFalse(AppUpdateNudge.shouldShowNudge(currentVersion: "1.0.10", defaults: defaults))
        XCTAssertFalse(AppUpdateNudge.shouldShowNudge(currentVersion: "1.0.11", defaults: defaults))
    }

    func testDismissedVersionSilencesNudge() {
        AppUpdateNudge.writeAvailableVersion("1.0.10", defaults: defaults)
        AppUpdateNudge.writeDismissedVersion("1.0.10", defaults: defaults)

        XCTAssertFalse(AppUpdateNudge.shouldShowNudge(currentVersion: "1.0.9", defaults: defaults))
    }

    func testDismissalOfOlderVersionDoesNotSilenceNewerRelay() {
        AppUpdateNudge.writeDismissedVersion("1.0.10", defaults: defaults)
        AppUpdateNudge.writeAvailableVersion("1.0.11", defaults: defaults)

        XCTAssertTrue(AppUpdateNudge.shouldShowNudge(currentVersion: "1.0.9", defaults: defaults))
    }
}
