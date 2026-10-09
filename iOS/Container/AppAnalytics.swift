import FirebaseAnalytics
import Foundation
import KeyboardPreferences
import PostHog

enum AppAnalytics {
    /// `timestamp` backdates the event to when it actually happened, for
    /// counters the keyboard accrued offline and the container only relays
    /// later. PostHog accepts it; Firebase has no equivalent on `logEvent`,
    /// so the Google mirror stays stamped at relay time.
    static func capture(_ name: String, properties: [String: Any] = [:], timestamp: Date? = nil) {
        var values = properties
        values["app_version"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        values["app_build"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        values["occurred_at"] = ISO8601DateFormatter().string(from: timestamp ?? Date())
        if name.hasPrefix("onboarding_") || name == "signed_up" || name == "ai_consent_decision" {
            values = OnboardingDiagnostics.context.merging(values) { _, new in new }
        }
        PostHogSDK.shared.capture(name, properties: values, timestamp: timestamp)
        Analytics.logEvent(googleEventName(for: name), parameters: googleParameters(values))
    }

    static func identify(_ userId: String, userProperties: [String: Any]) {
        PostHogSDK.shared.identify(userId, userProperties: userProperties)
        cacheDiagnosticIdentity()
        Analytics.setUserID(userId)
        Analytics.setUserProperty(
            userProperties["acquisition_source"] as? String,
            forName: "acquisition_source"
        )
    }

    static func reset() {
        PostHogSDK.shared.reset()
        cacheDiagnosticIdentity()
        Analytics.setUserID(nil)
        Analytics.setUserProperty(nil, forName: "acquisition_source")
    }

    static func cacheAppInstanceId() {
        cacheDiagnosticIdentity()
        guard let identifier = Analytics.appInstanceID() else { return }
        KeyboardSettingsStore.writeAnalyticsAppInstanceId(identifier)
    }

    static func cacheDiagnosticIdentity() {
        KeyboardSettingsStore.sharedDefaults?.set(PostHogSDK.shared.getDistinctId(), forKey: KeyboardDiagnosticStore.identityKey)
    }

    static func flushKeyboardDiagnostics() {
        for event in KeyboardDiagnosticStore.pending() {
            // An event without a captured identity must never be assigned to a
            // different account that happened to reopen the app later.
            if let distinctId = event.distinctId {
                var values: [String: Any] = event.properties
                values["$insert_id"] = event.id
                values["occurred_at"] = ISO8601DateFormatter().string(from: event.occurredAt)
                values["relayed_at"] = ISO8601DateFormatter().string(from: Date())
                values["relay_delay_ms"] = Int(max(0, Date().timeIntervalSince(event.occurredAt)) * 1000)
                values["source"] = "app_group_relay"
                PostHogSDK.shared.capture(event.name, distinctId: distinctId, properties: values, timestamp: event.occurredAt)
            }
            KeyboardDiagnosticStore.acknowledge(event)
        }
    }

    private static func googleEventName(for name: String) -> String {
        switch name {
        case "signed_up": return AnalyticsEventSignUp
        case "signed_in": return AnalyticsEventLogin
        default: return name
        }
    }

    private static func googleParameters(_ properties: [String: Any]) -> [String: Any]? {
        var parameters: [String: Any] = [:]
        for (key, value) in properties where key != "error_message" && key != "title" {
            switch value {
            case let string as String:
                parameters[key] = String(string.prefix(100))
            case let bool as Bool:
                parameters[key] = bool ? 1 : 0
            case let number as NSNumber:
                parameters[key] = number
            default:
                continue
            }
        }
        return parameters.isEmpty ? nil : parameters
    }
}
