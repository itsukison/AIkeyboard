import SwiftUI

enum WelcomeAuthRoute: Hashable {
    case signUp
    case signIn
}

/// First-run experience for users who have not completed onboarding:
/// welcome → keyboard onboarding → account choice (create / sign in / skip).
/// Auth is deferred to the end so the keyboard's purpose is shown to everyone,
/// and skipping lands the user in a fully usable guest app.
struct FirstRunFlow: View {
    let onComplete: () -> Void

    @State private var phase: Phase = .welcome

    private enum Phase {
        case welcome
        case onboarding
        case auth
    }

    var body: some View {
        Group {
            switch phase {
            case .welcome:
                WelcomePage(onStart: { withAnimation(.easeInOut(duration: 0.2)) { phase = .onboarding } })
            case .onboarding:
                OnboardingFlow(onFinish: { withAnimation(.easeInOut(duration: 0.2)) { phase = .auth } })
            case .auth:
                AuthChoiceScreen(onSkip: onComplete)
            }
        }
        .transition(.opacity)
        .preferredColorScheme(.light)
    }
}

// MARK: - Welcome

private struct WelcomePage: View {
    let onStart: () -> Void

    @State private var activeURL: IdentifiedURL?

    var body: some View {
        GeometryReader { proxy in
            let topInset = min(max(proxy.size.height * 0.30, 220), 268)

            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: topInset)

                Text("送る前に、\n敬語に整える。")
                    .bikeyFont(32, weight: .medium, relativeTo: .largeTitle)
                    .foregroundStyle(.white)
                    .tracking(-0.4)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.30), radius: 12, x: 0, y: 6)

                Text("LINE、メール、DMの文面をその場で自然に。")
                    .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.top, BikeyMetrics.Spacing.s + 4)
                    .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)

                Spacer(minLength: 0)

                VStack(spacing: BikeyMetrics.Spacing.s + 4) {
                    Button(action: onStart) {
                        Text("始める")
                            .bikeyFont(14, weight: .medium, relativeTo: .body)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(AppColor.charcoalAction, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    LegalFooterRow(activeURL: $activeURL)
                        .padding(.top, BikeyMetrics.Spacing.s)
                }
                .padding(.bottom, BikeyMetrics.Spacing.xl)
            }
            .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset + 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                OnboardingBackground(asset: .welcome)
                    .ignoresSafeArea()
            )
        }
        .sheet(item: $activeURL) { SafariView(url: $0.url) }
    }
}

// MARK: - Account choice

/// Account step shown at the end of onboarding and re-used as an in-app sheet
/// from guest surfaces. `onSkip` drives the onboarding "スキップ" affordance;
/// `onClose` drives the in-app dismiss (chevron).
struct AuthChoiceScreen: View {
    var onSkip: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    @State private var path: [WelcomeAuthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            AuthChoicePage(
                onSignUp: { path.append(.signUp) },
                onSignIn: { path.append(.signIn) },
                onSkip: onSkip,
                onClose: onClose
            )
            .navigationDestination(for: WelcomeAuthRoute.self) { route in
                switch route {
                case .signUp:
                    SignUpForm()
                case .signIn:
                    SignInForm()
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct AuthChoicePage: View {
    let onSignUp: () -> Void
    let onSignIn: () -> Void
    var onSkip: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        OnboardingScaffold(
            progress: 1.0,
            canGoBack: onClose != nil,
            onBack: onClose,
            onSkip: onSkip,
            ctaTitle: "アカウントを作成",
            isCtaEnabled: true,
            onCta: onSignUp,
            secondaryTitle: "すでにアカウントをお持ちの方はサインイン",
            onSecondary: onSignIn
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        Text("プロンプトを保存して\nどの端末でも")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(subtitle)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(OnboardingPalette.subInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 40)

                    AuthBenefitCard()
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private var subtitle: String {
        onSkip != nil
            ? "アカウントを作成すると、AI書き直しやカスタムプロンプトの保存・同期が使えます。スキップして後から登録することもできます。"
            : "アカウントを作成すると、AI書き直しやカスタムプロンプトの保存・同期が使えます。"
    }
}

private struct AuthBenefitCard: View {
    private let benefits: [(icon: String, text: String)] = [
        ("pencil.line", "AIで敬語・ビジネス文面に書き直し"),
        ("bookmark", "カスタムプロンプトを保存・同期"),
        ("iphone", "複数の端末で設定を引き継ぎ")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(benefits, id: \.icon) { benefit in
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 38, height: 38)
                            .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 0.5))
                        Image(systemName: benefit.icon)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(OnboardingPalette.ink)
                    }

                    Text(benefit.text)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(OnboardingPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.93, green: 0.92, blue: 0.91))
        )
    }
}

// MARK: - In-app auth cover

/// Presents the account choice from guest surfaces (Prompts, Settings) and
/// dismisses automatically once the user signs in.
private struct GuestAuthCover: ViewModifier {
    @Binding var isPresented: Bool
    @EnvironmentObject private var session: UserSession

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            AuthChoiceScreen(onClose: { isPresented = false })
                .onChange(of: session.state) { state in
                    if case .signedIn = state { isPresented = false }
                }
        }
    }
}

extension View {
    func guestAuthCover(isPresented: Binding<Bool>) -> some View {
        modifier(GuestAuthCover(isPresented: isPresented))
    }
}

// MARK: - Legal footer

private struct LegalFooterRow: View {
    @Binding var activeURL: IdentifiedURL?

    var body: some View {
        HStack(spacing: 14) {
            footerLink("プライバシー", url: LegalLinks.privacy)
            dot
            footerLink("利用規約", url: LegalLinks.terms)
            dot
            footerLink("サポート", url: LegalLinks.support)
        }
        .frame(maxWidth: .infinity)
    }

    private var dot: some View {
        Circle()
            .fill(.white.opacity(0.55))
            .frame(width: 3, height: 3)
    }

    private func footerLink(_ title: String, url: URL) -> some View {
        Button {
            activeURL = IdentifiedURL(url: url)
        } label: {
            Text(title)
                .bikeyFont(12, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(.white.opacity(0.82))
        }
        .buttonStyle(.plain)
    }
}
