import Foundation

public struct RewriteAttemptMetadata: Codable, Equatable, Sendable {
    public let attemptId: String
    public let rootAttemptId: String
    public let parentGenerationId: String?
    public let generationKind: String
    public let occurredAt: String
    public let onboardingAttemptId: String?
    public let appBuild: String?

    public init(kind: String = "fresh", previous: RewriteAttemptMetadata? = nil,
                parentGenerationId: String? = nil, onboardingAttemptId: String? = nil,
                appBuild: String? = nil, now: Date = Date()) {
        attemptId = UUID().uuidString.lowercased()
        rootAttemptId = previous?.rootAttemptId ?? attemptId
        self.parentGenerationId = parentGenerationId
        generationKind = kind
        occurredAt = ISO8601DateFormatter().string(from: now)
        self.onboardingAttemptId = onboardingAttemptId
        self.appBuild = appBuild
    }

    public var properties: [String: String] {
        var values = ["attempt_id": attemptId, "root_attempt_id": rootAttemptId,
                      "generation_kind": generationKind, "attempt_occurred_at": occurredAt]
        if let parentGenerationId { values["parent_generation_id"] = parentGenerationId }
        if let onboardingAttemptId { values["onboarding_attempt_id"] = onboardingAttemptId }
        if let appBuild { values["app_build"] = appBuild }
        return values
    }
}
