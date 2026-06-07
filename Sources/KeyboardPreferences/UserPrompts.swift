import Foundation

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
        case naturalKey: return "自然に"
        case emailKey: return "メール"
        case translateToEnglishKey: return "英訳"
        default: return nil
        }
    }

    public static func defaultPrompt(for builtinKey: String) -> String? {
        switch builtinKey {
        case politeKey:
            return "ビジネスで通用する自然な敬語に書き直してください。過度に堅苦しい表現は避け、読みやすい丁寧語にしてください。"
        case naturalKey:
            return "ネイティブが書いたような自然で読みやすい日本語に書き直してください。直訳調や不自然な言い回しは修正してください。"
        case emailKey:
            return "ビジネスメールの本文として送れる文体に書き直してください。件名・宛名・署名は付けず、拝啓・敬具は使わず、挨拶文は文脈に合う場合のみ添えてください。"
        case translateToEnglishKey:
            return "自然で読みやすい英語に翻訳してください。直訳ではなく、ネイティブが日常的に書く文体・語順にしてください。"
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
