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
    public static let replyKey = "reply"
    private static let legacyDefaults: [String: [(title: String, prompt: String)]] = [
        politeKey: [
            (
                title: "敬語",
                prompt: "Rewrite into polite, business-appropriate Japanese (敬語) while preserving meaning."
            ),
            (
                title: "敬語",
                prompt: "ビジネスで通用する自然な敬語に書き直してください。過度に堅苦しい表現は避け、読みやすい丁寧語にしてください。"
            ),
        ],
        naturalKey: [
            (
                title: "自然に書き直し",
                prompt: "Rewrite into natural, idiomatic Japanese while preserving meaning. Make it sound like a native speaker wrote it."
            ),
        ],
        emailKey: [
            (
                title: "メール",
                prompt: "Rewrite into formal Japanese business email style (件名を要さず、本文のみ). Use 拝啓 only if culturally appropriate, otherwise typical メール本文 register with お世話になっております level politeness when applicable."
            ),
        ],
        translateToEnglishKey: [
            (
                title: "英訳",
                prompt: "Translate into natural English."
            ),
        ],
    ]

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
            return "次の文章を、日常でそのまま送れる自然でやわらかい丁寧語に変換してください。\n\nビジネス敬語ではなく、相手に失礼がない普通の丁寧語にしてください。\nただし、命令・指示・お願いの文章は「〜してください」ではなく、「〜してもらえますか？」「〜しておいてもらえないでしょうか？」のような、やわらかいお願いの形にしてください。\n\n「〜しておいて」「〜しといて」「〜やっといて」は、原則として「〜しておいてもらえないでしょうか？」に変換してください。\n「ございます」「いただけますでしょうか」「ご〜される」などの堅すぎる敬語は使わないでください。\n出力は変換後の文章だけにしてください。"
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

    /// Local default prompt set for users who have not signed in. Mirrors the
    /// server-seeded set so the keyboard toolbar and Prompts screen are populated
    /// for guests. Overwritten by the cloud fetch once the user signs in.
    public static func seedEntries() -> [UserPrompt] {
        [
            seedEntry(politeKey, slot: .main, sortOrder: 0),
            seedEntry(naturalKey, slot: .sub, sortOrder: 0),
            seedEntry(emailKey, slot: .sub, sortOrder: 1),
            seedEntry(translateToEnglishKey, slot: .sub, sortOrder: 2),
        ].compactMap { $0 }
    }

    private static func seedEntry(_ key: String, slot: UserPrompt.Slot, sortOrder: Int) -> UserPrompt? {
        guard let title = defaultTitle(for: key), let prompt = defaultPrompt(for: key) else { return nil }
        return UserPrompt(slot: slot, builtinKey: key, title: title, prompt: prompt, sortOrder: sortOrder)
    }

    /// The reply command. Not part of `seedEntries()` — it is surfaced by a
    /// context-appearing pill (when a message was just copied), not the editable
    /// prompt list, and drives the two-input reply flow.
    public static func replyPrompt() -> UserPrompt {
        UserPrompt(
            slot: .sub,
            builtinKey: replyKey,
            title: "返信",
            prompt: "相手のメッセージに対する自然な返信を作成してください。文脈に合った丁寧で読みやすい日本語にし、相手の意図に過不足なく応じてください。"
        )
    }

    static func normalized(_ prompt: UserPrompt) -> UserPrompt {
        guard
            let key = prompt.builtinKey,
            let legacyVariants = legacyDefaults[key],
            legacyVariants.contains(where: { $0.title == prompt.title && $0.prompt == prompt.prompt }),
            let currentTitle = defaultTitle(for: key),
            let currentPrompt = defaultPrompt(for: key)
        else {
            return prompt
        }

        var normalizedPrompt = prompt
        normalizedPrompt.title = currentTitle
        normalizedPrompt.prompt = currentPrompt
        return normalizedPrompt
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
        let normalizedEntries = entries.map(UserPromptDefaults.normalized)
        guard let data = try? JSONEncoder().encode(normalizedEntries) else { return }
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
