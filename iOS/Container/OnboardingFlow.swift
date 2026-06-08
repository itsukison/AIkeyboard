import SwiftUI
import UIKit

enum OnboardingGradientAsset: String {
    case globe = "gradientwithglobe"
    case welcome = "homebg"
}

struct OnboardingFlow: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0
    @Environment(\.openURL) private var openURL

    private let totalPages = 3

    var body: some View {
        Group {
            switch pageIndex {
            case 0:
                KeyboardSetupPage(
                    progress: progress(for: 0),
                    onBack: nil,
                    onSkip: { advance() },
                    onContinue: { advance() }
                )
            case 1:
                KeyboardUsagePage(
                    progress: progress(for: 1),
                    onBack: { goBack() },
                    onContinue: { advance() }
                )
            case 2:
                OnboardingSourcePage(
                    progress: progress(for: 2),
                    onBack: { goBack() },
                    onContinue: { _ in onFinish() }
                )
            default:
                legacyPostAuthBody
            }
        }
        .transition(.opacity)
        .preferredColorScheme(.light)
    }

    private var legacyPostAuthBody: some View {
        ZStack {
            OnboardingBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                OnboardingBrandMark(foregroundStyle: .white)
                    .padding(.top, BikeyMetrics.Spacing.xxl + 8)

                Spacer(minLength: BikeyMetrics.Spacing.xl)

                Group {
                    if pageIndex == 1 {
                        EnableKeyboardCard(openSettings: openKeyboardSettings)
                    } else {
                        HowItWorksCard()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

                Spacer()

                OnboardingPageDots(currentIndex: pageIndex + 2, count: totalPages + 2, activeColor: AppColor.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, BikeyMetrics.Spacing.m)

                VStack(spacing: BikeyMetrics.Spacing.s + 4) {
                    Button {
                        if pageIndex == 1 {
                            advance()
                        } else {
                            onFinish()
                        }
                    } label: {
                        OnboardingCapsuleLabel(
                            title: pageIndex == 1 ? "追加しました" : "敬語ボタンをはじめる",
                            foreground: .white,
                            background: AppColor.charcoalAction
                        )
                    }
                    .buttonStyle(.plain)

                    if pageIndex == 1 {
                        Button("今はスキップ") {
                            advance()
                        }
                        .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(AppColor.secondaryInk)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 34)
                    }
                }
                .padding(.bottom, BikeyMetrics.Spacing.xl)
            }
            .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset + 8)
        }
    }

    private func advance() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            if pageIndex + 1 >= totalPages {
                onFinish()
            } else {
                pageIndex += 1
            }
        }
    }

    private func goBack() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            pageIndex = max(0, pageIndex - 1)
        }
    }

    private func progress(for index: Int) -> Double {
        let step = 1.0 / Double(totalPages)
        return step * Double(index + 1)
    }

    private func openKeyboardSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct LegalFooterRow: View {
    @State private var activeURL: IdentifiedURL?

    var body: some View {
        HStack(spacing: 14) {
            footerLink("プライバシー", url: LegalLinks.privacy)
            dot
            footerLink("利用規約", url: LegalLinks.terms)
            dot
            footerLink("サポート", url: LegalLinks.support)
        }
        .frame(maxWidth: .infinity)
        .sheet(item: $activeURL) { SafariView(url: $0.url) }
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

private struct EnableKeyboardCard: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
            VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.s + 2) {
                Text("敬語ボタンを追加します")
                    .bikeyFont(28, weight: .semibold, relativeTo: .largeTitle)
                    .foregroundStyle(AppColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("一度追加すると、LINEやメールの入力中にいつでも切り替えられます。")
                    .bikeyFont(15, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.secondaryInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsBreadcrumb()

            Button(action: openSettings) {
                HStack(spacing: 6) {
                    Text("設定を開く")
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 13, weight: .semibold))
                }
                .bikeyFont(15, weight: .medium, relativeTo: .body)
                .foregroundStyle(AppColor.purple)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .bikeyInteractiveGlass(in: Capsule(), fallback: .white.opacity(0.9))
                .overlay {
                    Capsule().stroke(AppColor.purple.opacity(0.18), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("iOS設定を開く")
        }
        .padding(BikeyMetrics.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: BikeyMetrics.Radius.largeCard, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 11, x: 0, y: 6)
    }
}

private struct HowItWorksCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
            VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.s + 2) {
                Text("送る前に、敬語へ整える。")
                    .bikeyFont(28, weight: .semibold, relativeTo: .largeTitle)
                    .foregroundStyle(AppColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("AIボタンを押すと、今の文章に合う自然な候補をすぐ選べます。")
                    .bikeyFont(15, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.secondaryInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            KeyboardDemoBlock()
        }
        .padding(BikeyMetrics.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: BikeyMetrics.Radius.largeCard, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 11, x: 0, y: 6)
    }
}

private struct SettingsBreadcrumb: View {
    private let segments = [
        "設定",
        "一般",
        "キーボード",
        "キーボード",
        "新しいキーボードを追加",
        "敬語ボタン"
    ]

    var body: some View {
        FlowLayout(spacing: 5, lineSpacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppColor.softText)
                        .frame(height: 26)
                }
                BreadcrumbChip(text: segment, isTarget: segment == "敬語ボタン")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("設定、一般、キーボード、キーボード、新しいキーボードを追加、敬語ボタン")
    }
}

private struct BreadcrumbChip: View {
    let text: String
    let isTarget: Bool

    var body: some View {
        Text(text)
            .bikeyFont(13, weight: .medium, relativeTo: .footnote)
            .foregroundStyle(isTarget ? AppColor.purple : AppColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .background(
                isTarget ? AppColor.purple.opacity(0.12) : AppColor.lavenderMist.opacity(0.75),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}

private struct KeyboardDemoBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.m - 2) {
            VStack(alignment: .leading, spacing: 4) {
                Text("入力")
                    .bikeyFont(10, weight: .semibold, relativeTo: .caption2)
                    .foregroundStyle(AppColor.softText)
                    .tracking(0.6)

                Text("きょうのよてい")
                    .bikeyFont(16, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CandidateCapsule(text: "今日の予定", style: .selected)
                    CandidateCapsule(text: "京の予定", style: .alternate)
                    CandidateCapsule(text: "きょうのよてい", style: .keep)
                }
                .padding(.vertical, 2)
            }

            Text("送る前にAIボタンを押して、相手に合う文面を選びます。")
                .bikeyFont(12, weight: .regular, relativeTo: .caption)
                .foregroundStyle(AppColor.secondaryInk)
                .lineLimit(2)
                .minimumScaleFactor(0.84)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BikeyMetrics.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.canvas.opacity(0.96), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CandidateCapsule: View {
    enum Style { case selected, alternate, keep }

    let text: String
    let style: Style

    private var foreground: Color {
        switch style {
        case .selected: return .white
        case .alternate: return AppColor.ink
        case .keep: return AppColor.purple
        }
    }

    private var fill: Color {
        switch style {
        case .selected: return AppColor.charcoalAction
        case .alternate: return AppColor.lavenderMist
        case .keep: return .white.opacity(0.94)
        }
    }

    var body: some View {
        Text(text)
            .bikeyFont(14, weight: .medium, relativeTo: .body)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 14)
            .frame(minHeight: 32)
            .background(fill, in: Capsule())
            .overlay {
                if style == .keep {
                    Capsule().stroke(AppColor.purple.opacity(0.22), lineWidth: 1)
                }
            }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + lineSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x - spacing)
        }
        return CGSize(width: min(totalWidth, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + lineSpacing
                x = 0
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct OnboardingBrandMark<S: ShapeStyle>: View {
    let foregroundStyle: S

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .medium))
            Text("敬語ボタン")
                .bikeyFont(12, weight: .medium, relativeTo: .footnote)
        }
        .foregroundStyle(foregroundStyle)
    }
}

private struct OnboardingCapsuleLabel: View {
    let title: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text(title)
            .bikeyFont(14, weight: .medium, relativeTo: .body)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(background, in: Capsule())
    }
}

private struct OnboardingPageDots: View {
    let currentIndex: Int
    let count: Int
    let activeColor: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? activeColor.opacity(0.92) : activeColor.opacity(0.32))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

struct OnboardingBackground: View {
    var asset: OnboardingGradientAsset = .globe

    var body: some View {
        ZStack {
            AppColor.canvas

            if let image = Self.loadImage(named: asset.rawValue) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        AppColor.purple.opacity(0.54),
                        AppColor.lavenderMist,
                        AppColor.canvas
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private static func loadImage(named name: String) -> UIImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return UIImage(contentsOfFile: repoRoot.appendingPathComponent("public/\(name).png").path)
    }
}
