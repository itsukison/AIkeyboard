import XCTest
@testable import KeyboardPreferences

final class UserPromptStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "UserPromptStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testWriteEntriesNormalizesLegacyBuiltinPromptDefaults() {
        let legacy = UserPrompt(
            slot: .sub,
            builtinKey: UserPromptDefaults.naturalKey,
            title: "自然に書き直し",
            prompt: "Rewrite into natural, idiomatic Japanese while preserving meaning. Make it sound like a native speaker wrote it.",
            sortOrder: 1
        )

        UserPromptStore.writeEntries([legacy], defaults: defaults)

        let entry = UserPromptStore.readEntries(defaults: defaults).first
        XCTAssertEqual(entry?.title, "自然に")
        XCTAssertEqual(
            entry?.prompt,
            "ネイティブが書いたような自然で読みやすい日本語に書き直してください。直訳調や不自然な言い回しは修正してください。"
        )
    }

    func testWriteEntriesNormalizesPriorPoliteDefaultToCurrent() {
        let priorDefault = UserPrompt(
            slot: .main,
            builtinKey: UserPromptDefaults.politeKey,
            title: "敬語",
            prompt: "ビジネスで通用する自然な敬語に書き直してください。過度に堅苦しい表現は避け、読みやすい丁寧語にしてください。",
            sortOrder: 0
        )

        UserPromptStore.writeEntries([priorDefault], defaults: defaults)

        let entry = UserPromptStore.readEntries(defaults: defaults).first
        XCTAssertEqual(entry?.prompt, UserPromptDefaults.defaultPrompt(for: UserPromptDefaults.politeKey))
    }

    func testWriteEntriesDoesNotNormalizeCustomBuiltinPrompt() {
        let custom = UserPrompt(
            slot: .main,
            builtinKey: UserPromptDefaults.politeKey,
            title: "敬語",
            prompt: "自分用の敬語プロンプト",
            sortOrder: 0
        )

        UserPromptStore.writeEntries([custom], defaults: defaults)

        let entry = UserPromptStore.readEntries(defaults: defaults).first
        XCTAssertEqual(entry, custom)
    }
}
