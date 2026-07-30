// DEFERRED — NOT COMPILED. Parked key-size settings UI, removed from
// iOS/Container/ProfileScreen.swift + InputStyleSelection.swift on 2026-07-03.
// See README.md in this folder for why and how to re-enable.
//
// This is the UI layer only. The rendering plumbing it drives
// (KeyboardKeySizeObserver, KeyboardKeySizePreset, the store read/write, the
// keySizeObserver param on FlickKeyboardView/QwertyKeyboardView, and the
// extension's viewWillAppear refresh) is still live in the compiled sources —
// dormant at .standard because nothing writes a non-standard preset once this
// UI is gone.

import KeyboardPreferences
import SwiftUI

enum KeyboardKeySizeOption {
    static func title(_ preset: KeyboardKeySizePreset) -> LocalizedStringKey {
        switch preset {
        case .small: return "小さい"
        case .slightlySmall: return "やや小さい"
        case .standard: return "標準"
        case .slightlyLarge: return "やや大きい"
        case .large: return "大きい"
        }
    }
}

// The following members belonged to KeyboardSettingsView. To re-enable:
//   1. Restore `@Binding var sizePreset` + `@StateObject previewKeySize` +
//      `@State showKeyboardPreview` on KeyboardSettingsView, and the
//      `sizePreset:` argument at its call site + the `keyboardKeySizePreset`
//      state and subtitle in ProfileScreen.
//   2. Re-add the "キーサイズ" section (title + keyboardKeySizeCard) to the body.
//   3. Move KeyboardSizePreviewPane.swift back into iOS/Container/ and re-add
//      the `.safeAreaInset`/`.onAppear` preview overlay.
//   4. Restore KeyboardKeySizeOption into InputStyleSelection.swift.
//   5. `xcodegen generate`.
//
// Known issues to fix before shipping (from the 2026-07-03 device test):
//   - The preview pane overlapped the tab bar and showed no candidate toolbar.
//   - The ±4pt keyCapInset (KeyboardKeySizePreset.keyCapInsetAdjustment) is too
//     small to read as a size change — reconsider the adjustment magnitude or
//     change actual key/row height, not just the cap inset.

/*
    private var keyboardKeySizeCard: some View {
        VStack(spacing: BikeyMetrics.Spacing.m) {
            HStack {
                Text("キーサイズ")
                    .bikeyFont(15, weight: .medium, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)

                Spacer()

                Text(KeyboardKeySizeOption.title(sizePreset))
                    .bikeyFont(13, weight: .semibold, relativeTo: .footnote)
                    .foregroundStyle(AppColor.purple)
            }

            KeyboardSizePreviewPane(style: selection, keySizeObserver: previewKeySize)

            Slider(
                value: sizeSliderBinding,
                in: 0...Double(KeyboardKeySizePreset.allCases.count - 1),
                step: 1
            )
            .tint(AppColor.purple)
            .accessibilityLabel("キーサイズ")
            .accessibilityValue(KeyboardKeySizeOption.title(sizePreset))

            HStack {
                Text("小さい")
                Spacer()
                Text("標準")
                Spacer()
                Text("大きい")
            }
            .bikeyFont(11, weight: .regular, relativeTo: .caption)
            .foregroundStyle(AppColor.muted)

            if sizePreset != .standard {
                Button("標準に戻す") {
                    sizePreset = .standard
                    previewKeySize.preset = .standard
                    KeyboardSettingsStore.writeKeyboardKeySizePreset(.standard)
                }
                .bikeyFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(AppColor.purple)
                .buttonStyle(.plain)
            }
        }
        .padding(BikeyMetrics.Spacing.m)
        .background(AppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 18, x: 0, y: 10)
    }

    private var sizeSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(KeyboardKeySizePreset.allCases.firstIndex(of: sizePreset) ?? 2)
            },
            set: { value in
                let index = min(
                    max(Int(value.rounded()), 0),
                    KeyboardKeySizePreset.allCases.count - 1
                )
                let preset = KeyboardKeySizePreset.allCases[index]
                sizePreset = preset
                previewKeySize.preset = preset
                KeyboardSettingsStore.writeKeyboardKeySizePreset(preset)
            }
        )
    }
*/
