import Foundation

// Reads and writes the user's AI-improvement retention consent. This is the
// authoritative record the edge function reads server-side to decide what it
// may store. RLS scopes every row to its owner, so the signed-in user's JWT is
// required. Data is collected only when the user opts in; the opt-in grants the
// `commercial_dataset` scope (build/provide Japanese-AI training datasets,
// incl. third-party provision). Absence of a row means no retention.
enum AIConsentRemoteStore {
    static let commercialScope = "commercial_dataset"
    // Bump when the consent copy / policy materially changes. Mirrors the
    // "同意バージョン" shown in the public privacy policy.
    static let currentConsentVersion = "2026-07-02"

    struct Consent: Equatable {
        var optIn: Bool
        var scope: String
        var rawTextAllowed: Bool
        var consentVersion: String?
    }

    /// True when the user has opted into commercial data use.
    static func isCommercialOptIn(_ consent: Consent?) -> Bool {
        guard let consent else { return false }
        return consent.optIn && consent.scope == commercialScope
    }

    static func fetch(for userId: UUID) async throws -> Consent? {
        let rows: [Row] = try await supabase
            .from("user_ai_consent")
            .select("ai_improvement_opt_in, data_use_scope, raw_text_allowed, consent_version")
            .eq("user_id", value: userId)
            .execute()
            .value

        guard let row = rows.first else { return nil }
        return Consent(
            optIn: row.ai_improvement_opt_in,
            scope: row.data_use_scope,
            rawTextAllowed: row.raw_text_allowed,
            consentVersion: row.consent_version
        )
    }

    static func setCommercialOptIn(_ optIn: Bool, for userId: UUID) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let row = UpsertRow(
            user_id: userId,
            ai_improvement_opt_in: optIn,
            data_use_scope: optIn ? commercialScope : "none",
            raw_text_allowed: false,
            consent_version: optIn ? currentConsentVersion : nil,
            consented_at: optIn ? now : nil,
            updated_at: now
        )
        try await supabase
            .from("user_ai_consent")
            .upsert(row, onConflict: "user_id")
            .execute()
    }
}

private struct Row: Decodable {
    let ai_improvement_opt_in: Bool
    let data_use_scope: String
    let raw_text_allowed: Bool
    let consent_version: String?
}

private struct UpsertRow: Encodable {
    let user_id: UUID
    let ai_improvement_opt_in: Bool
    let data_use_scope: String
    let raw_text_allowed: Bool
    let consent_version: String?
    let consented_at: String?
    let updated_at: String
}
