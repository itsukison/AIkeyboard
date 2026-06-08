# Development

## Prerequisites

- macOS with Xcode 16+
- Swift 6.1+
- `xcodegen` (`brew install xcodegen`)
- For backend: Supabase CLI (`brew install supabase/tap/supabase`) and
  Deno (only if you want to run the Edge Function locally)

## Build

```bash
cd Japanese
xcodegen generate
open BikeyJP.xcodeproj
```

Build and run the `BikeyJP` scheme. The keyboard extension target is
built and embedded automatically.

The scheme name is still legacy `BikeyJP`; the user-facing product name
is `AIキーボード`. Rename is deferred — see open items in `AGENTS.md` §8.

### Optional dev-only build settings

`Config/Local.xcconfig` (gitignored) is wired up as the Debug/Release
xcconfig source for the `KeyboardExtension` target via `project.yml`.
Currently no keys are required — see `Config/Local.example.xcconfig`.
You can leave the file empty or omit it; if missing, Xcode will warn
during `xcodegen generate` but the build still succeeds.

## Test

```bash
swift test
```

Covers `JapaneseKeyboardCore` (`Romaji`, `RomajiInputBuffer`,
`KanaKanjiAdapter`, `InputManager`, `ConversionPreferenceStore`) and
`JapaneseKeyboardUI`. The AI capture/replacement engine and the
`AIKeyboardController` are currently in the extension target and not
reachable from `swift test` — see the planned `JapaneseKeyboardAI`
target in `docs/architecture.md`.

## Run on simulator

1. Run the `BikeyJP` scheme on a simulator.
2. In the simulator, open
   `Settings > General > Keyboard > Keyboards > Add New Keyboard` and
   select `AIキーボード` (may still appear as `BikeyJP`).
3. In any text field, long-press the globe key and switch.

For Cloud AI:

1. Sign in inside the container app.
2. Toggle Cloud AI on.
3. In iOS Settings, enable Allow Full Access for the keyboard.

Without Full Access the base keyboard still works; AI commands surface
a Japanese error message and stop.

## Run on a real device

Add your team via Xcode signing. The Bundle IDs are:

- Container: `co.gastroduce-japan.bikey.japanese`
- Extension: `co.gastroduce-japan.bikey.japanese.keyboard`
- App Group: `group.co.gastroduce-japan.bikey.japanese`

You need a paid developer account to enable App Groups + custom keyboard
extensions on a real device.

## Backend

Deploy:

```bash
cd supabase
supabase functions deploy keyboard-rewrite
```

Verify with the curl recipes in `docs/backend.md`. Required secret:
`CEREBRAS_API_KEY` or `GROQ_API_KEY`. For production abuse protection, apply
the usage-guard migration and set `USAGE_GUARD_MODE=db`.

## Common gotchas

- **`KeyboardContext.sync(with:)` resets your state.** KeyboardKit's
  `super.viewWillAppear` re-reads the host proxy's autocapitalization
  type and flips `keyboardCase` to `.uppercased` on chat fields. Always
  re-apply our overrides after super runs — see
  `KeyboardViewController.viewWillAppear`.
- **Backspace during composition must consume on `.press`/`.repeatPress`,
  not `.release`.** Otherwise KeyboardKit's release-side `deleteBackward`
  races our marked-text writes and the user sees flicker. See
  `JapaneseActionHandler.handle`.
- **`tryChangeKeyboardCase` is a no-op.** KeyboardKit's default
  implementation re-uppercases after every gesture; we override to keep
  the romaji layer lowercase. Don't remove the override.
- **App Group writes from the extension are best-effort.** iOS does not
  flush UserDefaults synchronously across processes — the container may
  not see a write until both processes lifecycle. Don't build features
  that need sub-second cross-process consistency.
- **`textDocumentProxy.documentIdentifier` is host-controlled.** Treat
  it as a coarse "did the document change?" signal, not a stable ID
  across keyboard restarts.
- **Memory is the silent killer.** Profile in Instruments under typical
  usage and confirm peak < 40 MB. AzooKey's dictionary load is the
  biggest single cost — make sure nothing else holds a reference that
  prevents release.

## Memory profiling

The keyboard extension's hard ceiling is jetsam (around 30–60 MB on
recent devices). Target peak: < 40 MB. Profile before any release.

Manual checklist on a real device (iPhone 12 or older):

1. Build the `BikeyJP` scheme to a real device, Release configuration.
2. Enable the keyboard in Settings → General → Keyboard → Keyboards.
3. Allow Full Access (so Cloud AI is testable).
4. Open Xcode → Debug → Attach to Process → `KeyboardExtension`.
5. In Xcode → Debug Navigator → Memory, watch the resident size as you
   exercise these flows in Notes:
   - Cold open the keyboard.
   - Type a 30-character Japanese sentence with conversion.
   - Cycle through candidates 10 times.
   - Tap the main AI prompt; wait for result; tap 置き換え.
   - Repeat the AI flow 5 times in a row.
   - Open the `…` overflow drawer; tap each sub-prompt.
6. Record peak resident memory after each phase. Fail the release if
   peak exceeds 40 MB at any point.

When a peak exceeds 40 MB, the usual suspects:

- AzooKey dictionary loaded twice (check `KanaKanjiAdapter`).
- A SwiftUI `@StateObject` retained across keyboard dismissal (check
  `KeyboardViewController.viewDidLoad` for strong references).
- A `URLSession` shared instance accumulating in-flight tasks
  (`CloudRewriteService` should always cancel via `rewriteTask?.cancel()`).
- A `UIHostingController` not torn down between sessions (see
  `SnapCarouselView`).

## CI

`.github/workflows/ci.yml` runs on every push and PR to `main`:

- macOS-15 runner, Xcode 16
- `xcodegen generate` + `xcodebuild -resolvePackageDependencies`
- `JapaneseKeyboardAITests` + `JapaneseKeyboardCoreTests` via xcodebuild
- Release-config build of the keyboard extension (catches Release-only
  Swift settings drift)
- `deno check` on the Supabase Edge Function

Add new test targets to the CI workflow when you add them to
`project.yml`.

## Code style

Per `CLAUDE.md`:

- Surgical changes only. Don't refactor adjacent code you didn't touch.
- No speculative abstractions, no flexibility that wasn't requested.
- Match existing style even if you'd do it differently.
- Default to no comments. Add one only when the *why* is non-obvious.

If you find yourself writing more than ~50 lines for what should be a
small change, stop and reconsider.
