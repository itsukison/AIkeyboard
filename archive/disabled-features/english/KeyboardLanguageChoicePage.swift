// DISABLED (2026-06-29): pulled out of the build for the tonight ship.
// To re-enable, move this file back into iOS/Container/ and re-apply the
// OnboardingFlow gate (see archive/disabled-features/english/RESTORE.md), then `xcodegen generate`.

import KeyboardPreferences
import SwiftUI
import UIKit

// MARK: - Keyboard language page

struct KeyboardLanguageChoicePage: View {
    let progress: Double
    @Binding var selectedLanguage: KeyboardPreferences.KeyboardLanguage
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: false,
            onBack: nil,
            onSkip: nil,
            ctaTitle: "次へ",
            isCtaEnabled: true,
            onCta: onContinue
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        Text("キーボードの言語")
                            .font(.system(size: 31, weight: .medium))
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("入力に使う言語を選びます。日本語のままでもOK。あとから設定でいつでも変更できます。")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(OnboardingPalette.subInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 28)

                    VStack(spacing: 12) {
                        ForEach(KeyboardPreferences.KeyboardLanguage.allCases, id: \.self) { language in
                            LanguageChoiceCard(
                                title: Self.title(language),
                                subtitle: Self.subtitle(language),
                                isSelected: selectedLanguage == language,
                                onTap: { selectedLanguage = language }
                            )
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private static func title(_ language: KeyboardPreferences.KeyboardLanguage) -> String {
        switch language {
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }

    private static func subtitle(_ language: KeyboardPreferences.KeyboardLanguage) -> LocalizedStringKey {
        switch language {
        case .japanese: return "日本語キーボード（標準）"
        case .english: return "English keyboard"
        }
    }
}

private struct LanguageChoiceCard: View {
    let title: String
    let subtitle: LocalizedStringKey
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColor.ink)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppColor.muted)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? AppColor.purple : AppColor.rule.opacity(0.55))
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? AppColor.purple : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
