import Foundation

public protocol RewriteService: Sendable {
    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult
}
