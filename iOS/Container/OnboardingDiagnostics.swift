import KeyboardKit
import KeyboardPreferences
import Foundation

enum OnboardingDiagnostics {
    static let attemptKey = "analytics.onboardingAttemptId"
    private static let entryKey = "analytics.onboardingStepEntryId"
    private static let stepKey = "analytics.onboardingStep"
    private static let enteredAtKey = "analytics.onboardingStepEnteredAt"

    static func startAttempt() {
        UserDefaults.standard.set(UUID().uuidString.lowercased(), forKey: attemptKey)
        UserDefaults.standard.removeObject(forKey: stepKey)
        KeyboardSettingsStore.sharedDefaults?.set(UserDefaults.standard.string(forKey: attemptKey),
                                                  forKey: KeyboardDiagnosticStore.onboardingAttemptKey)
    }

    static var context: [String: Any] {
        guard UserDefaults.standard.string(forKey: attemptKey) != nil else { return [:] }
        var values: [String: Any] = ["onboarding_version": InteractiveOnboardingState.version]
        if let id = UserDefaults.standard.string(forKey: attemptKey) { values["onboarding_attempt_id"] = id }
        if let id = UserDefaults.standard.string(forKey: entryKey) { values["step_entry_id"] = id }
        return values
    }

    static func enter(_ step: String) {
        if UserDefaults.standard.string(forKey: attemptKey) == nil { startAttempt() }
        let resumedEntry = UserDefaults.standard.string(forKey: stepKey) == nil
            ? nil : UserDefaults.standard.string(forKey: entryKey)
        UserDefaults.standard.set(step, forKey: stepKey)
        UserDefaults.standard.set(UUID().uuidString.lowercased(), forKey: entryKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: enteredAtKey)
        capture("onboarding_step_entered", step: step,
                properties: resumedEntry.map { ["resumed_from_entry_id": $0] } ?? [:])
    }

    static func exit(_ outcome: String, detected: Bool? = nil) {
        guard let step = UserDefaults.standard.string(forKey: stepKey) else { return }
        var values: [String: Any] = ["outcome": outcome,
            "duration_ms": Int(max(0, Date().timeIntervalSince1970 - UserDefaults.standard.double(forKey: enteredAtKey)) * 1000)]
        if let detected { values["detected"] = detected }
        capture("onboarding_step_exited", step: step, properties: values)
        UserDefaults.standard.removeObject(forKey: stepKey)
    }

    static func capture(_ name: String, step: String? = nil, properties: [String: Any] = [:]) {
        let status = KeyboardStatusContext(bundleId: "com.core7.keigobutton.keyboard")
        var values = context.merging(properties) { _, new in new }
        values["step"] = step ?? UserDefaults.standard.string(forKey: stepKey) ?? "unknown"
        values["keyboard_enabled"] = status.isKeyboardEnabled
        values["keyboard_active"] = status.isKeyboardActive
        values["full_access_detected"] = status.isFullAccessEnabled
        values["full_access_last_observed"] = KeyboardSettingsStore.readLastKnownFullAccessEnabled()
        values["consent_granted"] = KeyboardSettingsStore.readAIConsentGranted()
        AppAnalytics.capture(name, properties: values)
    }
}
