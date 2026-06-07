import Foundation

public enum KeyboardStyle: String, Codable, Sendable, CaseIterable {
    case standard
    case japaneseRomaji

    public var showsLongVowelKey: Bool {
        self == .japaneseRomaji
    }
}

public enum KeyboardSettingsStore {
    public static let appGroupIdentifier = AppGroup.identifier
    public static let keyboardStyleKey = "keyboardStyle"
    public static let userPromptEntriesKey = "userPromptEntries"
    public static let conversionPreferenceEntriesKey = "conversionPreferenceEntries"
    public static let hapticsEnabledKey = "hapticsEnabled"
    public static let cloudAIEnabledKey = "cloudAIEnabled"
    public static let anonymousDeviceIdKey = "anonymousDeviceId"
    public static let lastKnownFullAccessEnabledKey = "lastKnownFullAccessEnabled"

    public static let aiAccessTokenKey = "aiAccessToken"
    public static let aiRefreshTokenKey = "aiRefreshToken"
    public static let aiTokenExpiresAtKey = "aiTokenExpiresAt"

    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    public static func readKeyboardStyle(defaults: UserDefaults? = sharedDefaults) -> KeyboardStyle {
        if let raw = defaults?.string(forKey: keyboardStyleKey) {
            return KeyboardStyle(rawValue: raw) ?? .japaneseRomaji
        }
        return .japaneseRomaji
    }

    public static func writeKeyboardStyle(
        _ style: KeyboardStyle,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(style.rawValue, forKey: keyboardStyleKey)
    }

    public static func readHapticsEnabled(defaults: UserDefaults? = sharedDefaults) -> Bool {
        defaults?.bool(forKey: hapticsEnabledKey) ?? false
    }

    public static func writeHapticsEnabled(
        _ enabled: Bool,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(enabled, forKey: hapticsEnabledKey)
    }

    public static func readCloudAIEnabled(defaults: UserDefaults? = sharedDefaults) -> Bool {
        defaults?.bool(forKey: cloudAIEnabledKey) ?? false
    }

    public static func writeCloudAIEnabled(
        _ enabled: Bool,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(enabled, forKey: cloudAIEnabledKey)
    }

    public static func anonymousDeviceId(defaults: UserDefaults? = sharedDefaults) -> String {
        if let existing = defaults?.string(forKey: anonymousDeviceIdKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        defaults?.set(id, forKey: anonymousDeviceIdKey)
        return id
    }

    public static func readLastKnownFullAccessEnabled(defaults: UserDefaults? = sharedDefaults) -> Bool {
        defaults?.bool(forKey: lastKnownFullAccessEnabledKey) ?? false
    }

    public static func writeLastKnownFullAccessEnabled(
        _ enabled: Bool,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(enabled, forKey: lastKnownFullAccessEnabledKey)
    }
}
