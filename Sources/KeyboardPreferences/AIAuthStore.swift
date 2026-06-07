import Foundation

/// Token cache for Supabase auth. The container app writes after sign-in /
/// refresh; the keyboard extension reads (and refreshes when within 30 s
/// of expiry, via `CloudRewriteService`).
public enum AIAuthStore {
    public static func writeTokens(
        accessToken: String?,
        refreshToken: String?,
        expiresAt: Date?,
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults
    ) {
        defaults?.set(accessToken, forKey: KeyboardSettingsStore.aiAccessTokenKey)
        defaults?.set(refreshToken, forKey: KeyboardSettingsStore.aiRefreshTokenKey)
        if let expiresAt {
            defaults?.set(expiresAt.timeIntervalSince1970, forKey: KeyboardSettingsStore.aiTokenExpiresAtKey)
        } else {
            defaults?.removeObject(forKey: KeyboardSettingsStore.aiTokenExpiresAtKey)
        }
    }

    public static func readAccessToken(defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) -> String? {
        defaults?.string(forKey: KeyboardSettingsStore.aiAccessTokenKey)
    }

    public static func readRefreshToken(defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) -> String? {
        defaults?.string(forKey: KeyboardSettingsStore.aiRefreshTokenKey)
    }

    public static func readExpiresAt(defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) -> Date? {
        guard let ti = defaults?.object(forKey: KeyboardSettingsStore.aiTokenExpiresAtKey) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: ti)
    }
}
