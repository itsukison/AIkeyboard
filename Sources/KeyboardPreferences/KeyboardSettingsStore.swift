import Foundation

public enum KeyboardStyle: String, Codable, Sendable, CaseIterable {
    case standard
    case japaneseRomaji
    case japaneseFlick

    public var showsLongVowelKey: Bool {
        self == .japaneseRomaji
    }
}

public enum KeyboardKeySizePreset: String, Codable, Sendable, CaseIterable {
    case small
    case slightlySmall
    case standard
    case slightlyLarge
    case large

    public var keyCapInsetAdjustment: Double {
        switch self {
        case .small: return 4.0
        case .slightlySmall: return 2.0
        case .standard: return 0
        case .slightlyLarge: return -2.0
        case .large: return -4.0
        }
    }
}

/// Which language the keyboard inputs in. `.japanese` (the default) drives the
/// existing romaji/kana → kana-kanji pipeline unchanged. Other languages are
/// opt-in parallel modes that must never alter the Japanese path (see CLAUDE.md
/// "Japanese is the default"). `KeyboardStyle` (romaji/flick) only applies when
/// this is `.japanese`.
public enum KeyboardLanguage: String, Codable, Sendable, CaseIterable {
    case japanese
    case english
}

public enum KeyboardSettingsStore {
    public static let appGroupIdentifier = AppGroup.identifier
    public static let keyboardStyleKey = "keyboardStyle"
    public static let keyboardKeySizePresetKey = "keyboardKeySizePreset"
    public static let keyboardLanguageKey = "keyboardLanguage"
    public static let userPromptEntriesKey = "userPromptEntries"
    public static let conversionPreferenceEntriesKey = "conversionPreferenceEntries"
    public static let nextWordPreferenceEntriesKey = "nextWordPreferenceEntries"
    public static let hapticsEnabledKey = "hapticsEnabled"
    public static let zenzaiEnabledKey = "zenzaiEnabled"
    public static let zenzaiAutoDisabledBuildKey = "zenzaiAutoDisabledBuild"
    public static let zenzaiAutoDisablePendingReportKey = "zenzaiAutoDisablePendingReport"
    public static let cloudAIEnabledKey = "cloudAIEnabled"
    public static let aiConsentGrantedKey = "aiConsentGranted"
    public static let aiCommercialOptInKey = "aiCommercialOptIn"
    public static let anonymousDeviceIdKey = "anonymousDeviceId"
    public static let lastKnownFullAccessEnabledKey = "lastKnownFullAccessEnabled"
    public static let lastSeenPasteboardChangeCountKey = "lastSeenPasteboardChangeCount"

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

    public static func readKeyboardKeySizePreset(
        defaults: UserDefaults? = sharedDefaults
    ) -> KeyboardKeySizePreset {
        guard let raw = defaults?.string(forKey: keyboardKeySizePresetKey) else {
            return .standard
        }
        return KeyboardKeySizePreset(rawValue: raw) ?? .standard
    }

    public static func writeKeyboardKeySizePreset(
        _ preset: KeyboardKeySizePreset,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(preset.rawValue, forKey: keyboardKeySizePresetKey)
    }

    /// Defaults to `.japanese` when unset, so every existing user — and anyone
    /// who never opens the language picker — stays on the Japanese keyboard.
    public static func readKeyboardLanguage(defaults: UserDefaults? = sharedDefaults) -> KeyboardLanguage {
        if let raw = defaults?.string(forKey: keyboardLanguageKey) {
            return KeyboardLanguage(rawValue: raw) ?? .japanese
        }
        return .japanese
    }

    public static func writeKeyboardLanguage(
        _ language: KeyboardLanguage,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(language.rawValue, forKey: keyboardLanguageKey)
    }

    public static func readHapticsEnabled(defaults: UserDefaults? = sharedDefaults) -> Bool {
        defaults?.bool(forKey: hapticsEnabledKey) ?? false
    }

    public static func isHapticsEnabledSet(defaults: UserDefaults? = sharedDefaults) -> Bool {
        defaults?.object(forKey: hapticsEnabledKey) != nil
    }

    public static func writeHapticsEnabled(
        _ enabled: Bool,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(enabled, forKey: hapticsEnabledKey)
    }

    /// Zenzai (on-device neural conversion). Defaults to `true`; the keyboard
    /// still falls back to classical conversion automatically when jetsam
    /// headroom is short, independent of this setting. Read once per extension
    /// process at converter creation, so a flip takes effect the next time iOS
    /// relaunches the keyboard process.
    public static func readZenzaiEnabled(defaults: UserDefaults? = sharedDefaults) -> Bool {
        if let value = defaults?.object(forKey: zenzaiEnabledKey) as? Bool {
            return value
        }
        return true
    }

    public static func writeZenzaiEnabled(
        _ enabled: Bool,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(enabled, forKey: zenzaiEnabledKey)
    }

    /// Called by the conversion engine when the latency gate trips: Zenzai is
    /// too slow on this device. Records the build so the decision persists
    /// across keyboard processes, plus a pending-report flag the container
    /// forwards to analytics (the extension can't emit analytics itself).
    public static func recordZenzaiAutoDisabled(
        build: String = currentBuild,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(build, forKey: zenzaiAutoDisabledBuildKey)
        defaults?.set(true, forKey: zenzaiAutoDisablePendingReportKey)
    }

    /// Whether the latency gate previously disabled Zenzai on this device.
    /// The decision is scoped to the app build that made it: a new build
    /// clears the flag and probes again, so a device isn't punished forever
    /// for one slow week (and OS/app updates get a fresh chance).
    public static func isZenzaiAutoDisabled(
        currentBuild: String = currentBuild,
        defaults: UserDefaults? = sharedDefaults
    ) -> Bool {
        guard let stored = defaults?.string(forKey: zenzaiAutoDisabledBuildKey) else {
            return false
        }
        if stored != currentBuild {
            defaults?.removeObject(forKey: zenzaiAutoDisabledBuildKey)
            return false
        }
        return true
    }

    /// Read-and-clear for the container's analytics bridge: returns `true`
    /// exactly once per gate trip.
    public static func takeZenzaiAutoDisablePendingReport(
        defaults: UserDefaults? = sharedDefaults
    ) -> Bool {
        guard defaults?.bool(forKey: zenzaiAutoDisablePendingReportKey) == true else {
            return false
        }
        defaults?.removeObject(forKey: zenzaiAutoDisablePendingReportKey)
        return true
    }

    /// Public only because default argument values must match their
    /// function's access level; callers should not need it directly.
    public static var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    public static func readCloudAIEnabled(defaults: UserDefaults? = sharedDefaults) -> Bool {
        if let value = defaults?.object(forKey: cloudAIEnabledKey) as? Bool {
            return value
        }
        return true
    }

    public static func writeCloudAIEnabled(
        _ enabled: Bool,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(enabled, forKey: cloudAIEnabledKey)
    }

    /// Whether the user has explicitly agreed to send text to the third-party
    /// AI services. Defaults to `false`: AI rewrite stays gated until the user
    /// consents in the container app. Read by the extension before any network
    /// call so consent is enforced cross-process via the App Group.
    public static func readAIConsentGranted(defaults: UserDefaults? = sharedDefaults) -> Bool {
        defaults?.bool(forKey: aiConsentGrantedKey) ?? false
    }

    public static func writeAIConsentGranted(
        _ granted: Bool,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(granted, forKey: aiConsentGrantedKey)
    }

    /// Pending commercial data-use opt-in captured during onboarding (before
    /// sign-in). The authoritative record lives server-side in `user_ai_consent`;
    /// this local flag is synced up on sign-in. Defaults false (opt-in).
    public static func readAICommercialOptIn(defaults: UserDefaults? = sharedDefaults) -> Bool {
        defaults?.bool(forKey: aiCommercialOptInKey) ?? false
    }

    public static func writeAICommercialOptIn(
        _ optIn: Bool,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(optIn, forKey: aiCommercialOptInKey)
    }

    public static func anonymousDeviceId(defaults: UserDefaults? = sharedDefaults) -> String {
        if let existing = defaults?.string(forKey: anonymousDeviceIdKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        defaults?.set(id, forKey: anonymousDeviceIdKey)
        return id
    }

    /// The `UIPasteboard.changeCount` the keyboard last offered a reply for.
    /// Compared against the current count to detect a freshly copied message
    /// without reading the clipboard contents (no privacy banner). Returns -1
    /// when unset so the very first non-empty clipboard counts as "new".
    public static func readLastSeenPasteboardChangeCount(defaults: UserDefaults? = sharedDefaults) -> Int {
        guard let defaults, defaults.object(forKey: lastSeenPasteboardChangeCountKey) != nil else {
            return -1
        }
        return defaults.integer(forKey: lastSeenPasteboardChangeCountKey)
    }

    public static func writeLastSeenPasteboardChangeCount(
        _ count: Int,
        defaults: UserDefaults? = sharedDefaults
    ) {
        defaults?.set(count, forKey: lastSeenPasteboardChangeCountKey)
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

public struct KeyboardUsageStatsSnapshot: Equatable, Sendable {
    public let conversionsTotal: Int
    public let streakDays: Int

    public init(conversionsTotal: Int, streakDays: Int) {
        self.conversionsTotal = conversionsTotal
        self.streakDays = streakDays
    }
}

public enum KeyboardUsageStatsStore {
    public static let conversionsTotalKey = "stats.conversionsTotal"
    public static let lastConversionDayKey = "stats.lastConversionDay"
    public static let streakDaysKey = "stats.streakDays"

    public static func snapshot(
        defaults: UserDefaults = KeyboardSettingsStore.sharedDefaults ?? .standard,
        now: Date = Date()
    ) -> KeyboardUsageStatsSnapshot {
        let total = defaults.integer(forKey: conversionsTotalKey)
        var streak = defaults.integer(forKey: streakDaysKey)

        if let storedDay = defaults.string(forKey: lastConversionDayKey),
           let dayDiff = daysBetween(storedDay, and: now),
           dayDiff > 1 {
            streak = 0
            defaults.set(0, forKey: streakDaysKey)
        }

        return KeyboardUsageStatsSnapshot(conversionsTotal: total, streakDays: streak)
    }

    @discardableResult
    public static func recordAcceptedRewrite(
        defaults: UserDefaults = KeyboardSettingsStore.sharedDefaults ?? .standard,
        now: Date = Date()
    ) -> KeyboardUsageStatsSnapshot {
        let today = dayIdentifier(for: now)
        let storedDay = defaults.string(forKey: lastConversionDayKey)
        let total = defaults.integer(forKey: conversionsTotalKey) + 1

        let streak: Int
        if storedDay == today {
            streak = max(1, defaults.integer(forKey: streakDaysKey))
        } else if let storedDay,
                  let dayDiff = daysBetween(storedDay, and: now),
                  dayDiff == 1 {
            streak = defaults.integer(forKey: streakDaysKey) + 1
        } else {
            streak = 1
        }

        defaults.set(total, forKey: conversionsTotalKey)
        defaults.set(streak, forKey: streakDaysKey)
        defaults.set(today, forKey: lastConversionDayKey)

        return KeyboardUsageStatsSnapshot(conversionsTotal: total, streakDays: streak)
    }

    private static func daysBetween(_ storedDay: String, and now: Date) -> Int? {
        guard let stored = dayFormatter.date(from: storedDay) else { return nil }
        let calendar = Calendar.current
        guard let storedStart = calendar.dateInterval(of: .day, for: stored)?.start,
              let todayStart = calendar.dateInterval(of: .day, for: now)?.start else {
            return nil
        }
        return calendar.dateComponents([.day], from: storedStart, to: todayStart).day
    }

    private static func dayIdentifier(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
