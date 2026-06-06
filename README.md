# AIキーボード

Japanese AI keyboard for iOS. The product starts as a reliable Japanese keyboard and grows into a keyboard-native writing assistant for proofreading, natural rewrites, polite/business tone, concise rewrites, and translation.

The user-facing product name is `AIキーボード`. Some internal targets, schemes, and legacy project files may still use `BikeyJP` while the app is being renamed.

## Product Direction

`AIキーボード` should feel like a normal Japanese keyboard until the user explicitly asks for AI help:

- normal Japanese input by default
- an AI button at the left side of the candidate bar
- a compact command strip with `校正`, `自然に`, `丁寧に`, `短く`, `英訳`, and `日訳`
- a generated result card inside the keyboard
- a primary `置き換え` action that replaces the captured input

For v1, AI rewrites the whole available input text captured through `UITextDocumentProxy`, not an arbitrary highlighted subsection. If the cursor is in the middle of the text, replacement moves to the end of the captured input, deletes that captured text, and inserts the rewrite.

## AI And Privacy Model

The keyboard must not send every keystroke. Text is sent only when the user taps an AI command.

AI provider strategy:

- Cloud AI is the first real provider for v1, guarded by explicit opt-in and iOS `Allow Full Access`.
- The OpenAI API key stays on the backend, never in the iOS app or keyboard extension.
- Foundation Models can be added later as an on-device provider where iOS, device support, locale support, and keyboard-extension compatibility allow it.
- Normal Japanese typing must continue to work without Full Access and without Cloud AI.

Current backend:

- Supabase Edge Function: `keyboard-rewrite`
- URL: `https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite`
- Auth: early TestFlight shared client token via `X-AI-Keyboard-Client-Token`
- Device bucketing: `X-AI-Keyboard-Device-Id`
- Current known limitation: daily quota is an in-memory first cut and should become database-backed before public launch.

See `docs/ai-writing-keyboard-research.md`, `docs/ai-writing-keyboard-implementation.md`, and `docs/supabase-keyboard-rewrite-backend.md` for details.

## Requirements

- macOS with Xcode 16+
- Swift 6.1+
- `xcodegen` (`brew install xcodegen`)
- iOS 16.4+ deployment target

## Build

```bash
cd Japanese
xcodegen generate
open BikeyJP.xcodeproj
```

Build the `BikeyJP` scheme. The keyboard extension is built and embedded automatically. The scheme name is still legacy naming; the product direction and user-facing name are `AIキーボード`.

## Run on simulator

1. Run the `BikeyJP` scheme on a simulator.
2. In the simulator, open `Settings > General > Keyboard > Keyboards > Add New Keyboard` and select the keyboard. It may still appear as `BikeyJP` until the rename is complete.
3. In any text field, long-press the globe key and switch to the keyboard.

Cloud AI cannot run from a third-party keyboard unless the app requests Open Access and the user enables `Allow Full Access`. The base keyboard should still work without this setting.

## Run package tests

```bash
swift test
```

## Project layout

- `Sources/JapaneseKeyboardCore/` — IME logic (romaji to kana, kana to kanji)
- `Sources/JapaneseKeyboardUI/` — SwiftUI keyboard views
- `Sources/KeyboardPreferences/` — settings + App Group identifier
- `iOS/Container/` — container SwiftUI app
- `iOS/KeyboardExtension/` — `UIInputViewController` subclass
- `supabase/functions/keyboard-rewrite/` — Cloud AI rewrite backend
- `docs/` — AI keyboard research, implementation plan, and backend notes
- `Tests/` — package unit tests

## Near-Term Implementation Order

1. Keep the pure Japanese keyboard stable.
2. Add the AI button and command strip with a fake local rewrite.
3. Implement whole-input capture and replacement through `UITextDocumentProxy`.
4. Add the result card and stable loading/error states.
5. Connect `CloudRewriteService` to the Supabase rewrite endpoint.
6. Add Full Access, Cloud AI, and privacy settings in the container app.
7. Add Foundation Models later as a privacy-friendly on-device enhancement.
# AIkeyboard
