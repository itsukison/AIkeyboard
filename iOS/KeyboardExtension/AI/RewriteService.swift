import JapaneseKeyboardUI

protocol RewriteService: Sendable {
    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult
}
