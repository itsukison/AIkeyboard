import SwiftUI

// MARK: - Reusable onboarding chrome
//
// This file establishes the template for the redesigned onboarding flow.
// Layout reference: a top chrome with circular back button + thin progress bar
// + "Skip" affordance, a large bold title, a body content area, and a single
// dark capsule CTA pinned to the bottom safe area.

struct OnboardingScaffold<Content: View>: View {
    let progress: Double          // 0.0 ... 1.0
    let canGoBack: Bool
    let onBack: (() -> Void)?
    let onSkip: (() -> Void)?
    let ctaTitle: LocalizedStringKey
    let isCtaEnabled: Bool
    var isCtaLoading: Bool = false
    let onCta: () -> Void
    var secondaryTitle: LocalizedStringKey? = nil
    var onSecondary: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            OnboardingPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OnboardingTopBar(
                    progress: progress,
                    canGoBack: canGoBack,
                    onBack: onBack,
                    onSkip: onSkip
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack(spacing: 0) {
                    OnboardingPrimaryButton(
                        title: ctaTitle,
                        isEnabled: isCtaEnabled,
                        isLoading: isCtaLoading,
                        action: onCta
                    )

                    if let secondaryTitle, let onSecondary {
                        Button(action: onSecondary) {
                            Text(secondaryTitle)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(OnboardingPalette.subInk)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct OnboardingTopBar: View {
    let progress: Double
    let canGoBack: Bool
    let onBack: (() -> Void)?
    let onSkip: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            Button(action: { onBack?() }) {
                ZStack {
                    Circle()
                        .fill(OnboardingPalette.fieldFill)
                        .frame(width: 36, height: 36)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.ink)
                }
            }
            .buttonStyle(.plain)
            .opacity(canGoBack ? 1.0 : 0.0)
            .disabled(!canGoBack)
            .accessibilityLabel("戻る")

            OnboardingProgressBar(progress: progress)
                .frame(height: 4)
                .frame(maxWidth: .infinity)

            Button(action: { onSkip?() }) {
                Text("スキップ")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
            }
            .buttonStyle(.plain)
            .opacity(onSkip == nil ? 0.0 : 1.0)
            .disabled(onSkip == nil)
        }
        .frame(height: 44)
    }
}

private struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(OnboardingPalette.progressTrack)
                Capsule()
                    .fill(OnboardingPalette.ink)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
                    .animation(.easeOut(duration: 0.25), value: progress)
            }
        }
    }
}

struct OnboardingPrimaryButton: View {
    let title: LocalizedStringKey
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(isEnabled ? .white : .white.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill((isEnabled && !isLoading) ? OnboardingPalette.primaryActionFill : OnboardingPalette.ctaDisabled)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .animation(.easeOut(duration: 0.18), value: isEnabled)
        .animation(.easeOut(duration: 0.18), value: isLoading)
    }
}

// MARK: - Source page (1:1 replication template)

struct OnboardingSourcePage: View {
    let progress: Double
    let onBack: (() -> Void)?
    let onContinue: (SourceOption?) -> Void

    @State private var selected: SourceOption? = nil

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: onBack != nil,
            onBack: onBack,
            onSkip: nil,
            ctaTitle: "次へ",
            isCtaEnabled: selected != nil,
            onCta: { onContinue(selected) }
        ) {
            VStack(alignment: .center, spacing: 0) {
                Text("敬語ボタンを\nどこで知りましたか？")
                    .font(.system(size: 31, weight: .medium))
                    .foregroundStyle(OnboardingPalette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 52)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(SourceOption.allCases) { option in
                        SourceOptionCard(
                            option: option,
                            isSelected: selected == option,
                            onTap: { selected = option }
                        )
                    }
                }
                .padding(.top, 56)
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
        }
    }
}

enum OnboardingSourceStore {
    static let key = "aikJP.onboardingSource"

    static func write(_ source: SourceOption) {
        UserDefaults.standard.set(source.rawValue, forKey: key)
    }
}

enum SourceOption: String, CaseIterable, Identifiable {
    case google
    case twitter
    case reddit
    case instagram
    case facebook
    case tiktok
    case youtube
    case linkedin
    case productHunt
    case friend
    case newsletter
    case other

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .google:      return "Google"
        case .twitter:     return "Twitter/X"
        case .reddit:      return "Reddit"
        case .instagram:   return "Instagram"
        case .facebook:    return "Facebook"
        case .tiktok:      return "TikTok"
        case .youtube:     return "YouTube"
        case .linkedin:    return "LinkedIn"
        case .productHunt: return "Product Hunt"
        case .friend:      return "友人・知人"
        case .newsletter:  return "メール"
        case .other:       return "その他"
        }
    }
}

private struct SourceOptionCard: View {
    let option: SourceOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                SourceBrandBadge(option: option)
                    .frame(width: 28, height: 28)

                Text(option.label)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .frame(height: 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(OnboardingPalette.fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? AppColor.purple : Color.clear, lineWidth: isSelected ? 1.5 : 0)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(SourceCardPressStyle())
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct SourceCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Palette

enum OnboardingPalette {
    static let background = AppColor.canvas
    static let ink = AppColor.ink
    static let subInk = AppColor.muted
    static let progressTrack = AppColor.rule.opacity(0.55)
    // A dimmed version of the enabled charcoal so the disabled state always reads
    // as a faded form of the real button — and never ends up *lighter* than the
    // enabled fill on the dark canvas (which made "enabled" look inactive).
    static let ctaDisabled = AppColor.charcoalAction.opacity(0.4)
    static let primaryActionFill = AppColor.charcoalAction
    static let selectedControlFill = AppColor.purple
    static let fieldFill = AppColor.surface
    static let fieldStroke = AppColor.rule
    static let danger = adaptive(
        light: Color(red: 0.78, green: 0.22, blue: 0.30),
        dark: Color(red: 0.94, green: 0.35, blue: 0.42)
    )

    static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Brand badges
//
// Brand glyphs are bundled in Assets.xcassets as full-color SVGs sourced from
// theSVG (https://thesvg.org). Each icon renders in its native brand color on
// a white circular tile with a hairline border.

private struct SourceBrandBadge: View {
    let option: SourceOption

    var body: some View {
        switch option {
        case .google:      BrandTile(asset: "BrandGoogle",      inset: 5)
        case .twitter:     BrandTile(asset: "BrandX",           inset: 7)
        case .reddit:      BrandTile(asset: "BrandReddit",      inset: 4)
        case .instagram:   BrandTile(asset: "BrandInstagram",   inset: 4)
        case .facebook:    BrandTile(asset: "BrandFacebook",    inset: 4)
        case .tiktok:      BrandTile(asset: "BrandTiktok",      inset: 5)
        case .youtube:     BrandTile(asset: "BrandYoutube",     inset: 4)
        case .linkedin:    BrandTile(asset: "BrandLinkedin",    inset: 4)
        case .productHunt: BrandTile(asset: "BrandProducthunt", inset: 5)
        case .friend:      FriendBadge()
        case .newsletter:  NewsletterBadge()
        case .other:       OtherBadge()
        }
    }
}

private struct BrandTile: View {
    let asset: String
    var inset: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().fill(Color.white)
            Image(asset)
                .resizable()
                .scaledToFit()
                .padding(inset)
        }
        .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
    }
}

private struct FriendBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.86, green: 0.84, blue: 0.82))
            Image(systemName: "person.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

private struct NewsletterBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(OnboardingPalette.fieldFill)
            Image(systemName: "envelope")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
        }
        .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }
}

private struct OtherBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(OnboardingPalette.fieldFill)
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OnboardingPalette.ink)
        }
        .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }
}

// MARK: - Preview

#Preview("Source page") {
    OnboardingSourcePage(
        progress: 0.2,
        onBack: {},
        onContinue: { _ in }
    )
}
