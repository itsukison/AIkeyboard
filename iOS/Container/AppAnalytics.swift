import FirebaseAnalytics
import KeyboardPreferences
import PostHog

enum AppAnalytics {
    /// `timestamp` backdates the event to when it actually happened, for
    /// counters the keyboard accrued offline and the container only relays
    /// later. PostHog accepts it; Firebase has no equivalent on `logEvent`,
    /// so the Google mirror stays stamped at relay time.
    static func capture(_ name: String, properties: [String: Any] = [:], timestamp: Date? = nil) {
        PostHogSDK.shared.capture(name, properties: properties, timestamp: timestamp)
        Analytics.logEvent(googleEventName(for: name), parameters: googleParameters(properties))
    }

    static func identify(_ userId: String, userProperties: [String: Any]) {
        PostHogSDK.shared.identify(userId, userProperties: userProperties)
        Analytics.setUserID(userId)
        Analytics.setUserProperty(
            userProperties["acquisition_source"] as? String,
            forName: "acquisition_source"
        )
    }

    static func reset() {
        PostHogSDK.shared.reset()
        Analytics.setUserID(nil)
        Analytics.setUserProperty(nil, forName: "acquisition_source")
    }

    static func cacheAppInstanceId() {
        guard let identifier = Analytics.appInstanceID() else { return }
        KeyboardSettingsStore.writeAnalyticsAppInstanceId(identifier)
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
