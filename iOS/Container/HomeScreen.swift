import PostHog
import SwiftUI
import UIKit

struct HomeScreen: View {
    @ObservedObject private var stats = ConversionStats.shared
    @State private var showDemo = false
    @State private var isLoading = true

    private let tips: [Tip] = [
        .init(
            label: "その場で敬語",
            title: "チャットを離れずに書き直せます",
            sourceText: "確認お願いします",
            convertedText: "ご確認お願いいたします",
            icon: "keyboard.badge.ellipsis"
        ),
        .init(
            label: "相手に合わせる",
            title: "上司・取引先向けの自然な文面に",
            sourceText: "了解です",
            convertedText: "承知しました",
            icon: "person.text.rectangle"
        )
    ]

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    HomeHeader(stats: stats)
                        .padding(.top, BikeyMetrics.Spacing.s)

                    KeyboardEnabledBanner()
                        .padding(.top, BikeyMetrics.Spacing.m)

                    HeroCard(onTryDemo: { showDemo = true })
                        .padding(.top, BikeyMetrics.Spacing.m - 2)

                    TipsHeader(title: "できること")
                        .padding(.top, BikeyMetrics.Spacing.m)

                    VStack(spacing: BikeyMetrics.Spacing.m - 2) {
                        ForEach(tips) { tip in
                            TipCard(tip: tip)
                        }
                    }
                    .padding(.top, BikeyMetrics.Spacing.s + 2)

                    Spacer(minLength: BikeyMetrics.Sizing.tabBarHeight + 32)
                }
                .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
            }
            .opacity(isLoading ? 0 : 1)

            if isLoading {
                HomeSkeletonView()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .background(AppColor.background.ignoresSafeArea())
        .sheet(isPresented: $showDemo) {
            BikeyDemoSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
                .presentationBackground(AppColor.background)
        }
        .onChange(of: showDemo) { isShowing in
            if isShowing {
                PostHogSDK.shared.capture("demo_opened")
            }
        }
        .onAppear {
            guard isLoading else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeOut(duration: 0.28)) {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Header

private struct HomeHeader: View {
    @ObservedObject var stats: ConversionStats

    var body: some View {
        HStack(alignment: .center, spacing: BikeyMetrics.Spacing.s + 2) {
            HStack(spacing: BikeyMetrics.Spacing.s - 1) {
                AppLogoTile()
                    .frame(width: 26, height: 26)

                Text("敬語ボタン")
                    .bikeyFont(20, weight: .medium, relativeTo: .title3)
                    .foregroundStyle(AppColor.ink)
            }

            Spacer(minLength: BikeyMetrics.Spacing.s)

            StatsPill(stats: stats)
        }
        .frame(height: 40)
    }
}

private struct AppLogoTile: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(AppColor.paleLavender)
            .overlay {
                Group {
                    if let image = BundledImage.load("applogo") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppColor.purple.opacity(0.72))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
    }
}

private struct StatsPill: View {
    @ObservedObject var stats: ConversionStats

    var body: some View {
        HStack(spacing: 0) {
            MetricColumn(value: stats.conversionsDisplay, label: "変換")
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(AppColor.rule.opacity(0.6))
                .frame(width: 0.6, height: 18)

            MetricColumn(value: stats.streakDisplay, label: "日連続")
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .frame(width: 132, height: 38)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

private struct MetricColumn: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .bikeyFont(13, weight: .medium, relativeTo: .footnote)
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .bikeyFont(9, weight: .regular, relativeTo: .caption2)
                .foregroundStyle(AppColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

// MARK: - Enabled banner

private struct KeyboardEnabledBanner: View {
    var body: some View {
        HStack(spacing: BikeyMetrics.Spacing.s + 2) {
            Image(systemName: "keyboard")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppColor.purple.opacity(0.76))

            Text("AIボタンを押した文章だけ書き直します")
                .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(AppColor.ink.opacity(0.78))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, BikeyMetrics.Spacing.m - 2)
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(AppColor.paleLavender.opacity(0.85), in: Capsule())
    }
}

// MARK: - Hero card

private struct HeroCard: View {
    let onTryDemo: () -> Void

    var body: some View {
        ZStack {
            HeroBackgroundImage()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("送る前に、\n失礼じゃない言葉へ。")
                        .bikeyFont(24, weight: .regular, relativeTo: .title2)
                        .foregroundStyle(AppColor.ink.opacity(0.92))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("LINEもメールも、キーボード上で\n敬語・ビジネス文面に整えます。")
                        .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(AppColor.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: BikeyMetrics.Spacing.m)

                HStack(alignment: .center, spacing: BikeyMetrics.Spacing.s + 2) {
                    ConversionPreviewPill()

                    TryDemoButton(action: onTryDemo)
                }
            }
            .padding(.horizontal, BikeyMetrics.Spacing.l - 4)
            .padding(.vertical, BikeyMetrics.Spacing.l - 4)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: BikeyMetrics.Radius.hero - 8, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

private struct HeroBackgroundImage: View {
    var body: some View {
        Group {
            if let image = BundledImage.load("globebg") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.12)
            } else {
                LinearGradient(
                    colors: [
                        AppColor.lavender,
                        AppColor.paleLavender
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

private struct ConversionPreviewPill: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("明日いけますか")
                .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(spacing: 4) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(AppColor.softText)

                Text("明日ご都合いかがでしょうか")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, BikeyMetrics.Spacing.s + 4)
        .padding(.vertical, BikeyMetrics.Spacing.s + 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TryDemoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("試してみる")
                .bikeyFont(13, weight: .medium, relativeTo: .footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, BikeyMetrics.Spacing.m)
                .frame(height: 38)
                .background(AppColor.charcoalAction, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("敬語ボタンを試す")
    }
}

// MARK: - Tips

private struct TipsHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .bikeyFont(15, weight: .regular, relativeTo: .subheadline)
                .foregroundStyle(AppColor.muted)

            Spacer()
        }
        .padding(.horizontal, 2)
    }
}

private struct Tip: Identifiable {
    let id = UUID()
    let label: String
    let title: String
    let sourceText: String
    let convertedText: String
    let icon: String
}

private struct TipCard: View {
    let tip: Tip

    var body: some View {
        HStack(alignment: .top, spacing: BikeyMetrics.Spacing.m - 4) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.label)
                    .bikeyFont(11, weight: .regular, relativeTo: .caption)
                    .foregroundStyle(AppColor.purple.opacity(0.78))

                Text(tip.title)
                    .bikeyFont(15, weight: .medium, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .padding(.top, 2)

                HStack(spacing: 6) {
                    Text(tip.sourceText)
                        .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(AppColor.softText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AppColor.softText.opacity(0.8))

                    Text(tip.convertedText)
                        .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(AppColor.ink.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .padding(.top, 6)
            }

            Spacer(minLength: 0)

            Image(systemName: tip.icon)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppColor.purple.opacity(0.6))
                .frame(width: 32, height: 32)
                .background(AppColor.paleLavender.opacity(0.92), in: Circle())
        }
        .padding(.horizontal, BikeyMetrics.Spacing.m)
        .padding(.vertical, BikeyMetrics.Spacing.m - 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: BikeyMetrics.Radius.largeCard, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Demo sheet

private struct BikeyDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .bikeyFont(15, weight: .medium, relativeTo: .body)
                        .foregroundStyle(AppColor.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.m)
            .padding(.top, BikeyMetrics.Spacing.m)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("お試し")
                            .bikeyFont(11, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(AppColor.purple)
                            .tracking(0.6)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(AppColor.paleLavender.opacity(0.85), in: Capsule())

                        Text("キーボードを試す")
                            .bikeyFont(24, weight: .medium, relativeTo: .title2)
                            .foregroundStyle(AppColor.ink)

                        Text("ここは入力を試すためのお試し欄です。送信ボタンはありません。\n1. 地球儀キー🌐を長押しして「敬語ボタン」に切り替え\n2. 文章を入力\n3. ツールバーのAIボタンを押すと敬語に書き直せます")
                            .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    DemoTextField(text: $text, isFocused: $isFocused)

                    Text("※ お試し用の入力欄です。入力した文章はどこにも送信されません。")
                        .bikeyFont(12, weight: .regular, relativeTo: .caption)
                        .foregroundStyle(AppColor.softText)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l)
                .padding(.top, BikeyMetrics.Spacing.xl)
                .padding(.bottom, BikeyMetrics.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppColor.background.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                isFocused = true
            }
        }
    }
}

private struct DemoTextField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        TextField("明日までに確認お願いします", text: $text, axis: .vertical)
            .focused(isFocused)
            .bikeyFont(16, weight: .regular, relativeTo: .body)
            .foregroundStyle(AppColor.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .lineLimit(5...12)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isFocused.wrappedValue ? AppColor.ink.opacity(0.18) : AppColor.rule.opacity(0.25),
                        lineWidth: isFocused.wrappedValue ? 1 : 0.6
                    )
            )
            .animation(.easeInOut(duration: 0.18), value: isFocused.wrappedValue)
            .contentShape(Rectangle())
            .onTapGesture { isFocused.wrappedValue = true }
    }
}

// MARK: - Skeleton loader

private struct HomeSkeletonView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                SkeletonHeader()
                    .padding(.top, BikeyMetrics.Spacing.s)

                SkeletonBanner()
                    .padding(.top, BikeyMetrics.Spacing.m)

                SkeletonHero()
                    .padding(.top, BikeyMetrics.Spacing.m - 2)

                SkeletonTipsHeader()
                    .padding(.top, BikeyMetrics.Spacing.m)

                VStack(spacing: BikeyMetrics.Spacing.m - 2) {
                    ForEach(0..<2, id: \.self) { _ in
                        SkeletonTipCard()
                    }
                }
                .padding(.top, BikeyMetrics.Spacing.s + 2)

                Spacer(minLength: BikeyMetrics.Sizing.tabBarHeight + 32)
            }
            .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
        }
        .disabled(true)
    }
}

private struct SkeletonHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: BikeyMetrics.Spacing.s + 2) {
            HStack(spacing: BikeyMetrics.Spacing.s - 1) {
                SkeletonShape(shape: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .frame(width: 26, height: 26)

                SkeletonShape(shape: Capsule())
                    .frame(width: 58, height: 18)
            }

            Spacer(minLength: BikeyMetrics.Spacing.s)

            SkeletonShape(shape: Capsule())
                .frame(width: 132, height: 38)
        }
        .frame(height: 40)
    }
}

private struct SkeletonBanner: View {
    var body: some View {
        SkeletonShape(shape: Capsule())
            .frame(maxWidth: .infinity)
            .frame(height: 38)
    }
}

private struct SkeletonHero: View {
    var body: some View {
        SkeletonShape(shape: RoundedRectangle(cornerRadius: BikeyMetrics.Radius.hero - 8, style: .continuous))
            .frame(height: 220)
            .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }
}

private struct SkeletonTipsHeader: View {
    var body: some View {
        HStack {
            SkeletonShape(shape: Capsule())
                .frame(width: 36, height: 14)
            Spacer()
        }
        .padding(.horizontal, 2)
    }
}

private struct SkeletonTipCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: BikeyMetrics.Spacing.m - 4) {
            VStack(alignment: .leading, spacing: 8) {
                SkeletonShape(shape: Capsule())
                    .frame(width: 64, height: 11)

                SkeletonShape(shape: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .frame(width: 200, height: 14)
                    .padding(.top, 2)

                SkeletonShape(shape: Capsule())
                    .frame(width: 168, height: 12)
                    .padding(.top, 6)
            }

            Spacer(minLength: 0)

            SkeletonShape(shape: Circle())
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, BikeyMetrics.Spacing.m)
        .padding(.vertical, BikeyMetrics.Spacing.m - 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: BikeyMetrics.Radius.largeCard, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }
}

private struct SkeletonShape<S: Shape>: View {
    let shape: S
    @State private var phase: CGFloat = -1

    var body: some View {
        shape
            .fill(AppColor.paleLavender.opacity(0.72))
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.0), location: 0.0),
                            .init(color: .white.opacity(0.55), location: 0.5),
                            .init(color: .white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.6)
                    .offset(x: phase * width)
                    .blendMode(.plusLighter)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
    }
}

// MARK: - Bundled image loader

private enum BundledImage {
    static func load(_ name: String) -> UIImage? {
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
