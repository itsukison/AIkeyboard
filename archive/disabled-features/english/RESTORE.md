# English keyboard — disabled for the 2026-06-29 ship

The English keyboard mode (Phase 1) was built but is **incomplete/unverified**, so it
was pulled out of the build and made unreachable for tonight's release. Nothing in the
shipped app reads or writes the keyboard language, so it always behaves as Japanese-only.

## What's here (preserved, OUT of the build)
- `English/EnglishInputController.swift`, `English/EnglishActionHandler.swift`,
  `English/EnglishSuggestionBar.swift` — the keyboard-extension wiring (KeyboardKit).
- `KeyboardLanguageChoicePage.swift` — the onboarding language-choice page + card.

This directory is at the repo root and is **not** globbed by `project.yml`, so it does
not compile.

## What stayed in the repo (dormant, compiles, unreachable)
These are verified-compiling and harmless (nothing calls them):
- `Sources/KeyboardPreferences/KeyboardSettingsStore.swift` — `KeyboardLanguage` enum + `read/writeKeyboardLanguage` (no callers).
- `Sources/KeyboardPreferences/ConversionPreferenceStore.swift` — `.english` scope case.
- `Sources/JapaneseKeyboardCore/NextWordPrior.swift` — `completions(prefix:)`, `weight(for:)`, `englishUnigram`, `englishBigram` (lazy, never accessed).
- `Sources/JapaneseKeyboardCore/EnglishSuggestionEngine.swift` + `Tests/.../EnglishSuggestionEngineTests.swift`.
- `Sources/JapaneseKeyboardCore/Resources/english_unigram.bin` / `english_bigram.bin` (~2 MB, not loaded).
- `scripts/build_english_ngram.py`.

## To re-enable
1. `mv archive/disabled-features/english/English iOS/KeyboardExtension/English`
2. `mv archive/disabled-features/english/KeyboardLanguageChoicePage.swift iOS/Container/` (drop the top DISABLED comment + imports tweak if needed).
3. Re-apply the entry-point + extension wiring (all gated on `KeyboardSettingsStore.readKeyboardLanguage() == .english`):
   - **`iOS/KeyboardExtension/KeyboardViewController.swift`**: add `keyboardLanguage` stored prop + `lazy var englishController`; branch the action handler in `viewWillSetupKeyboardKit`; branch `configureInputManager` to skip the AzooKey load for English; add the English branch + `makeEnglishKeyboardView` in `viewWillSetupKeyboardView`; branch `textDidChange`/`selectionDidChange`; add the `configureEnglishKeyboardBehavior` guard in `configureJapaneseKeyboardBehavior`.
   - **`iOS/Container/ProfileScreen.swift`**: remove the identity card, add the keyboard-language picker (`アプリの言語` vs `キーボードの言語`).
   - **`iOS/Container/OnboardingFlow.swift`**: gate `body` on `languageChosen`, show `KeyboardLanguageChoicePage` first, English skips the input-style page (`pageIndex = 1`), and the `goBack` tweak.
4. `xcodegen generate`, then build in Xcode (iOS) and fix any KeyboardKit API mismatches
   in `makeEnglishKeyboardView` / `configureEnglishKeyboardBehavior` (these were never
   compile-verified).

Full context: memory note `multilingual-keyboard-direction`.
