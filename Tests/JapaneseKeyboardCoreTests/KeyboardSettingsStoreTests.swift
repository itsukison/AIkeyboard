import XCTest
@testable import KeyboardPreferences

final class KeyboardSettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "KeyboardSettingsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testKeyboardKeySizeDefaultsToStandard() {
        XCTAssertEqual(
            KeyboardSettingsStore.readKeyboardKeySizePreset(defaults: defaults),
            .standard
        )
    }

    func testKeyboardKeySizePresetsRoundTrip() {
        for preset in KeyboardKeySizePreset.allCases {
            KeyboardSettingsStore.writeKeyboardKeySizePreset(preset, defaults: defaults)

            XCTAssertEqual(
                KeyboardSettingsStore.readKeyboardKeySizePreset(defaults: defaults),
                preset
            )
        }
    }

    func testInvalidKeyboardKeySizeFallsBackToStandard() {
        defaults.set("invalid", forKey: KeyboardSettingsStore.keyboardKeySizePresetKey)

        XCTAssertEqual(
            KeyboardSettingsStore.readKeyboardKeySizePreset(defaults: defaults),
            .standard
        )
    }

    func testStandardKeyboardKeySizeDoesNotInsetCaps() {
        XCTAssertEqual(KeyboardKeySizePreset.standard.keyCapInsetAdjustment, 0)
    }

    func testKeyboardKeySizePresetsReduceInsetsInSliderOrder() {
        let adjustments = KeyboardKeySizePreset.allCases.map(\.keyCapInsetAdjustment)

        XCTAssertEqual(adjustments, adjustments.sorted(by: >))
        XCTAssertEqual(Set(adjustments).count, KeyboardKeySizePreset.allCases.count)
    }

    func testZenzaiEnabledDefaultsToTrue() {
        XCTAssertTrue(KeyboardSettingsStore.readZenzaiEnabled(defaults: defaults))
    }

    func testKeyClickSoundEnabledDefaultsToTrue() {
        XCTAssertTrue(KeyboardSettingsStore.readKeyClickSoundEnabled(defaults: defaults))
    }

    func testKeyClickSoundEnabledRoundTrip() {
        KeyboardSettingsStore.writeKeyClickSoundEnabled(false, defaults: defaults)
        XCTAssertFalse(KeyboardSettingsStore.readKeyClickSoundEnabled(defaults: defaults))

        KeyboardSettingsStore.writeKeyClickSoundEnabled(true, defaults: defaults)
        XCTAssertTrue(KeyboardSettingsStore.readKeyClickSoundEnabled(defaults: defaults))
    }

    func testZenzaiEnabledRoundTrip() {
        KeyboardSettingsStore.writeZenzaiEnabled(false, defaults: defaults)
        XCTAssertFalse(KeyboardSettingsStore.readZenzaiEnabled(defaults: defaults))

        KeyboardSettingsStore.writeZenzaiEnabled(true, defaults: defaults)
        XCTAssertTrue(KeyboardSettingsStore.readZenzaiEnabled(defaults: defaults))
    }

    func testZenzaiAutoDisablePersistsForSameBuild() {
        KeyboardSettingsStore.recordZenzaiAutoDisabled(build: "12", defaults: defaults)

        XCTAssertTrue(KeyboardSettingsStore.isZenzaiAutoDisabled(currentBuild: "12", defaults: defaults))
    }

    func testZenzaiAutoDisableReprobesOnNewBuild() {
        KeyboardSettingsStore.recordZenzaiAutoDisabled(build: "12", defaults: defaults)

        XCTAssertFalse(KeyboardSettingsStore.isZenzaiAutoDisabled(currentBuild: "13", defaults: defaults))
        // The stale verdict is cleared, so even the original build probes again.
        XCTAssertFalse(KeyboardSettingsStore.isZenzaiAutoDisabled(currentBuild: "12", defaults: defaults))
    }

    func testZenzaiAutoDisablePendingReportIsTakenOnce() {
        KeyboardSettingsStore.recordZenzaiAutoDisabled(build: "12", defaults: defaults)

        XCTAssertTrue(KeyboardSettingsStore.takeZenzaiAutoDisablePendingReport(defaults: defaults))
        XCTAssertFalse(KeyboardSettingsStore.takeZenzaiAutoDisablePendingReport(defaults: defaults))
    }

    func testZenzaiAutoDisableDefaultsToFalse() {
        XCTAssertFalse(KeyboardSettingsStore.isZenzaiAutoDisabled(currentBuild: "12", defaults: defaults))
    }

    func testAnalyticsAppInstanceIdRoundTrip() {
        XCTAssertNil(KeyboardSettingsStore.readAnalyticsAppInstanceId(defaults: defaults))

        KeyboardSettingsStore.writeAnalyticsAppInstanceId("analytics-instance", defaults: defaults)

        XCTAssertEqual(
            KeyboardSettingsStore.readAnalyticsAppInstanceId(defaults: defaults),
            "analytics-instance"
        )
    }

    func testPendingOnboardingPromptEntriesRoundTripAndClear() {
        let entries = UserPromptDefaults.seedEntries()

        KeyboardSettingsStore.writePendingOnboardingPromptEntries(entries, defaults: defaults)

        XCTAssertEqual(
            KeyboardSettingsStore.readPendingOnboardingPromptEntries(defaults: defaults),
            entries
        )

        KeyboardSettingsStore.clearPendingOnboardingPromptEntries(defaults: defaults)

        XCTAssertNil(KeyboardSettingsStore.readPendingOnboardingPromptEntries(defaults: defaults))
    }

    func testKeySizeObserverReadsStoreOnInit() {
        KeyboardSettingsStore.writeKeyboardKeySizePreset(.large, defaults: defaults)

        XCTAssertEqual(KeyboardKeySizeObserver(defaults: defaults).preset, .large)
    }

    func testKeySizeObserverRefreshPicksUpExternalWrite() {
        let observer = KeyboardKeySizeObserver(defaults: defaults)
        XCTAssertEqual(observer.preset, .standard)

        KeyboardSettingsStore.writeKeyboardKeySizePreset(.small, defaults: defaults)
        XCTAssertEqual(observer.preset, .standard)

        observer.refresh()
        XCTAssertEqual(observer.preset, .small)
    }
}
