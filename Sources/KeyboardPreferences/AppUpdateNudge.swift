import Foundation

/// Container → keyboard relay for the "new version available" nudge. The
/// container's App Store check writes the latest version here; the keyboard
/// (which must never make its own lookup call) reads it and shows an update
/// pill until the user updates, or dismisses that version in the container.
public enum AppUpdateNudge {
    public static let availableVersionKey = "updateNudge.availableVersion"
    public static let dismissedVersionKey = "updateNudge.dismissedVersion"

    public static func writeAvailableVersion(
        _ version: String,
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults
    ) {
        defaults?.set(version, forKey: availableVersionKey)
    }

    public static func writeDismissedVersion(
        _ version: String,
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults
    ) {
        defaults?.set(version, forKey: dismissedVersionKey)
    }

    /// Whether the keyboard should show its update pill: the container relayed
    /// a version strictly newer than the running one, and the user hasn't
    /// dismissed that version with 「あとで」. Self-clears on update because the
    /// relayed version stops being newer than the installed one.
    public static func shouldShowNudge(
        currentVersion: String,
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults
    ) -> Bool {
        guard let available = defaults?.string(forKey: availableVersionKey),
              isVersion(available, newerThan: currentVersion) else { return false }
        return available != defaults?.string(forKey: dismissedVersionKey)
    }

    /// Numeric, component-wise compare ("1.0.10" is newer than "1.0.9"), padding
    /// the shorter side with zeros so "1.1" beats "1.0.9".
    public static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let a = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let b = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
