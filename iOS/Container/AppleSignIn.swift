import AuthenticationServices
import CryptoKit
import SwiftUI

/// A fresh raw nonce is generated per Sign in with Apple request. Its SHA-256
/// hash is sent to Apple (Apple embeds it in the signed identity token) and the
/// raw value is handed to Supabase, which re-hashes it to prove the token was
/// minted for this request. Without it Supabase can't bind the token to us.
enum AppleNonce {
    /// 64-char URL-safe set: 256 % 64 == 0, so `byte % 64` is bias-free.
    private static let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_")

    static func random(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// HIG-compliant "Continue with Apple" button. One button covers both first
/// sign-up and returning sign-in — `UserSession.signInWithApple` decides which.
struct AppleSignInButton: View {
    @EnvironmentObject private var session: UserSession
    @Environment(\.colorScheme) private var colorScheme
    var onError: (String) -> Void = { _ in }

    @State private var currentNonce: String?

    var body: some View {
        SignInWithAppleButton(.continue, onRequest: configure, onCompletion: handle)
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(Capsule())
    }

    private func configure(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleNonce.random()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleNonce.sha256(nonce)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                onError(localizedAppString("Appleサインインに失敗しました。時間をおいて再度お試しください。"))
                return
            }
            Task {
                do {
                    try await session.signInWithApple(
                        idToken: idToken,
                        nonce: nonce,
                        fullName: credential.fullName
                    )
                } catch {
                    onError(japaneseAuthErrorMessage(for: error))
                    AppAnalytics.capture("apple_sign_in_error", properties: [
                        "error_message": error.localizedDescription,
                    ])
                }
            }
        case let .failure(error):
            // User-cancelled dismissal is not an error worth surfacing.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            onError(japaneseAuthErrorMessage(for: error))
        }
    }
}
