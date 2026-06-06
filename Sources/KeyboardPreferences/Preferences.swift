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

// MARK: - User prompts (replaces user dictionary)

public struct UserPrompt: Codable, Equatable, Identifiable, Sendable {
    public enum Slot: String, Codable, Sendable {
        case main
        case sub
    }

    public let id: UUID
    public let slot: Slot
    public let builtinKey: String?
    public var title: String
    public var prompt: String
    public var isEnabled: Bool
    public var sortOrder: Int
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        slot: Slot,
        builtinKey: String? = nil,
        title: String,
        prompt: String,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.slot = slot
        self.builtinKey = builtinKey
        self.title = title
        self.prompt = prompt
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum UserPromptDefaults {
    public static let politeKey = "polite"
    public static let naturalKey = "natural"
    public static let emailKey = "email"
    public static let translateToEnglishKey = "translateToEnglish"

    public static func defaultTitle(for builtinKey: String) -> String? {
        switch builtinKey {
        case politeKey: return "敬語"
        case naturalKey: return "自然に書き直し"
        case emailKey: return "メール"
        case translateToEnglishKey: return "英訳"
        default: return nil
        }
    }

    public static func defaultPrompt(for builtinKey: String) -> String? {
        switch builtinKey {
        case politeKey:
            return "Rewrite into polite, business-appropriate Japanese (敬語) while preserving meaning."
        case naturalKey:
            return "Rewrite into natural, idiomatic Japanese while preserving meaning. Make it sound like a native speaker wrote it."
        case emailKey:
            return "Rewrite into formal Japanese business email style (件名を要さず、本文のみ). Use 拝啓 only if culturally appropriate, otherwise typical メール本文 register with お世話になっております level politeness when applicable."
        case translateToEnglishKey:
            return "Translate into natural English."
        default:
            return nil
        }
    }
}

public enum UserPromptStore {
    public static func readEntries(defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) -> [UserPrompt] {
        guard let data = defaults?.data(forKey: KeyboardSettingsStore.userPromptEntriesKey) else {
            return []
        }
        return (try? JSONDecoder().decode([UserPrompt].self, from: data)) ?? []
    }

    public static func writeEntries(
        _ entries: [UserPrompt],
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults
    ) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults?.set(data, forKey: KeyboardSettingsStore.userPromptEntriesKey)
    }

    /// The main button prompt (slot=.main, enabled). Falls back to a built-in 敬語 default if none cached.
    public static func mainPrompt(defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) -> UserPrompt? {
        let entries = readEntries(defaults: defaults)
        return entries.first(where: { $0.slot == .main && $0.isEnabled })
    }

    /// Enabled sub-button prompts in sort_order ascending.
    public static func subPrompts(defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) -> [UserPrompt] {
        readEntries(defaults: defaults)
            .filter { $0.slot == .sub && $0.isEnabled }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - AI auth token cache (container writes, extension reads)

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
