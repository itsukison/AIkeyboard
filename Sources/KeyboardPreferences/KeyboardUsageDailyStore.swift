import Foundation

/// One day's local keyboard-usage tally. Written by the extension into the App
/// Group and flushed to analytics by the container app. Holds counts only — no
/// text, no keystrokes — so nothing crosses the privacy boundary the keyboard
/// promises, and the extension never touches the network.
public struct KeyboardDayUsage: Codable, Equatable, Sendable {
    public let date: String
    public var opens: Int
    public var activeSeconds: Int
    public var typed: Bool

    public init(date: String, opens: Int = 0, activeSeconds: Int = 0, typed: Bool = false) {
        self.date = date
        self.opens = opens
        self.activeSeconds = activeSeconds
        self.typed = typed
    }
}

/// Per-day usage counters the extension accumulates and the container forwards
/// to PostHog. The container can only flush days that have fully elapsed, so a
/// user who types but never reopens the container app keeps accruing days
/// locally (capped at `maxRetainedDays`) until they next open it.
public enum KeyboardUsageDailyStore {
    public static let dailyUsageKey = "stats.dailyUsage"
    private static let maxRetainedDays = 30

    public static func recordKeyboardOpen(
        defaults: UserDefaults = KeyboardSettingsStore.sharedDefaults ?? .standard,
        now: Date = Date()
    ) {
        mutateToday(defaults: defaults, now: now) { $0.opens += 1 }
    }

    public static func addActiveSeconds(
        _ seconds: Int,
        defaults: UserDefaults = KeyboardSettingsStore.sharedDefaults ?? .standard,
        now: Date = Date()
    ) {
        guard seconds > 0 else { return }
        mutateToday(defaults: defaults, now: now) { $0.activeSeconds += seconds }
    }

    public static func markTyped(
        defaults: UserDefaults = KeyboardSettingsStore.sharedDefaults ?? .standard,
        now: Date = Date()
    ) {
        mutateToday(defaults: defaults, now: now) { $0.typed = true }
    }

    /// Returns and removes every fully-elapsed day (anything before today),
    /// leaving today's still-accumulating record in place. Called by the
    /// container so each completed day reaches analytics exactly once.
    public static func flushCompletedDays(
        defaults: UserDefaults = KeyboardSettingsStore.sharedDefaults ?? .standard,
        now: Date = Date()
    ) -> [KeyboardDayUsage] {
        let today = dayIdentifier(for: now)
        let days = load(defaults: defaults)
        let completed = days.filter { $0.date != today }
        save(days.filter { $0.date == today }, defaults: defaults)
        return completed.sorted { $0.date < $1.date }
    }

    private static func mutateToday(
        defaults: UserDefaults,
        now: Date,
        _ change: (inout KeyboardDayUsage) -> Void
    ) {
        let today = dayIdentifier(for: now)
        var days = load(defaults: defaults)
        if let index = days.firstIndex(where: { $0.date == today }) {
            change(&days[index])
        } else {
            var entry = KeyboardDayUsage(date: today)
            change(&entry)
            days.append(entry)
        }
        if days.count > maxRetainedDays {
            days = Array(days.suffix(maxRetainedDays))
        }
        save(days, defaults: defaults)
    }

    private static func load(defaults: UserDefaults) -> [KeyboardDayUsage] {
        guard let data = defaults.data(forKey: dailyUsageKey) else { return [] }
        return (try? JSONDecoder().decode([KeyboardDayUsage].self, from: data)) ?? []
    }

    private static func save(_ days: [KeyboardDayUsage], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(days) else { return }
        defaults.set(data, forKey: dailyUsageKey)
    }

    private static func dayIdentifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
