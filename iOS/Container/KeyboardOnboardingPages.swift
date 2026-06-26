import SwiftUI
import UIKit

// MARK: - Setup page

struct KeyboardSetupPage: View {
    let progress: Double
    let onBack: (() -> Void)?
    let onSkip: (() -> Void)?
    let onContinue: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: onBack != nil,
            onBack: onBack,
            onSkip: onSkip,
            ctaTitle: "設定を開く",
            isCtaEnabled: true,
            onCta: openAndAdvance
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        Text("敬語ボタンを\nキーボードに追加")
                            .font(.system(size: 31, weight: .medium))
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("一度追加すると、LINEやメールの入力中にそのまま使えます。AIはボタンを押した時だけ、今の文章を書き直します。")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(OnboardingPalette.subInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 28)

                    SettingsMockCard()
                        .padding(.top, 8)

                    Button("追加済みなので次へ") {
                        onContinue()
                    }
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(OnboardingPalette.subInk)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private func openAndAdvance() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
        onContinue()
    }
}

private struct SettingsMockCard: View {
    var body: some View {
        VStack {
            PhoneFrameMock {
                SettingsKeyboardsMock()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.93, green: 0.92, blue: 0.91))
        )
    }
}

private struct PhoneFrameMock<Inner: View>: View {
    @ViewBuilder var inner: () -> Inner

    var body: some View {
        VStack(spacing: 0) {
            // Mini status bar
            HStack {
                Text("4:36")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black)
                Spacer()
                Capsule()
                    .fill(.black)
                    .frame(width: 78, height: 18)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.system(size: 9, weight: .semibold))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.black)
                        .frame(width: 18, height: 9)
                }
                .foregroundStyle(.black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)

            inner()
                .background(Color(red: 0.95, green: 0.95, blue: 0.96))
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
    }
}

private struct SettingsKeyboardsMock: View {
    var body: some View {
        VStack(spacing: 12) {
            // Nav bar
            ZStack {
                Text("キーボード")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                HStack {
                    ZStack {
                        Circle().fill(Color.black.opacity(0.06)).frame(width: 22, height: 22)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.7))
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            // Toggle rows
            VStack(spacing: 0) {
                SettingsToggleRow(label: "敬語ボタン", isOn: true, showDivider: true)
                SettingsToggleRow(label: "フルアクセスを許可", isOn: true, showDivider: false, iconName: "keyboard")
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 14)

            Text("AIで書き直すために必要です。通常の入力中に勝手に送信されることはありません。")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(.black.opacity(0.5))
                .padding(.horizontal, 22)
                .padding(.top, 2)
                .lineSpacing(2)

            // Permission dialog
            VStack(alignment: .leading, spacing: 6) {
                Text("“敬語ボタン”に\nフルアクセスを許可しますか？")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineSpacing(1)
                Text("AIボタンを押した時だけ、今の文章を敬語に書き直します。")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.black.opacity(0.6))
                    .lineSpacing(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
    }
}

private struct SettingsToggleRow: View {
    let label: String
    let isOn: Bool
    let showDivider: Bool
    var iconName: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if let iconName {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(red: 0.85, green: 0.85, blue: 0.87))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: iconName)
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(.white)
                        )
                }
                Text(label)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.black)
                Spacer()
                MiniToggle(isOn: isOn)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)

            if showDivider {
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.leading, iconName == nil ? 12 : 38)
            }
        }
    }
}

private struct MiniToggle: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Color(red: 0.20, green: 0.78, blue: 0.35) : Color(red: 0.78, green: 0.78, blue: 0.80))
                .frame(width: 28, height: 16)
            Circle()
                .fill(.white)
                .frame(width: 13, height: 13)
                .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 0.5)
                .padding(1.5)
        }
    }
}

// MARK: - Usage page

struct KeyboardUsagePage: View {
    let progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: onBack,
            onSkip: nil,
            ctaTitle: "次へ",
            isCtaEnabled: true,
            onCta: onContinue
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        Text("送信前に\n3つの敬語候補。")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("候補バーの敬語ボタンから、よく使う書き換えをすぐ選べます。")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(OnboardingPalette.subInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 40)

                    KeyboardMockCard()
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct KeyboardMockCard: View {
    var body: some View {
        NativeKeyboardSurfaceMock(mode: .toolbar)
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.93, green: 0.92, blue: 0.91))
        )
    }
}

struct KeyboardResultPage: View {
    let progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: onBack,
            onSkip: nil,
            ctaTitle: "次へ",
            isCtaEnabled: true,
            onCta: onContinue
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        Text("候補をフリックして\nそのまま置き換え。")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("生成後はカードを横に動かして比較できます。\n選んだ候補で文章を置き換えます。")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(OnboardingPalette.subInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 40)

                    KeyboardResultMockCard()
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct KeyboardResultMockCard: View {
    var body: some View {
        NativeKeyboardSurfaceMock(mode: .result)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.93, green: 0.92, blue: 0.91))
            )
    }
}

// MARK: - Reply page

struct KeyboardReplyPage: View {
    let progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: onBack,
            onSkip: nil,
            ctaTitle: "次へ",
            isCtaEnabled: true,
            onCta: onContinue
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        Text("コピーした文に\nワンタップで返信。")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("相手のメッセージをコピーすると、ツールバーに返信ボタンが出ます。押すだけで返信文の候補を作成します。")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(OnboardingPalette.subInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 40)

                    KeyboardReplyMockCard()
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct KeyboardReplyMockCard: View {
    var body: some View {
        NativeKeyboardSurfaceMock(mode: .reply)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.93, green: 0.92, blue: 0.91))
            )
    }
}

// MARK: - Consent page

struct KeyboardConsentPage: View {
    let progress: Double
    let onBack: () -> Void
    let onAgree: () -> Void
    let onDecline: () -> Void

    @State private var showPrivacy = false
    @State private var agreedToPolicy = false

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: onBack,
            onSkip: nil,
            ctaTitle: "同意してはじめる",
            isCtaEnabled: agreedToPolicy,
            onCta: onAgree,
            secondaryTitle: "今は使わない（通常のキーボードとして利用）",
            onSecondary: onDecline
        ) {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 14) {
                            Text("AIに送る前に\n確認してください")
                                .font(.system(size: 31, weight: .medium))
                                .foregroundStyle(OnboardingPalette.ink)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("敬語ボタンを押した時だけ、その文章がAIサービスに送信されます。通常の入力が送信されることはありません。")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(OnboardingPalette.subInk)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 4)
                        }
                        .padding(.top, 28)

                        ConsentDataCard()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }

                ConsentAgreementCheckbox(
                    isOn: $agreedToPolicy,
                    onOpenPrivacy: { showPrivacy = true }
                )
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: LegalLinks.privacy)
        }
    }
}

struct ConsentDataCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AIサービスに送信される内容")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OnboardingPalette.subInk)

            VStack(alignment: .leading, spacing: 14) {
                ConsentDataRow(icon: "text.alignleft", text: "入力したテキスト")
                ConsentDataRow(icon: "wand.and.stars", text: "使用した機能の種類（敬語・メール・翻訳など）")
                ConsentDataRow(icon: "info.circle", text: "処理に関する技術情報（文字数・処理日時など）")
            }

            Divider()
                .overlay(Color.black.opacity(0.06))

            ConsentDataRow(icon: "cpu", text: "送信先：第三者のAIサービス（Cerebras・Groq）")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

private struct ConsentAgreementCheckbox: View {
    @Binding var isOn: Bool
    let onOpenPrivacy: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                isOn.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isOn ? OnboardingPalette.ink : Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(isOn ? Color.clear : OnboardingPalette.fieldStroke, lineWidth: 1.5)
                        )

                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("プライバシーポリシーの内容に同意する")
            .accessibilityAddTraits(isOn ? [.isSelected] : [])

            Text(.init("[プライバシーポリシー](\(LegalLinks.privacy.absoluteString))の内容に同意します"))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
                .tint(AppColor.purple)
                .environment(\.openURL, OpenURLAction { _ in
                    onOpenPrivacy()
                    return .handled
                })
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct ConsentDataRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
                .frame(width: 22)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private enum NativeKeyboardSurfaceMode {
    case toolbar
    case result
    case reply
}

private struct NativeKeyboardSurfaceMock: View {
    let mode: NativeKeyboardSurfaceMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var cardIndex = 0
    @State private var showReply = false

    private let designSize = CGSize(width: 390, height: 266)

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designSize.width

            ZStack(alignment: .topLeading) {
                content
                    .frame(width: designSize.width, height: designSize.height)
                    .scaleEffect(scale, anchor: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .aspectRatio(designSize.width / designSize.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: reduceMotion) {
            await runDemoLoop()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .toolbar:
            VStack(spacing: 8) {
                NativeToolbarDemo(isExpanded: isExpanded)
                NativeKeyboardRows()
                NativeKeyboardAccessoryRow()
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
            .background(NativeKeyboardStyle.surface)
        case .result:
            NativeResultDemo(selectedIndex: cardIndex)
                .background(NativeKeyboardStyle.surface)
        case .reply:
            VStack(spacing: 8) {
                NativeIncomingMessageBubble()
                NativeReplyToolbarDemo(showReply: showReply)
                NativeKeyboardRows()
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
            .background(NativeKeyboardStyle.surface)
        }
    }

    @MainActor
    private func runDemoLoop() async {
        guard !reduceMotion else {
            isExpanded = mode == .toolbar
            cardIndex = 0
            showReply = mode == .reply
            return
        }

        switch mode {
        case .toolbar:
            isExpanded = false
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 900_000_000)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    isExpanded = true
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    isExpanded = false
                }
            }
        case .result:
            cardIndex = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_350_000_000)
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    cardIndex = (cardIndex + 1) % 3
                }
            }
        case .reply:
            showReply = false
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    showReply = true
                }
                try? await Task.sleep(nanoseconds: 1_900_000_000)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    showReply = false
                }
            }
        }
    }
}

private enum NativeKeyboardStyle {
    static let surface = Color(red: 0.86, green: 0.87, blue: 0.89)
    static let keyFill = Color.white.opacity(0.96)
    static let specialKey = Color(red: 0.74, green: 0.76, blue: 0.78)
    static let ink = Color(red: 0.129, green: 0.129, blue: 0.155)
    static let accent = Color(red: 0.341, green: 0.258, blue: 0.656)
    static let accentSoft = Color(red: 0.950, green: 0.937, blue: 0.986)
}

private struct NativeToolbarDemo: View {
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 6) {
            if !isExpanded {
                NativeToolbarPill(title: "敬語", isSelected: false)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            NativeToolbarPill(title: "…", isSelected: isExpanded, minWidth: 36)

            if isExpanded {
                HStack(spacing: 6) {
                    NativeToolbarPill(title: "自然に", isSelected: false)
                    NativeToolbarPill(title: "メール", isSelected: false)
                    NativeToolbarPill(title: "英訳", isSelected: false)
                    Spacer(minLength: 6)
                    NativeToolbarPill(title: "設定", isSelected: false)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Spacer(minLength: 0)
        }
        .frame(height: 46)
        .padding(.horizontal, 6)
        .clipped()
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isExpanded)
    }
}

private struct NativeToolbarPill: View {
    let title: String
    let isSelected: Bool
    var minWidth: CGFloat? = nil

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(NativeKeyboardStyle.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 12)
            .frame(minWidth: minWidth, minHeight: 38)
            .background(
                isSelected ? NativeKeyboardStyle.accentSoft : Color.white.opacity(0.72),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? NativeKeyboardStyle.accent : Color.clear, lineWidth: 1.2)
            )
    }
}

private struct NativeIncomingMessageBubble: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(NativeKeyboardStyle.accentSoft)
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(NativeKeyboardStyle.accent.opacity(0.7))
                )

            Text("明日の10時で大丈夫ですか？")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(NativeKeyboardStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            HStack(spacing: 3) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                Text("コピー済み")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(NativeKeyboardStyle.accent)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(NativeKeyboardStyle.accentSoft, in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 6)
    }
}

private struct NativeReplyToolbarDemo: View {
    let showReply: Bool

    var body: some View {
        HStack(spacing: 6) {
            if showReply {
                NativeReplyPill()
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            NativeToolbarPill(title: "敬語", isSelected: false)
            NativeToolbarPill(title: "…", isSelected: false, minWidth: 36)

            Spacer(minLength: 0)
        }
        .frame(height: 46)
        .padding(.horizontal, 6)
        .clipped()
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: showReply)
    }
}

private struct NativeReplyPill: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrowshape.turn.up.left")
                .font(.system(size: 15, weight: .semibold))
            Text("返信")
                .font(.system(size: 17, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(NativeKeyboardStyle.accent)
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background(
            Color.white.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

private struct NativeKeyboardRows: View {
    private let row1 = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
    private let row2 = ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ー"]
    private let row3 = ["z", "x", "c", "v", "b", "n", "m"]

    var body: some View {
        VStack(spacing: 8) {
            NativeLetterRow(keys: row1)
            NativeLetterRow(keys: row2)

            HStack(spacing: 6) {
                NativeSpecialKey(symbol: "shift", width: 45)
                Spacer(minLength: 6)
                ForEach(row3, id: \.self) { key in
                    NativeLetterKey(label: key)
                }
                Spacer(minLength: 6)
                NativeSpecialKey(symbol: "delete.left", width: 45)
            }
        }
        .padding(.horizontal, 6)
    }
}

private struct NativeLetterRow: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(keys, id: \.self) { key in
                NativeLetterKey(label: key)
            }
        }
    }
}

private struct NativeLetterKey: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 25, weight: .regular))
            .foregroundStyle(.black.opacity(0.92))
            .frame(maxWidth: .infinity)
            .frame(height: 43)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(NativeKeyboardStyle.keyFill)
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

private struct NativeSpecialKey: View {
    let symbol: String
    let width: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(.black.opacity(0.92))
            .frame(width: width, height: 43)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(NativeKeyboardStyle.specialKey)
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

private struct NativeKeyboardAccessoryRow: View {
    var body: some View {
        HStack(spacing: 6) {
            NativeBottomKey(text: "123", width: 42, fill: NativeKeyboardStyle.specialKey)
            NativeBottomKey(text: "空白", width: nil, fill: NativeKeyboardStyle.keyFill)
            NativeBottomKey(text: "改行", width: 78, fill: NativeKeyboardStyle.specialKey)
        }
        .frame(height: 43)
        .padding(.horizontal, 6)
    }
}

private struct NativeBottomKey: View {
    var text: String? = nil
    var symbol: String? = nil
    var width: CGFloat?
    let fill: Color

    var body: some View {
        Group {
            if let text {
                Text(text)
                    .font(.system(size: 18, weight: .regular))
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .regular))
            }
        }
        .foregroundStyle(.black.opacity(0.92))
        .frame(maxWidth: width == nil ? .infinity : nil)
        .frame(width: width, height: 43)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(fill)
                .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
        )
    }
}

private struct NativeResultDemo: View {
    let selectedIndex: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                NativeToolbarPill(title: "敬語", isSelected: true)
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(NativeKeyboardStyle.ink)
                    .frame(width: 38, height: 38)
            }
            .frame(height: 52)
            .padding(.horizontal, 6)

            NativeResultCarousel(selectedIndex: selectedIndex)
                .frame(height: 158)

            NativeRefinementRow()
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
    }
}

private struct NativeResultCarousel: View {
    let selectedIndex: Int

    private let cardWidth: CGFloat = 330
    private let spacing: CGFloat = 14
    private let samples = [
        "テストについてご案内いたします",
        "テストの件につきまして、ご案内申し上げます。",
        "テストについて、以下の通りご案内いたします。"
    ]

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                NativeCandidateCard(text: sample, isSelected: index == selectedIndex)
                    .frame(width: cardWidth, height: 156)
            }
        }
        .padding(.leading, 30)
        .offset(x: -CGFloat(selectedIndex) * (cardWidth + spacing))
        .frame(width: 390, height: 158, alignment: .leading)
        .clipped()
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: selectedIndex)
    }
}

private struct NativeCandidateCard: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(NativeKeyboardStyle.ink)
            .lineLimit(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? NativeKeyboardStyle.accent.opacity(0.74) : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

private struct NativeRefinementRow: View {
    private let chips = [
        ("arrow.clockwise", "再作成"),
        ("briefcase", "より丁寧に"),
        ("arrow.up.arrow.down", "より詳しく"),
        ("arrow.down.right.and.arrow.up.left", "短く")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    HStack(spacing: 5) {
                        Image(systemName: chip.0)
                            .font(.system(size: 14, weight: .regular))
                        Text(chip.1)
                            .font(.system(size: 17, weight: .regular))
                    }
                    .foregroundStyle(NativeKeyboardStyle.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Color.white.opacity(0.92), in: Capsule())
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 40)
    }
}

private struct ChatInputMock: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 30, height: 30)
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.black.opacity(0.7))
            }
            .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 0.5))

            HStack {
                Text("明日までに確認お願いします")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
                Rectangle()
                    .fill(OnboardingPalette.ink)
                    .frame(width: 1.2, height: 16)
                Spacer()
                Image(systemName: "mic")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.black.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(
                Capsule()
                    .fill(Color(red: 0.94, green: 0.93, blue: 0.95))
            )
        }
        .padding(.horizontal, 6)
    }
}

private struct KeyboardMock: View {
    private let suggestions = ["敬語", "ビジネス", "メール", "やわらかく"]
    private let row1 = ["q","w","e","r","t","y","u","i","o","p"]
    private let row2 = ["a","s","d","f","g","h","j","k","l"]
    private let row3 = ["z","x","c","v","b","n","m"]

    var body: some View {
        VStack(spacing: 8) {
            SuggestionBar(items: suggestions)
            KeyRow(keys: row1)
            KeyRow(keys: row2, sidePadding: 18)
            HStack(spacing: 5) {
                SpecialKey(symbol: "shift.fill", width: 36)
                ForEach(row3, id: \.self) { k in
                    LetterKey(label: k)
                }
                SpecialKey(symbol: "delete.left", width: 36)
            }
            HStack(spacing: 5) {
                BottomKey(text: "123", width: 42)
                BottomKey(symbol: "face.smiling", width: 36)
                BottomKey(text: "空白", width: nil)
                KeepKey()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.86, green: 0.87, blue: 0.89))
        )
    }
}

private struct SuggestionBar: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 0) {
            Text("AI")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 34, height: 26)
                .background(
                    Capsule()
                        .fill(Color(red: 0.18, green: 0.17, blue: 0.22))
                )
                .padding(.leading, 4)
                .padding(.trailing, 6)

            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                Text(item)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                if idx < items.count - 1 {
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 0.5, height: 16)
                }
            }
        }
        .background(Color.white.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .padding(.horizontal, 4)
    }
}

private struct KeyRow: View {
    let keys: [String]
    var sidePadding: CGFloat = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(keys, id: \.self) { k in
                LetterKey(label: k)
            }
        }
        .padding(.horizontal, sidePadding)
    }
}

private struct LetterKey: View {
    let label: String

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(OnboardingPalette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

private struct SpecialKey: View {
    let symbol: String
    let width: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(OnboardingPalette.ink)
            .frame(width: width, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(red: 0.74, green: 0.76, blue: 0.78))
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

private struct BottomKey: View {
    var text: String? = nil
    var symbol: String? = nil
    var width: CGFloat?

    var body: some View {
        Group {
            if let text {
                Text(text)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
            }
        }
        .frame(maxWidth: width == nil ? .infinity : nil)
        .frame(width: width, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
        )
    }
}

private struct KeepKey: View {
    var body: some View {
        Text("確定")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 64, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.46, blue: 0.93))
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

// MARK: - Reply feature announcement (existing users)
//
// Shown once as a bottom sheet to users who completed onboarding before the
// reply feature existed. New users meet the same demo on the onboarding
// `KeyboardReplyPage`, so the sheet is suppressed for them. Container chrome
// uses the Bikey Design System; the keyboard depiction keeps the native look.

struct ReplyFeatureSheet: View {
    @Environment(\.dismiss) private var dismiss

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
                        Text("新機能")
                            .bikeyFont(11, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(AppColor.purple)
                            .tracking(0.6)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(AppColor.paleLavender.opacity(0.85), in: Capsule())

                        Text("コピーした文に、\nワンタップで返信。")
                            .bikeyFont(24, weight: .medium, relativeTo: .title2)
                            .foregroundStyle(AppColor.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("LINEやメールで相手のメッセージをコピーすると、キーボードのツールバーに「返信」ボタンが表示されます。押すだけで、文脈に合った返信文の候補を作成します。")
                            .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    NativeKeyboardSurfaceMock(mode: .reply)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(red: 0.93, green: 0.92, blue: 0.91))
                        )

                    VStack(alignment: .leading, spacing: 12) {
                        ReplyFeaturePoint(icon: "doc.on.doc", text: "他のアプリでメッセージをコピー")
                        ReplyFeaturePoint(icon: "arrowshape.turn.up.left", text: "ツールバーの「返信」ボタンをタップ")
                        ReplyFeaturePoint(icon: "sparkles", text: "返信文の候補から選んで置き換え")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.l)
            }

            Button {
                dismiss()
            } label: {
                Text("使ってみる")
                    .bikeyFont(15, weight: .medium, relativeTo: .body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.charcoalAction, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, BikeyMetrics.Spacing.l)
            .padding(.bottom, BikeyMetrics.Spacing.m)
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}

private struct ReplyFeaturePoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppColor.purple.opacity(0.78))
                .frame(width: 26, height: 26)
                .background(AppColor.paleLavender.opacity(0.85), in: Circle())

            Text(text)
                .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(AppColor.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Previews

#Preview("Setup page") {
    KeyboardSetupPage(progress: 0.66, onBack: {}, onSkip: nil, onContinue: {})
}

#Preview("Usage page") {
    KeyboardUsagePage(progress: 0.88, onBack: {}, onContinue: {})
}

#Preview("Result page") {
    KeyboardResultPage(progress: 0.75, onBack: {}, onContinue: {})
}

#Preview("Reply page") {
    KeyboardReplyPage(progress: 0.66, onBack: {}, onContinue: {})
}

#Preview("Consent page") {
    KeyboardConsentPage(progress: 1.0, onBack: {}, onAgree: {}, onDecline: {})
}

#Preview("Reply feature sheet") {
    ReplyFeatureSheet()
}
