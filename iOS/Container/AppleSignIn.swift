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

/// One button covers both first sign-up and returning sign-in —
/// `UserSession.signInWithApple` decides which.
struct AppleSignInButton: View {
    @EnvironmentObject private var session: UserSession
    @Environment(\.colorScheme) private var colorScheme
    var onStart: () -> Void = {}
    var onError: (String) -> Void = { _ in }

    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(colorScheme == .dark ? Color.white : Color.black)

            Image(systemName: "apple.logo")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .allowsHitTesting(false)

            SignInWithAppleButton(.continue, onRequest: configure, onCompletion: handle)
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .opacity(0)
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .accessibilityLabel(Text("Appleで続ける"))
        .accessibilityAddTraits(.isButton)
    }

    private func configure(_ request: ASAuthorizationAppleIDRequest) {
        onStart()
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

struct GoogleSignInButton: View {
    @EnvironmentObject private var session: UserSession

    var onStart: () -> Void = {}
    var onError: (String) -> Void = { _ in }

    @State private var isLoading = false

    var body: some View {
        Button(action: authenticate) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255))
                } else {
                    Image("BrandGoogle")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 56, height: 56)
            .background(Color.white, in: Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color(red: 116 / 255, green: 119 / 255, blue: 117 / 255), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.78 : 1)
        .accessibilityLabel(Text("Googleで続ける"))
    }

    private func authenticate() {
        onStart()
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await session.signInWithGoogle()
            } catch {
                if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return }
                onError(japaneseAuthErrorMessage(for: error))
                AppAnalytics.capture("google_sign_in_error", properties: [
                    "error_message": error.localizedDescription,
                ])
            }
        }
    }
}
