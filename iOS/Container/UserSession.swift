import Foundation
import KeyboardPreferences
import Supabase

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
        do {
            let session = try await supabase.auth.session
            let profile = try await loadProfile(for: session.user)
            persistTokens(from: session)
            state = .signedIn(profile)
            // Lowercased to match the edge function's distinct_id (Supabase's canonical
        // form) — uppercase `uuidString` split every user into two PostHog persons.
        AppAnalytics.identify(profile.id.uuidString.lowercased(), userProperties: identifyProperties(for: profile))
            try? await refreshUserPromptsCache(for: profile.id)
        } catch {
            clearTokens()
            UserPromptStore.writeEntries(UserPromptDefaults.seedEntries())
            state = .signedOut
        }

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
        AppAnalytics.capture("signed_up")
        state = .signedIn(profile)
        await syncCommercialConsent(for: profile.id)
        // Brand-new account: carry up onboarding prompt edits/reordering before
        // the local cache is overwritten with the server-seeded set.
        await applyPendingOnboardingPrompts(for: profile.id)
        try? await refreshUserPromptsCache(for: profile.id)
    }

    func signIn(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(email: email, password: password)
        let profile = try await loadProfile(for: session.user)
        // Lowercased to match the edge function's distinct_id (Supabase's canonical
        // form) — uppercase `uuidString` split every user into two PostHog persons.
        AppAnalytics.identify(profile.id.uuidString.lowercased(), userProperties: identifyProperties(for: profile))
        AppAnalytics.capture("signed_in")
        state = .signedIn(profile)
        await syncCommercialConsent(for: profile.id)
        // Existing account: its saved prompts win, so discard any onboarding edit
        // rather than clobber the server set.
        KeyboardSettingsStore.clearPendingOnboardingMainPrompt()
        KeyboardSettingsStore.clearPendingOnboardingPromptEntries()
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
            let serverEntries = try await UserPromptRemoteStore.fetchEntries(for: userId)
            let serverByBuiltin = Dictionary(
                serverEntries.compactMap { entry -> (String, UserPrompt)? in
                    guard let key = entry.builtinKey else { return nil }
                    return (key, entry)
                },
                uniquingKeysWith: { first, _ in first }
            )
            var orderedForServer: [UserPrompt] = []
            for pendingEntry in pending {
                guard let key = pendingEntry.builtinKey, var serverEntry = serverByBuiltin[key] else {
                    continue
                }
                try await UserPromptRemoteStore.updatePrompt(
                    id: serverEntry.id,
                    title: pendingEntry.title,
                    prompt: pendingEntry.prompt,
                    isEnabled: pendingEntry.isEnabled,
                    sortOrder: pendingEntry.sortOrder,
                    userId: userId
                )
                serverEntry.slot = pendingEntry.slot
                serverEntry.title = pendingEntry.title
                serverEntry.prompt = pendingEntry.prompt
                serverEntry.isEnabled = pendingEntry.isEnabled
                serverEntry.sortOrder = pendingEntry.sortOrder
                orderedForServer.append(serverEntry)
            }
            if !orderedForServer.isEmpty {
                try await UserPromptRemoteStore.updateOrdering(orderedForServer, userId: userId)
            }
            KeyboardSettingsStore.clearPendingOnboardingPromptEntries()
            KeyboardSettingsStore.clearPendingOnboardingMainPrompt()
        } catch {
            // Leave it pending; the refresh below still yields a usable default set.
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
