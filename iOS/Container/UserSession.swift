import AuthenticationServices
import Foundation
import KeyboardPreferences
import Supabase
import UIKit

@MainActor
final class UserSession: ObservableObject {
    struct Profile: Equatable {
        let id: UUID
        let displayName: String
        let email: String
        let createdAt: Date
    }

    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(Profile)
    }

    @Published private(set) var state: State
    @Published private(set) var bootstrapFailed = false
    private var observingAuthChanges = false
    private var googleAuthenticationSession: ASWebAuthenticationSession?

    init(initialState: State = .loading) {
        self.state = initialState
    }

    var profile: Profile? {
        if case let .signedIn(profile) = state { return profile }
        return nil
    }

    var displayName: String {
        profile?.displayName ?? ""
    }

    func bootstrap() async {
        bootstrapFailed = false
        do {
            let session = try await supabase.auth.session
            let profile = try await loadProfile(for: session.user)
            persistTokens(from: session)
            state = .signedIn(profile)
            // Lowercased to match the edge function's distinct_id (Supabase's canonical
        // form) — uppercase `uuidString` split every user into two PostHog persons.
        AppAnalytics.identify(profile.id.uuidString.lowercased(), userProperties: identifyProperties(for: profile))
            // Retry a carry-up that failed at sign-in: without this, one failed
            // request loses an authored button permanently.
            await mergePendingOnboardingButtons(for: profile.id)
            try? await refreshUserPromptsCache(for: profile.id)
        } catch let error as AuthError where AIAuthFailure.requiresSignIn(code: error.errorCode.rawValue) {
            clearTokens()
            UserPromptStore.writeEntries(UserPromptDefaults.seedEntries())
            state = .signedOut
        } catch {
            bootstrapFailed = true
            return
        }

        guard !observingAuthChanges else { return }
        observingAuthChanges = true
        Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .signedOut, .userDeleted:
                    self.clearTokens()
                    UserPromptStore.writeEntries(UserPromptDefaults.seedEntries())
                    self.state = .signedOut
                case .signedIn, .tokenRefreshed, .userUpdated:
                    if let session {
                        self.persistTokens(from: session)
                    }
                    if let user = session?.user,
                       let profile = try? await self.loadProfile(for: user) {
                        self.state = .signedIn(profile)
                        try? await self.refreshUserPromptsCache(for: profile.id)
                    }
                default:
                    break
                }
            }
        }
    }

    /// Explicit keyboard recovery also republishes a valid container session.
    func recoverKeyboardSession() async throws -> Bool {
        guard profile != nil else { return false }
        do {
            let refreshed = try await supabase.auth.refreshSession()
            persistTokens(from: refreshed)
            return true
        } catch let error as AuthError where AIAuthFailure.requiresSignIn(code: error.errorCode.rawValue) {
            clearTokens()
            state = .signedOut
            return false
        }
    }

    func deleteAccount() async throws {
        try await supabase.functions.invoke("delete-account")
        AppAnalytics.capture("account_deleted")
        AppAnalytics.reset()
        try? await supabase.auth.signOut()
        clearTokens()
        UserPromptStore.writeEntries(UserPromptDefaults.seedEntries())
        state = .signedOut
    }

    func submitFeedback(category: String, message: String, appVersion: String) async throws {
        struct Body: Encodable {
            let category: String
            let message: String
            let appVersion: String
        }
        try await supabase.functions.invoke(
            "submit-feedback",
            options: FunctionInvokeOptions(
                body: Body(category: category, message: message, appVersion: appVersion)
            )
        )
    }

    func signUp(name: String, email: String, password: String) async throws {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(name)]
        )
        let profile = try await loadProfile(for: response.user, fallbackName: name)
        // Lowercased to match the edge function's distinct_id (Supabase's canonical
        // form) — uppercase `uuidString` split every user into two PostHog persons.
        AppAnalytics.identify(profile.id.uuidString.lowercased(), userProperties: identifyProperties(for: profile))
        AppAnalytics.capture("signed_up", properties: ["auth_provider": "email"])
        state = .signedIn(profile)
        await syncCommercialConsent(for: profile.id)
        // Brand-new account: carry up onboarding prompt edits/reordering before
        // the local cache is overwritten with the server-seeded set.
        await applyPendingOnboardingPrompts(for: profile.id)
        try? await refreshUserPromptsCache(for: profile.id)
    }

    /// Sign in (or first-time sign up) with an Apple identity token. One entry
    /// point handles both because Apple's button doesn't distinguish them; the
    /// `lastSignInAt`/`createdAt` gap tells a fresh account from a returning one.
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
        let user = session.user

        // Apple sends the name only on the FIRST authorization; the
        // handle_new_user trigger seeds display_name empty for OAuth sign-ups, so
        // persist it now or later launches fall back to the (often relayed) email.
        let appleName = fullName
            .map { PersonNameComponentsFormatter().string(from: $0).trimmingCharacters(in: .whitespaces) }
            .flatMap { $0.isEmpty ? nil : $0 }
        if let appleName {
            try? await supabase
                .from("profiles")
                .update(["display_name": appleName])
                .eq("id", value: user.id)
                .execute()
        }

        let profile = try await loadProfile(for: user, fallbackName: appleName)
        // Lowercased to match the edge function's distinct_id (Supabase's canonical
        // form) — uppercase `uuidString` split every user into two PostHog persons.
        AppAnalytics.identify(profile.id.uuidString.lowercased(), userProperties: identifyProperties(for: profile))
        state = .signedIn(profile)
        await syncCommercialConsent(for: profile.id)

        if isNewlyCreated(user) {
            AppAnalytics.capture("signed_up", properties: ["auth_provider": "apple"])
            // Brand-new account: carry up onboarding prompt edits/reordering before
            // the local cache is overwritten with the server-seeded set.
            await applyPendingOnboardingPrompts(for: profile.id)
        } else {
            AppAnalytics.capture("signed_in", properties: ["auth_provider": "apple"])
            await mergePendingOnboardingButtons(for: profile.id)
        }
        try? await refreshUserPromptsCache(for: profile.id)
    }

    func signInWithGoogle() async throws {
        let session = try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: SupabaseConfig.oauthRedirectURL
        ) { [weak self] authorizationURL in
            guard let self else { throw CancellationError() }
            return try await self.authenticateWithGoogle(
                at: SupabaseConfig.brandedAuthURL(from: authorizationURL)
            )
        }
        let user = session.user
        let googleName = ["full_name", "name", "display_name"]
            .compactMap { user.userMetadata[$0]?.stringValue?.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }

        if isNewlyCreated(user), let googleName {
            try? await supabase
                .from("profiles")
                .update(["display_name": googleName])
                .eq("id", value: user.id)
                .execute()
        }

        let profile = try await loadProfile(for: user, fallbackName: googleName)
        AppAnalytics.identify(
            profile.id.uuidString.lowercased(),
            userProperties: identifyProperties(for: profile)
        )
        state = .signedIn(profile)
        await syncCommercialConsent(for: profile.id)

        if isNewlyCreated(user) {
            AppAnalytics.capture("signed_up", properties: ["auth_provider": "google"])
            await applyPendingOnboardingPrompts(for: profile.id)
        } else {
            AppAnalytics.capture("signed_in", properties: ["auth_provider": "google"])
            await mergePendingOnboardingButtons(for: profile.id)
        }
        try? await refreshUserPromptsCache(for: profile.id)
    }

    private func authenticateWithGoogle(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let authenticationSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: SupabaseConfig.oauthRedirectURL.scheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    self?.googleAuthenticationSession = nil
                }
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? URLError(.cancelled))
                }
            }
            authenticationSession.presentationContextProvider = OAuthPresentationContextProvider.shared
            authenticationSession.prefersEphemeralWebBrowserSession = false
            googleAuthenticationSession = authenticationSession

            guard authenticationSession.start() else {
                googleAuthenticationSession = nil
                continuation.resume(throwing: URLError(.cannotLoadFromNetwork))
                return
            }
        }
    }

    /// A just-created account signs in within a moment of creation; a returning
    /// user's `createdAt` is far behind this sign-in.
    private func isNewlyCreated(_ user: User) -> Bool {
        guard let lastSignInAt = user.lastSignInAt else { return true }
        return lastSignInAt.timeIntervalSince(user.createdAt) < 5
    }

    func signIn(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(email: email, password: password)
        let profile = try await loadProfile(for: session.user)
        // Lowercased to match the edge function's distinct_id (Supabase's canonical
        // form) — uppercase `uuidString` split every user into two PostHog persons.
        AppAnalytics.identify(profile.id.uuidString.lowercased(), userProperties: identifyProperties(for: profile))
        AppAnalytics.capture("signed_in", properties: ["auth_provider": "email"])
        state = .signedIn(profile)
        await syncCommercialConsent(for: profile.id)
        await mergePendingOnboardingButtons(for: profile.id)
        try? await refreshUserPromptsCache(for: profile.id)
    }

    /// Applies onboarding-time prompt edits/reordering to the new account's
    /// seeded rows. Falls back to the old main-only pending value for users who
    /// started onboarding before the full-list editor shipped.
    private func applyPendingOnboardingPrompts(for userId: UUID) async {
        guard let pending = KeyboardSettingsStore.readPendingOnboardingPromptEntries() else {
            await applyPendingOnboardingMainPrompt(for: userId)
            return
        }
        do {
            // The pending set is only stored when it differs from the seeded
            // default (a use-case preset or a hand-edited set), so replace the
            // trigger-seeded rows wholesale — presets may add, drop, reorder, or
            // include custom buttons the seeded four can't represent.
            try await UserPromptRemoteStore.replaceAll(pending, userId: userId)
            KeyboardSettingsStore.clearPendingOnboardingPromptEntries()
            KeyboardSettingsStore.clearPendingOnboardingMainPrompt()
        } catch {
            // Leave it pending; the refresh below still yields a usable default set.
        }
    }

    /// Signing in to an account that already exists: its saved prompts win, so a
    /// 敬語 edit made during onboarding is still discarded — the account's own main
    /// is the one that user has been typing with. A button the builder made is not
    /// an edit: it exists only on this device, and dropping it deleted work the
    /// user had just authored. Append it as a sub button instead.
    private func mergePendingOnboardingButtons(for userId: UUID) async {
        KeyboardSettingsStore.clearPendingOnboardingMainPrompt()
        guard let pending = KeyboardSettingsStore.readPendingOnboardingPromptEntries() else { return }
        let built = pending.filter { $0.origin == .onboardingBuilder }
        guard !built.isEmpty else {
            KeyboardSettingsStore.clearPendingOnboardingPromptEntries()
            return
        }
        do {
            try await UserPromptRemoteStore.appendMissing(built, userId: userId)
            KeyboardSettingsStore.clearPendingOnboardingPromptEntries()
            AppAnalytics.capture("onboarding_buttons_merged", properties: [
                "count": built.count,
                "onboarding_version": InteractiveOnboardingState.version,
            ])
        } catch {
            // Leave it pending; `bootstrap()` retries on the next launch rather
            // than losing an authored button to one failed request.
        }
    }

    /// Applies an onboarding-time 敬語 edit to the new account's main prompt row.
    /// No-op when nothing is pending or the server hasn't seeded a main row.
    private func applyPendingOnboardingMainPrompt(for userId: UUID) async {
        guard let pending = KeyboardSettingsStore.readPendingOnboardingMainPrompt() else { return }
        do {
            let entries = try await UserPromptRemoteStore.fetchEntries(for: userId)
            guard let main = entries.first(where: { $0.slot == .main }) else { return }
            try await UserPromptRemoteStore.updatePrompt(
                id: main.id,
                title: pending.title,
                prompt: pending.prompt,
                isEnabled: true,
                sortOrder: main.sortOrder,
                purpose: main.purpose,
                userId: userId
            )
            KeyboardSettingsStore.clearPendingOnboardingMainPrompt()
        } catch {
            // Leave it pending; the refresh below still yields a usable default set.
        }
    }

    /// Propagates a commercial data-use opt-in chosen during onboarding (before
    /// sign-in) up to the server-side consent record. Only pushes an opt-in, so
    /// it never clobbers a server value with a fresh device's local default.
    private func syncCommercialConsent(for userId: UUID) async {
        guard KeyboardSettingsStore.readAICommercialOptIn() else { return }
        try? await AIConsentRemoteStore.setCommercialOptIn(true, for: userId)
    }

    func signOut() async {
        AppAnalytics.capture("signed_out")
        AppAnalytics.reset()
        try? await supabase.auth.signOut()
        clearTokens()
        UserPromptStore.writeEntries(UserPromptDefaults.seedEntries())
        state = .signedOut
    }

    private func identifyProperties(for profile: Profile) -> [String: Any] {
        var properties: [String: Any] = [
            "name": profile.displayName,
            "email": profile.email,
        ]
        if let source = UserDefaults.standard.string(forKey: OnboardingSourceStore.key), !source.isEmpty {
            properties["acquisition_source"] = source
        }
        return properties
    }

    private func persistTokens(from session: Session) {
        AIAuthStore.writeTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
    }

    private func clearTokens() {
        AIAuthStore.writeTokens(accessToken: nil, refreshToken: nil, expiresAt: nil)
    }

    func refreshUserPromptsCache() async throws {
        guard let profile else {
            UserPromptStore.writeEntries(UserPromptDefaults.seedEntries())
            return
        }
        try await refreshUserPromptsCache(for: profile.id)
    }

    /// Returns the current Supabase access token, refreshing the session if needed.
    /// Returns nil if the user is not signed in.
    func currentAccessToken() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.accessToken
        } catch {
            return nil
        }
    }

    private func loadProfile(for user: User, fallbackName: String? = nil) async throws -> Profile {
        struct Row: Decodable {
            let id: UUID
            let display_name: String
            let created_at: Date
        }

        let row: Row = try await supabase
            .from("profiles")
            .select("id, display_name, created_at")
            .single()
            .execute()
            .value

        return Profile(
            id: row.id,
            displayName: row.display_name.isEmpty ? (fallbackName ?? user.email ?? "") : row.display_name,
            email: user.email ?? "",
            createdAt: row.created_at
        )
    }

    private func refreshUserPromptsCache(for userId: UUID) async throws {
        let entries = try await UserPromptRemoteStore.fetchEntries(for: userId)
        UserPromptStore.writeEntries(entries)
    }
}

@MainActor
private final class OAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthPresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
    }
}
