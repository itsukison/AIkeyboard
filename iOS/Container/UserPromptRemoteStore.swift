import Foundation
import KeyboardPreferences

enum UserPromptRemoteStore {
    static func fetchEntries(for userId: UUID) async throws -> [UserPrompt] {
        let rows: [Row] = try await supabase
            .from("user_prompts")
            .select("id, user_id, slot, builtin_key, title, prompt, is_enabled, sort_order, created_at, updated_at")
            .eq("user_id", value: userId)
            .order("slot", ascending: true)
            .order("sort_order", ascending: true)
            .execute()
            .value

        return rows.map(\.entry)
    }

    static func updatePrompt(
        id: UUID,
        title: String,
        prompt: String,
        isEnabled: Bool,
        sortOrder: Int,
        userId: UUID
    ) async throws {
        let row = UpdateRow(
            title: title,
            prompt: prompt,
            is_enabled: isEnabled,
            sort_order: sortOrder
        )
        try await supabase
            .from("user_prompts")
            .update(row)
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    static func insertCustomSubPrompt(
        title: String,
        prompt: String,
        sortOrder: Int,
        userId: UUID
    ) async throws -> UserPrompt {
        let row = InsertRow(
            user_id: userId,
            slot: "sub",
            builtin_key: nil,
            title: title,
            prompt: prompt,
            is_enabled: true,
            sort_order: sortOrder
        )
        let inserted: Row = try await supabase
            .from("user_prompts")
            .insert(row)
            .select("id, user_id, slot, builtin_key, title, prompt, is_enabled, sort_order, created_at, updated_at")
            .single()
            .execute()
            .value
        return inserted.entry
    }

    static func deletePrompt(id: UUID, userId: UUID) async throws {
        try await supabase
            .from("user_prompts")
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    static func updateSortOrders(_ orders: [(id: UUID, sortOrder: Int)], userId: UUID) async throws {
        for entry in orders {
            try await supabase
                .from("user_prompts")
                .update(SortOrderRow(sort_order: entry.sortOrder))
                .eq("id", value: entry.id)
                .eq("user_id", value: userId)
                .execute()
        }
    }
}

private struct Row: Decodable {
    let id: UUID
    let user_id: UUID
    let slot: String
    let builtin_key: String?
    let title: String
    let prompt: String
    let is_enabled: Bool
    let sort_order: Int
    let created_at: Date
    let updated_at: Date

    var entry: UserPrompt {
        UserPrompt(
            id: id,
            slot: UserPrompt.Slot(rawValue: slot) ?? .sub,
            builtinKey: builtin_key,
            title: title,
            prompt: prompt,
            isEnabled: is_enabled,
            sortOrder: sort_order,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }
}

private struct UpdateRow: Encodable {
    let title: String
    let prompt: String
    let is_enabled: Bool
    let sort_order: Int
}

private struct InsertRow: Encodable {
    let user_id: UUID
    let slot: String
    let builtin_key: String?
    let title: String
    let prompt: String
    let is_enabled: Bool
    let sort_order: Int
}

private struct SortOrderRow: Encodable {
    let sort_order: Int
}
