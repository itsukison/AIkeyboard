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
