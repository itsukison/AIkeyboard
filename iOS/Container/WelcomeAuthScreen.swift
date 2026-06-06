import SwiftUI

private enum WelcomeAuthRoute: Hashable {
    case signUp
    case signIn
}

struct WelcomeAuthScreen: View {
    @State private var path: [WelcomeAuthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomePage(
                onSignUp: { path.append(.signUp) },
                onSignIn: { path.append(.signIn) }
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

private struct WelcomePage: View {
    let onSignUp: () -> Void
    let onSignIn: () -> Void

    @State private var activeURL: IdentifiedURL?

    var body: some View {
        GeometryReader { proxy in
            let topInset = min(max(proxy.size.height * 0.30, 220), 268)

            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: topInset)

                Text("普通に入力。\n必要な時だけAI。")
                    .bikeyFont(32, weight: .medium, relativeTo: .largeTitle)
                    .foregroundStyle(.white)
                    .tracking(-0.4)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.30), radius: 12, x: 0, y: 6)

                Text("プロンプトを保存して、どの端末でも同じAI体験を。")
                    .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.top, BikeyMetrics.Spacing.s + 4)
                    .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)

                Spacer(minLength: 0)

                VStack(spacing: BikeyMetrics.Spacing.s + 4) {
                    Button(action: onSignUp) {
                        Text("アカウントを作成")
                            .bikeyFont(14, weight: .medium, relativeTo: .body)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(AppColor.charcoalAction, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onSignIn) {
                        Text("サインイン")
                            .bikeyFont(14, weight: .medium, relativeTo: .body)
                            .foregroundStyle(AppColor.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 46)
                            .bikeyInteractiveGlass(in: Capsule(), fallback: .white.opacity(0.7))
                            .overlay {
                                Capsule().stroke(.white.opacity(0.55), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $activeURL) { SafariView(url: $0.url) }
    }
}

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
