import KeyboardPreferences
import SwiftUI

// Display metadata + mini layout preview for the two Japanese input styles.
// Shared by the onboarding input-style page and the settings picker so both
// surfaces present the choice identically.

enum InputStyleOption {
    static let selectable: [KeyboardPreferences.KeyboardStyle] = [.japaneseRomaji, .japaneseFlick]

    static func title(_ style: KeyboardPreferences.KeyboardStyle) -> String {
        switch style {
        case .japaneseFlick: return "フリック"
        default: return "ローマ字"
        }
    }

    static func subtitle(_ style: KeyboardPreferences.KeyboardStyle) -> String {
        switch style {
        case .japaneseFlick: return "10キー入力"
        default: return "QWERTY配列"
        }
    }
}

struct InputStyleSelectionCard: View {
    let style: KeyboardPreferences.KeyboardStyle
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 14) {
                InputStyleMiniPreview(style: style)
                    .frame(height: 96)
                    .frame(maxWidth: .infinity)
                    .background(AppColor.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 3) {
                    Text(InputStyleOption.title(style))
                        .bikeyFont(16, weight: .semibold, relativeTo: .body)
                        .foregroundStyle(AppColor.ink)
                    Text(InputStyleOption.subtitle(style))
                        .bikeyFont(12, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(AppColor.muted)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? AppColor.purple : AppColor.rule.opacity(0.55))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? AppColor.purple : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(InputStyleCardPressStyle())
        .accessibilityLabel(InputStyleOption.title(style))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct InputStyleCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct InputStyleMiniPreview: View {
    let style: KeyboardPreferences.KeyboardStyle

    var body: some View {
        switch style {
        case .japaneseFlick: FlickMiniPreview()
        default: QwertyMiniPreview()
        }
    }
}

private struct QwertyMiniPreview: View {
    private let rows = [10, 9, 7]

    var body: some View {
        VStack(spacing: 5) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, count in
                HStack(spacing: 3) {
                    ForEach(0..<count, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 16)
                            .shadow(color: .black.opacity(0.10), radius: 0.5, x: 0, y: 0.5)
                    }
                }
                .padding(.horizontal, count == 7 ? 16 : (count == 9 ? 6 : 0))
            }
        }
        .padding(.horizontal, 12)
    }
}

private struct FlickMiniPreview: View {
    private let grid = [["あ", "か", "さ"], ["た", "な", "は"], ["ま", "や", "ら"]]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(grid.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColor.ink.opacity(0.85))
                            .frame(width: 22, height: 18)
                            .background(.white, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .shadow(color: .black.opacity(0.10), radius: 0.5, x: 0, y: 0.5)
                    }
                }
            }
        }
    }
}

#Preview("Input style cards") {
    HStack(spacing: 12) {
        InputStyleSelectionCard(style: .japaneseRomaji, isSelected: true, onTap: {})
        InputStyleSelectionCard(style: .japaneseFlick, isSelected: false, onTap: {})
    }
    .padding()
    .background(AppColor.canvas)
}
