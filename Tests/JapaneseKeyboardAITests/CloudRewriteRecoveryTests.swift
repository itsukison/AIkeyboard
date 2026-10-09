import Foundation
import XCTest
import KeyboardPreferences
@testable import JapaneseKeyboardAI

final class CloudRewriteRecoveryTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var session: URLSession!
    private var service: CloudRewriteService!
    private let request = RewriteRequest(prompt: "丁寧に", text: "確認して", locale: "ja-JP", appVersion: "test")
    private let success = #"{"candidates":[{"replacement":"ご確認ください","changed":true}],"language":"ja"}"#
    private let refreshed = #"{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600}"#

    override func setUp() {
        super.setUp()
        suite = "AIRecoveryTests.\(UUID())"
        defaults = UserDefaults(suiteName: suite)!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecoveryURLProtocol.self]
        session = URLSession(configuration: configuration)
        service = CloudRewriteService(configuration: .init(supabaseURL: URL(string: "https://recovery.invalid")!, appVersion: "test"), session: session, defaults: defaults)
        seed(expired: false)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        defaults.removePersistentDomain(forName: suite)
        RecoveryURLProtocol.handler = nil
        super.tearDown()
    }

    private func seed(expired: Bool, refresh: String? = "refresh") {
        AIAuthStore.writeTokens(accessToken: "access", refreshToken: refresh,
                                expiresAt: Date().addingTimeInterval(expired ? -60 : 3600), defaults: defaults)
    }

    func testMissingTokenNeverMakesRequest() async {
        AIAuthStore.writeTokens(accessToken: nil, refreshToken: nil, expiresAt: nil, defaults: defaults)
        RecoveryURLProtocol.handler = { _ in XCTFail("Must not send without credentials"); return (500, "{}") }
        do { _ = try await service.rewrite(request); XCTFail("Expected sign in") }
        catch { XCTAssertEqual(error as? CloudRewriteError, .notSignedIn) }
    }

    func testExpiredTokenRefreshesBeforeRewrite() async throws {
        seed(expired: true)
        var paths: [String] = []
        RecoveryURLProtocol.handler = { [self] req in
            paths.append(req.url!.path)
            if req.url!.path == "/auth/v1/token" { return (200, refreshed) }
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer new-access")
            return (200, success)
        }
        let result = try await service.rewrite(request)
        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(paths, ["/auth/v1/token", "/functions/v1/keyboard-rewrite"])
        XCTAssertEqual(AIAuthStore.readAccessToken(defaults: defaults), "new-access")
    }

    func testUnauthorizedRetriesOnceForBufferedAndStreaming() async throws {
        for streaming in [false, true] {
            seed(expired: false)
            var rewrites = 0
            var refreshes = 0
            RecoveryURLProtocol.handler = { [self] req in
                if req.url!.path == "/auth/v1/token" {
                    refreshes += 1
                    return (200, refreshed)
                }
                rewrites += 1
                return rewrites == 1 ? (401, "{}") : (200, success)
            }
            if streaming { _ = try await service.rewriteStreaming(request) { _ in } }
            else { _ = try await service.rewrite(request) }
            XCTAssertEqual(rewrites, 2)
            XCTAssertEqual(refreshes, 1)
        }
    }

    func testRepeatedUnauthorizedStopsAndRetainsCredentials() async {
        for streaming in [false, true] {
            seed(expired: false)
            var requests = 0
            RecoveryURLProtocol.handler = { [self] req in
                requests += 1
                return req.url!.path == "/auth/v1/token" ? (200, refreshed) : (401, "{}")
            }
            do {
                if streaming { _ = try await service.rewriteStreaming(request) { _ in } }
                else { _ = try await service.rewrite(request) }
                XCTFail("Expected authentication failure")
            } catch { XCTAssertEqual(error as? CloudRewriteError, .sessionRejected(accessToken: "new-access")) }
            XCTAssertEqual(requests, 3)
            XCTAssertEqual(AIAuthStore.readAccessToken(defaults: defaults), "new-access")
        }
    }

    func testMissingAndRejectedRefreshCredentialsRequireLogin() async {
        seed(expired: true, refresh: nil)
        RecoveryURLProtocol.handler = { _ in XCTFail("Must not send expired credentials"); return (500, "{}") }
        do { _ = try await service.rewrite(request); XCTFail("Expected login") }
        catch { XCTAssertEqual(error as? CloudRewriteError, .sessionRejected(accessToken: "access")) }
        seed(expired: true)
        RecoveryURLProtocol.handler = { _ in (400, #"{"code":"refresh_token_not_found"}"#) }
        do { _ = try await service.rewrite(request); XCTFail("Expected login") }
        catch { XCTAssertEqual(error as? CloudRewriteError, .sessionRejected(accessToken: "access")) }
        XCTAssertEqual(AIAuthStore.readAccessToken(defaults: defaults), "access")
    }

    func testTemporaryRefreshFailuresDoNotBecomeSignOut() async {
        for status in [429, 500, 503] {
            seed(expired: true)
            RecoveryURLProtocol.handler = { _ in (status, #"{"code":"unexpected_failure"}"#) }
            do { _ = try await service.rewrite(request); XCTFail("Expected temporary failure") }
            catch { XCTAssertEqual(error as? CloudRewriteError, .temporarilyUnavailable) }
            XCTAssertEqual(AIAuthStore.readRefreshToken(defaults: defaults), "refresh")
        }
        RecoveryURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        do { _ = try await service.rewrite(request); XCTFail("Expected network failure") }
        catch { XCTAssertTrue(error is URLError) }
        XCTAssertEqual(AIAuthStore.readAccessToken(defaults: defaults), "access")
    }

    func testMalformedRefreshDoesNotReplaceCredentials() async {
        seed(expired: true)
        RecoveryURLProtocol.handler = { _ in (200, "{}") }
        do { _ = try await service.rewrite(request); XCTFail("Expected decode failure") }
        catch { XCTAssertFalse(error as? CloudRewriteError == .notSignedIn) }
        XCTAssertEqual(AIAuthStore.readAccessToken(defaults: defaults), "access")
    }

    func testChangedCredentialsIgnoreOldRefreshSuccessAndFailure() async {
        for status in [200, 400] {
            seed(expired: true)
            RecoveryURLProtocol.handler = { [self] _ in
                AIAuthStore.writeTokens(accessToken: "other-login", refreshToken: "other-refresh",
                                        expiresAt: .distantFuture, defaults: defaults)
                return (status, status == 200 ? refreshed : #"{"code":"refresh_token_not_found"}"#)
            }
            do { _ = try await service.rewrite(request); XCTFail("Expected superseded request") }
            catch { XCTAssertEqual(error as? CloudRewriteError, .credentialsChanged) }
            XCTAssertEqual(AIAuthStore.readAccessToken(defaults: defaults), "other-login")
        }
    }

    func testStreamErrorAfterCandidateNeverRetries() async {
        var calls = 0
        RecoveryURLProtocol.handler = { _ in
            calls += 1
            return (200, "data: {\"type\":\"candidate\",\"text\":\"確認してください\"}\n\ndata: {\"type\":\"error\",\"message\":\"failed\"}\n\n")
        }
        do { _ = try await service.rewriteStreaming(request) { _ in }; XCTFail("Expected stream error") }
        catch { XCTAssertEqual(error as? CloudRewriteError, .backend("failed")) }
        XCTAssertEqual(calls, 1)
    }
}

private final class RecoveryURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, body) = try Self.handler!(request)
            let contentType = body.hasPrefix("data:") ? "text/event-stream" : "application/json"
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                           headerFields: ["Content-Type": contentType])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
