import PostHog
import SwiftUI

enum AuthField: Hashable {
    case name
    case email
    case password
}

struct SignUpForm: View {
    @EnvironmentObject private var session: UserSession
    @AppStorage("aikJP.pendingPostAuthOnboarding") private var pendingPostAuthOnboarding = false
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @FocusState private var focusedField: AuthField?

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@")
            && password.count >= 6
            && !isSubmitting
    }

    var body: some View {
        AuthFormScaffold(
            title: "アカウントを\n作成する",
            subtitle: "よく使うプロンプトを保存できます。",
            progress: 0.32,
            ctaTitle: "アカウントを作成",
            isCtaEnabled: canSubmit,
            isCtaLoading: isSubmitting,
            errorMessage: errorMessage,
            onBack: { dismiss() },
            onCta: submit
        ) {
            VStack(spacing: 14) {
                AuthTextField(
                    label: "お名前",
                    text: $name,
                    field: .name,
                    focused: $focusedField,
                    autocapitalization: .words,
                    textContentType: .name,
                    submitLabel: .next,
                    onSubmit: { focusedField = .email }
                )
                AuthTextField(
                    label: "メールアドレス",
                    text: $email,
                    field: .email,
                    focused: $focusedField,
                    keyboardType: .emailAddress,
                    autocapitalization: .never,
                    textContentType: .emailAddress,
                    submitLabel: .next,
                    onSubmit: { focusedField = .password }
                )
                AuthTextField(
                    label: "パスワード (6文字以上)",
                    text: $password,
                    field: .password,
                    focused: $focusedField,
                    textContentType: .newPassword,
                    submitLabel: .go,
                    isSecure: true,
                    onSubmit: { if canSubmit { submit() } }
                )
            }
        }
        .bikeyKeyboardToolbar { focusedField = nil }
    }

    private func submit() {
        focusedField = nil
        errorMessage = nil
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await session.signUp(
                    name: name.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                pendingPostAuthOnboarding = true
            } catch {
                let message = japaneseAuthErrorMessage(for: error)
                errorMessage = message
                PostHogSDK.shared.capture("sign_up_error", properties: [
                    "error_message": error.localizedDescription,
                ])
            }
        }
    }
}

struct SignInForm: View {
    @EnvironmentObject private var session: UserSession
    @AppStorage("aikJP.pendingPostAuthOnboarding") private var pendingPostAuthOnboarding = false
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @FocusState private var focusedField: AuthField?

    private var canSubmit: Bool {
        email.contains("@") && !password.isEmpty && !isSubmitting
    }

    var body: some View {
        AuthFormScaffold(
            title: "おかえりなさい",
            subtitle: "保存したプロンプトを引き継ぎます。",
            progress: 0.32,
            ctaTitle: "サインイン",
            isCtaEnabled: canSubmit,
            isCtaLoading: isSubmitting,
            errorMessage: errorMessage,
            onBack: { dismiss() },
            onCta: submit
        ) {
            VStack(spacing: 14) {
                AuthTextField(
                    label: "メールアドレス",
                    text: $email,
                    field: .email,
                    focused: $focusedField,
                    keyboardType: .emailAddress,
                    autocapitalization: .never,
                    textContentType: .emailAddress,
                    submitLabel: .next,
                    onSubmit: { focusedField = .password }
                )
                AuthTextField(
                    label: "パスワード",
                    text: $password,
                    field: .password,
                    focused: $focusedField,
                    textContentType: .password,
                    submitLabel: .go,
                    isSecure: true,
                    onSubmit: { if canSubmit { submit() } }
                )
            }
        }
        .bikeyKeyboardToolbar { focusedField = nil }
    }

    private func submit() {
        focusedField = nil
        errorMessage = nil
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await session.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                pendingPostAuthOnboarding = true
            } catch {
                let message = japaneseAuthErrorMessage(for: error)
                errorMessage = message
                PostHogSDK.shared.capture("sign_in_error", properties: [
                    "error_message": error.localizedDescription,
                ])
            }
        }
    }
}

// MARK: - Scaffold

private struct AuthFormScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    let progress: Double
    let ctaTitle: String
    let isCtaEnabled: Bool
    var isCtaLoading: Bool = false
    let errorMessage: String?
    let onBack: () -> Void
    let onCta: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: onBack,
            onSkip: nil,
            ctaTitle: ctaTitle,
            isCtaEnabled: isCtaEnabled,
            isCtaLoading: isCtaLoading,
            onCta: onCta
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(OnboardingPalette.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(OnboardingPalette.subInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 28)

                    content()

                    if let errorMessage {
                        AuthErrorLabel(message: errorMessage)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: - Auth text field

struct AuthTextField<Field: Hashable>: View {
    let label: String
    @Binding var text: String
    let field: Field
    var focused: FocusState<Field?>.Binding

    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .return
    var isSecure: Bool = false
    var onSubmit: (() -> Void)? = nil

    @State private var isPasswordVisible: Bool = false

    private var isFocused: Bool { focused.wrappedValue == field }
    private var hasContent: Bool { !text.isEmpty }
    private var labelFloated: Bool { isFocused || hasContent }

    var body: some View {
        ZStack(alignment: .leading) {
            inputField
            floatingLabel
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OnboardingPalette.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isFocused ? OnboardingPalette.ink.opacity(0.65) : OnboardingPalette.fieldStroke,
                    lineWidth: isFocused ? 1.4 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
        .overlay(alignment: .trailing) {
            trailingAccessory
                .padding(.trailing, 14)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: labelFloated)
        .animation(.easeInOut(duration: 0.18), value: isFocused)
        .contentShape(Rectangle())
        .onTapGesture { focused.wrappedValue = field }
    }

    @ViewBuilder
    private var inputField: some View {
        let prompt = Text(labelFloated ? "" : label).foregroundColor(OnboardingPalette.subInk.opacity(0.65))
        Group {
            if isSecure && !isPasswordVisible {
                SecureField("", text: $text, prompt: prompt)
            } else {
                TextField("", text: $text, prompt: prompt)
            }
        }
        .keyboardType(keyboardType)
        .textInputAutocapitalization(isSecure ? .never : autocapitalization)
        .autocorrectionDisabled(true)
        .textContentType(textContentType)
        .submitLabel(submitLabel)
        .focused(focused, equals: field)
        .foregroundStyle(OnboardingPalette.ink)
        .font(.system(size: 17, weight: .regular))
        .padding(.top, labelFloated ? 14 : 0)
        .padding(.trailing, trailingPadding)
        .onSubmit { onSubmit?() }
    }

    private var trailingPadding: CGFloat {
        let showsClear = isFocused && hasContent && !isSecure
        let showsEye = isSecure
        return (showsClear || showsEye) ? 36 : 0
    }

    @ViewBuilder
    private var floatingLabel: some View {
        Text(label)
            .foregroundStyle(labelFloated ? OnboardingPalette.subInk : OnboardingPalette.subInk.opacity(0.7))
            .font(.system(size: labelFloated ? 12 : 17, weight: .regular))
            .padding(.bottom, labelFloated ? 26 : 0)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if isSecure {
            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(OnboardingPalette.subInk.opacity(0.7))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPasswordVisible ? "パスワードを隠す" : "パスワードを表示")
        } else if isFocused && hasContent {
            Button {
                text = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(OnboardingPalette.subInk.opacity(0.55))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("入力をクリア")
            .transition(.opacity)
        }
    }
}

private struct AuthErrorLabel: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(OnboardingPalette.danger)
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(OnboardingPalette.danger)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

/// Maps Supabase / network auth errors to user-facing Japanese strings.
/// Matches on the raw English message because the Supabase SDK surfaces errors
/// as opaque `Error`s whose `localizedDescription` carries the upstream copy.
func japaneseAuthErrorMessage(for error: Error) -> String {
    let raw = error.localizedDescription.lowercased()

    if (error as NSError).domain == NSURLErrorDomain {
        return "通信エラーが発生しました。インターネット接続を確認してください。"
    }
    if raw.contains("invalid login credentials") || raw.contains("invalid_credentials") {
        return "メールアドレスまたはパスワードが正しくありません。"
    }
    if raw.contains("user already registered") || raw.contains("already been registered") || raw.contains("user_already_exists") {
        return "このメールアドレスはすでに登録されています。サインインしてください。"
    }
    if raw.contains("email not confirmed") {
        return "メール認証が完了していません。受信トレイの確認メールをご確認ください。"
    }
    if raw.contains("email rate limit") || raw.contains("over_email_send_rate_limit") {
        return "短時間にリクエストが集中しました。しばらく時間をおいて再度お試しください。"
    }
    if raw.contains("for security purposes") || raw.contains("you can only request this") {
        return "セキュリティ保護のため、しばらく時間をおいて再度お試しください。"
    }
    if raw.contains("password should be at least") || raw.contains("weak_password") {
        return "パスワードは6文字以上で入力してください。"
    }
    if raw.contains("unable to validate email") || raw.contains("invalid format") || raw.contains("invalid email") {
        return "メールアドレスの形式が正しくありません。"
    }
    if raw.contains("signup is disabled") || raw.contains("signup_disabled") {
        return "現在、新規登録を一時停止しています。しばらくしてから再度お試しください。"
    }
    if raw.contains("user not found") {
        return "アカウントが見つかりません。メールアドレスをご確認ください。"
    }
    return "サインインに失敗しました。時間をおいて再度お試しください。"
}
