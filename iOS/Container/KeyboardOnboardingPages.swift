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

                        Text("候補バー左のAIボタンを押すだけ。上司、取引先、教授、採用担当に送る前に、自然な敬語へ整えます。")
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
        VStack(spacing: 10) {
            ChatInputMock()
            KeyboardMock()
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.93, green: 0.92, blue: 0.91))
        )
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

// MARK: - Previews

#Preview("Setup page") {
    KeyboardSetupPage(progress: 0.66, onBack: {}, onSkip: nil, onContinue: {})
}

#Preview("Usage page") {
    KeyboardUsagePage(progress: 0.88, onBack: {}, onContinue: {})
}
