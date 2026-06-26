import Foundation

public protocol RewriteService: Sendable {
    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult
    /// Best-effort: records which candidate (0-based, within the originating
    /// rewrite event) the user accepted. Never throws — feedback loss is fine.
    func submitSelection(eventId: String, selectedIndex: Int) async
}
