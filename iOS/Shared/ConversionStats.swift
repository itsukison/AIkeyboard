import Foundation
import KeyboardPreferences

@MainActor
final class ConversionStats: ObservableObject {
    static let shared = ConversionStats()

    @Published private(set) var conversionsTotal: Int
    @Published private(set) var streakDays: Int

    private let defaults: UserDefaults

    private init() {
        self.defaults = KeyboardSettingsStore.sharedDefaults ?? .standard
        let snapshot = KeyboardUsageStatsStore.snapshot(defaults: defaults)
        self.conversionsTotal = snapshot.conversionsTotal
        self.streakDays = snapshot.streakDays
    }

    func recordAcceptedRewrite(now: Date = Date()) {
        apply(KeyboardUsageStatsStore.recordAcceptedRewrite(defaults: defaults, now: now))
    }

    func refresh(now: Date = Date()) {
        apply(KeyboardUsageStatsStore.snapshot(defaults: defaults, now: now))
    }

    var conversionsDisplay: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: conversionsTotal)) ?? "\(conversionsTotal)"
    }

    var streakDisplay: String { "\(streakDays)" }

    private func apply(_ snapshot: KeyboardUsageStatsSnapshot) {
        if conversionsTotal != snapshot.conversionsTotal {
            conversionsTotal = snapshot.conversionsTotal
        }
        if streakDays != snapshot.streakDays {
            streakDays = snapshot.streakDays
        }
    }
}
