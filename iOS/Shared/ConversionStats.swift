import Foundation

@MainActor
final class ConversionStats: ObservableObject {
    static let shared = ConversionStats()

    private static let suiteName = "group.com.core7.keigobutton"
    private static let totalKey = "stats.conversionsTotal"
    private static let lastDayKey = "stats.lastConversionDay"
    private static let streakKey = "stats.streakDays"

    @Published private(set) var conversionsTotal: Int
    @Published private(set) var streakDays: Int

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let dayFormatter: DateFormatter

    private init() {
        self.defaults = UserDefaults(suiteName: ConversionStats.suiteName) ?? .standard

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        self.calendar = cal

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        self.dayFormatter = fmt

        self.conversionsTotal = defaults.integer(forKey: ConversionStats.totalKey)
        self.streakDays = defaults.integer(forKey: ConversionStats.streakKey)
    }

    func recordJapaneseConversion(now: Date = Date()) {
        let today = dayFormatter.string(from: now)
        let storedDay = defaults.string(forKey: ConversionStats.lastDayKey)

        let newTotal = defaults.integer(forKey: ConversionStats.totalKey) + 1
        let newStreak: Int
        if storedDay == today {
            newStreak = max(1, defaults.integer(forKey: ConversionStats.streakKey))
        } else if let storedDay, let stored = dayFormatter.date(from: storedDay),
                  let storedStart = calendar.dateInterval(of: .day, for: stored)?.start,
                  let todayStart = calendar.dateInterval(of: .day, for: now)?.start,
                  let dayDiff = calendar.dateComponents([.day], from: storedStart, to: todayStart).day,
                  dayDiff == 1 {
            newStreak = defaults.integer(forKey: ConversionStats.streakKey) + 1
        } else {
            newStreak = 1
        }

        defaults.set(newTotal, forKey: ConversionStats.totalKey)
        defaults.set(newStreak, forKey: ConversionStats.streakKey)
        defaults.set(today, forKey: ConversionStats.lastDayKey)

        conversionsTotal = newTotal
        streakDays = newStreak
    }

    func refresh(now: Date = Date()) {
        let storedTotal = defaults.integer(forKey: ConversionStats.totalKey)
        var storedStreak = defaults.integer(forKey: ConversionStats.streakKey)

        if let storedDay = defaults.string(forKey: ConversionStats.lastDayKey),
           let stored = dayFormatter.date(from: storedDay),
           let storedStart = calendar.dateInterval(of: .day, for: stored)?.start,
           let todayStart = calendar.dateInterval(of: .day, for: now)?.start,
           let dayDiff = calendar.dateComponents([.day], from: storedStart, to: todayStart).day,
           dayDiff > 1 {
            storedStreak = 0
            defaults.set(0, forKey: ConversionStats.streakKey)
        }

        if conversionsTotal != storedTotal { conversionsTotal = storedTotal }
        if streakDays != storedStreak { streakDays = storedStreak }
    }

    var conversionsDisplay: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: conversionsTotal)) ?? "\(conversionsTotal)"
    }

    var streakDisplay: String { "\(streakDays)" }
}
