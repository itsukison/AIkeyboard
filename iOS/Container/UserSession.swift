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
            try? await refreshUserPromptsCache(for: profile.id)
        } catch {
            clearTokens()
            UserPromptStore.writeEntries([])
            state = .signedOut
        }

        Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .signedOut, .userDeleted:
                    self.clearTokens()
                    UserPromptStore.writeEntries([])
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
        try? await supabase.auth.signOut()
        clearTokens()
        UserPromptStore.writeEntries([])
        state = .signedOut
    }

    func signUp(name: String, email: String, password: String) async throws {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(name)]
        )
        let profile = try await loadProfile(for: response.user, fallbackName: name)
        state = .signedIn(profile)
        try? await refreshUserPromptsCache(for: profile.id)
    }

    func signIn(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(email: email, password: password)
        let profile = try await loadProfile(for: session.user)
        state = .signedIn(profile)
        try? await refreshUserPromptsCache(for: profile.id)
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        clearTokens()
        UserPromptStore.writeEntries([])
        state = .signedOut
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
            UserPromptStore.writeEntries([])
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
