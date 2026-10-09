import Foundation
import KeyboardPreferences

public struct CloudRewriteConfiguration: Sendable {
    public static let defaultSupabaseURL = URL(string: "https://eercsucvxnszqletxued.supabase.co")!
    public static let defaultPublishableKey = "sb_publishable_S8rEoVqCOV8iVGfDEErI6w_Slb79nCO"

    public let endpoint: URL
    public let supabaseURL: URL
    public let publishableKey: String
    public let appVersion: String

    public init(
        supabaseURL: URL = CloudRewriteConfiguration.defaultSupabaseURL,
        publishableKey: String = CloudRewriteConfiguration.defaultPublishableKey,
        appVersion: String
    ) {
        self.endpoint = supabaseURL.appendingPathComponent("functions/v1/keyboard-rewrite")
        self.supabaseURL = supabaseURL
        self.publishableKey = publishableKey
        self.appVersion = appVersion
    }
}

public enum CloudRewriteError: Error, Equatable {
    case notSignedIn
    case sessionRejected(accessToken: String)
    case credentialsChanged
    case temporarilyUnavailable
    case invalidResponse
    case backend(String)
}

public final class CloudRewriteService: RewriteService, @unchecked Sendable {
    private let configuration: CloudRewriteConfiguration
    private let session: URLSession
    private let defaults: UserDefaults?

    public init(configuration: CloudRewriteConfiguration, session: URLSession = .shared,
                defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) {
        self.configuration = configuration
        self.session = session
        self.defaults = defaults
    }

    public func rewrite(_ request: RewriteRequest) async throws -> RewriteResult {
        let accessToken = try await ensureFreshAccessToken()
        return try await rewrite(request, accessToken: accessToken, canRetry: true)
    }

    private func rewrite(_ request: RewriteRequest, accessToken: String, canRetry: Bool) async throws -> RewriteResult {
        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.timeoutInterval = 20
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw CloudRewriteError.invalidResponse
        }

        if http.statusCode == 401 {
            guard canRetry else { throw authenticationFailure(for: accessToken) }
            let refreshed = try await tokenAfterUnauthorized(accessToken)
            return try await rewrite(request, accessToken: refreshed, canRetry: false)
        }
        if http.statusCode == 429 || http.statusCode >= 500 { throw CloudRewriteError.temporarilyUnavailable }
        if (200..<300).contains(http.statusCode) {
            return try JSONDecoder().decode(RewriteResult.self, from: data)
        }

        if let payload = try? JSONDecoder().decode(CloudRewriteErrorPayload.self, from: data) {
            throw CloudRewriteError.backend(payload.error.message)
        }

        throw CloudRewriteError.backend("AI rewrite failed.")
    }

    public func rewriteStreaming(
        _ request: RewriteRequest,
        onCandidate: @escaping @Sendable (RewriteCandidate) -> Void
    ) async throws -> RewriteResult {
        let accessToken = try await ensureFreshAccessToken()
        return try await rewriteStreaming(request, accessToken: accessToken, canRetry: true, onCandidate: onCandidate)
    }

    private func rewriteStreaming(
        _ request: RewriteRequest, accessToken: String, canRetry: Bool,
        onCandidate: @escaping @Sendable (RewriteCandidate) -> Void
    ) async throws -> RewriteResult {
        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.timeoutInterval = 20
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (bytes, response) = try await session.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw CloudRewriteError.invalidResponse
        }

        if http.statusCode == 401 {
            _ = try await Self.collect(bytes)
            guard canRetry else { throw authenticationFailure(for: accessToken) }
            let refreshed = try await tokenAfterUnauthorized(accessToken)
            return try await rewriteStreaming(request, accessToken: refreshed, canRetry: false, onCandidate: onCandidate)
        }
        if http.statusCode == 429 || http.statusCode >= 500 { throw CloudRewriteError.temporarilyUnavailable }
        guard (200..<300).contains(http.statusCode) else {
            let data = try await Self.collect(bytes)
            if let payload = try? JSONDecoder().decode(CloudRewriteErrorPayload.self, from: data) {
                throw CloudRewriteError.backend(payload.error.message)
            }
            throw CloudRewriteError.backend("AI rewrite failed.")
        }

        // The backend falls back to a buffered JSON response when it can't open
        // a stream, so a streaming request can still legitimately get one back.
        guard (http.value(forHTTPHeaderField: "Content-Type") ?? "").contains("text/event-stream") else {
            let result = try JSONDecoder().decode(RewriteResult.self, from: try await Self.collect(bytes))
            result.candidates.forEach(onCandidate)
            return result
        }

        var collected: [RewriteCandidate] = []
        var language = "ja"
        var eventId: String?

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let raw = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let event = try? JSONDecoder().decode(
                RewriteStreamEvent.self, from: Data(raw.utf8)
            ) else { continue }

            switch event.type {
            case "candidate":
                guard let text = event.text else { continue }
                let candidate = RewriteCandidate(replacement: text, changed: event.changed ?? true)
                collected.append(candidate)
                onCandidate(candidate)
            case "done":
                language = event.language ?? language
                eventId = event.eventId
            case "error":
                throw CloudRewriteError.backend(event.message ?? "AI rewrite failed.")
            default:
                continue
            }
        }

        guard !collected.isEmpty else { throw CloudRewriteError.invalidResponse }
        return RewriteResult(candidates: collected, language: language, eventId: eventId)
    }

    private static func collect(_ bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes { data.append(byte) }
        return data
    }

    public func submitSelection(eventId: String, selectedIndex: Int) async {
        guard let accessToken = try? await ensureFreshAccessToken() else { return }

        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.timeoutInterval = 10
        urlRequest.httpBody = try? JSONEncoder().encode(
            SelectionFeedback(
                eventId: eventId,
                selectedIndex: selectedIndex,
                analyticsAppInstanceId: KeyboardSettingsStore.readAnalyticsAppInstanceId()
            )
        )

        _ = try? await session.data(for: urlRequest)
    }

    /// Reports a user action on a result (e.g. `regenerated`, `dismissed`) to
    /// the originating rewrite event. Fire-and-forget, like `submitSelection`.
    public func submitAction(
        eventId: String,
        action: String,
        selectedIndex: Int? = nil,
        latencyMs: Int? = nil
    ) async {
        guard let accessToken = try? await ensureFreshAccessToken() else { return }

        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.timeoutInterval = 10
        urlRequest.httpBody = try? JSONEncoder().encode(
            ActionFeedback(
                eventId: eventId,
                action: action,
                selectedIndex: selectedIndex,
                latencyMs: latencyMs,
                analyticsAppInstanceId: KeyboardSettingsStore.readAnalyticsAppInstanceId()
            )
        )

        _ = try? await session.data(for: urlRequest)
    }

    private func authenticationFailure(for token: String) -> CloudRewriteError {
        AIAuthStore.readAccessToken(defaults: defaults) == token ? .sessionRejected(accessToken: token) : .credentialsChanged
    }

    private func tokenAfterUnauthorized(_ rejected: String) async throws -> String {
        if let latest = AIAuthStore.readAccessToken(defaults: defaults), latest != rejected { return latest }
        guard let refresh = AIAuthStore.readRefreshToken(defaults: defaults) else {
            throw authenticationFailure(for: rejected)
        }
        return try await refreshAccessToken(refreshToken: refresh)
    }

    private func ensureFreshAccessToken() async throws -> String {
        guard let accessToken = AIAuthStore.readAccessToken(defaults: defaults) else {
            throw CloudRewriteError.notSignedIn
        }
        let expiresAt = AIAuthStore.readExpiresAt(defaults: defaults) ?? .distantPast
        if Date().addingTimeInterval(30) < expiresAt { return accessToken }
        guard let refreshToken = AIAuthStore.readRefreshToken(defaults: defaults) else {
            if expiresAt > Date() { return accessToken }
            throw authenticationFailure(for: accessToken)
        }
        return try await refreshAccessToken(refreshToken: refreshToken)
    }

    private func refreshAccessToken(refreshToken: String) async throws -> String {
        let originalAccessToken = AIAuthStore.readAccessToken(defaults: defaults)
        let url = configuration.supabaseURL.appendingPathComponent("auth/v1/token")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]

        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(configuration.publishableKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let (data, response) = try await session.data(for: req)
        guard AIAuthStore.readAccessToken(defaults: defaults) == originalAccessToken,
              AIAuthStore.readRefreshToken(defaults: defaults) == refreshToken else {
            throw CloudRewriteError.credentialsChanged
        }
        guard let http = response as? HTTPURLResponse else { throw CloudRewriteError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let failure = try? JSONDecoder().decode(RefreshFailure.self, from: data)
            if (400..<500).contains(http.statusCode), http.statusCode != 429,
               AIAuthFailure.requiresSignIn(code: failure?.code ?? failure?.error_code ?? failure?.error ?? "") {
                guard let originalAccessToken else { throw CloudRewriteError.notSignedIn }
                throw authenticationFailure(for: originalAccessToken)
            }
            throw CloudRewriteError.temporarilyUnavailable
        }
        let payload = try JSONDecoder().decode(RefreshResponse.self, from: data)
        guard !payload.access_token.isEmpty, !payload.refresh_token.isEmpty, payload.expires_in > 0 else {
            throw CloudRewriteError.invalidResponse
        }
        AIAuthStore.writeTokens(
            accessToken: payload.access_token,
            refreshToken: payload.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(payload.expires_in)),
            defaults: defaults
        )
        return payload.access_token
    }
}

private struct SelectionFeedback: Encodable {
    let eventId: String
    let selectedIndex: Int
    let analyticsAppInstanceId: String?
}

private struct ActionFeedback: Encodable {
    let eventId: String
    let action: String
    let selectedIndex: Int?
    let latencyMs: Int?
    let analyticsAppInstanceId: String?
}

private struct RewriteStreamEvent: Decodable {
    let type: String
    let text: String?
    let changed: Bool?
    let language: String?
    let eventId: String?
    let message: String?
}

private struct CloudRewriteErrorPayload: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
    }
    let error: Body
}

private struct RefreshResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
}

private struct RefreshFailure: Decodable {
    let code: String?
    let error_code: String?
    let error: String?
}
