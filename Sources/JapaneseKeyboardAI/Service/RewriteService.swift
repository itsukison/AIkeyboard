import Foundation

public protocol RewriteService: Sendable {
    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult
    /// Delivers each candidate through `onCandidate` as soon as the backend
    /// finishes generating it, then returns the complete result. Conformers
    /// that cannot stream fall back to `rewrite` via the extension below.
    func rewriteStreaming(
        _ request: RewriteRequest,
        onCandidate: @escaping @Sendable (RewriteCandidate) -> Void
    ) async throws -> RewriteResult
    /// Best-effort: records which candidate (0-based, within the originating
    /// rewrite event) the user accepted. Never throws — feedback loss is fine.
    func submitSelection(eventId: String, selectedIndex: Int) async
}

extension RewriteService {
    public func rewriteStreaming(
        _ request: RewriteRequest,
        onCandidate: @escaping @Sendable (RewriteCandidate) -> Void
    ) async throws -> RewriteResult {
        let result = try await rewrite(request)
        result.candidates.forEach(onCandidate)
        return result
    }
}
