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
open KeigoButton.xcodeproj
```

Build and run the `KeigoButton` scheme. The keyboard extension target is
built and embedded automatically.

The Xcode project and scheme are `KeigoButton`; the user-facing product name
is `AIキーボード`.

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

Covers `JapaneseKeyboardCore`, `JapaneseKeyboardUI`, and the
`JapaneseKeyboardAI` capture/replacement engine. Extension lifecycle code
still needs Xcode target tests or simulator coverage.

## Run on simulator

1. Run the `KeigoButton` scheme on a simulator.
2. In the simulator, open
   `Settings > General > Keyboard > Keyboards > Add New Keyboard` and
   select `AIキーボード`.
3. In any text field, long-press the globe key and switch.

For Cloud AI:

1. Sign in inside the container app.
2. Toggle Cloud AI on.
3. In iOS Settings, enable Allow Full Access for the keyboard.

Without Full Access the base keyboard still works; AI commands surface
a Japanese error message and stop.

## Run on a real device

Add your team via Xcode signing. The Bundle IDs are:

- Container: `com.core7.keigobutton`
- Extension: `com.core7.keigobutton.keyboard`
- App Group: `group.com.core7.keigobutton`

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

1. Build the `KeigoButton` scheme to a real device, Release configuration.
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

## Input latency profiling

`InputLatencyProbe` (`Sources/JapaneseKeyboardCore/InputLatencyProbe.swift`)
measures why typing feels slower than the native keyboard. Every entry point
compiles to nothing in Release, so it costs nothing to leave the call sites in.

What it records:

| Metric | Meaning |
|---|---|
| `impactOccurred` | UIKit's key-press haptic call. A cold Taptic Engine would show up here. |
| `playInputClick` | The key click sound. |
| `textDidChange` / `selectionDidChange` | The whole handler, with each piece (`├ …`) timed separately. |
| `setMarkedText` | The marked-text write to the host (cross-process). |
| `convert` | One `requestCandidates` — Zenzai included. |
| `runloop-stall` | How late a 60 Hz main-runloop timer fires. The overall congestion number. |

How to read it:

1. Build the `KeyboardExtension` scheme (Debug) to a real device — the
   simulator's CPU scheduling doesn't represent anything. Rebuilding is not
   enough on its own: iOS keeps the extension process alive, so switch to
   another keyboard and back to force it to restart.
2. Attach Xcode to the `KeyboardExtension` process, open a text field, and type
   a normal Japanese sentence with conversion.
3. Read the `⏱ LATENCY` table in the console: printed every 5 s while the
   keyboard is up, and again on dismiss (`[FINAL]`). Samples reset on every
   appearance, so one keyboard session = one reading. Filter on `LATENCY` —
   every row carries the marker, precisely so filtering keeps all of them.
4. For a timeline instead of aggregates, profile with Instruments and look at
   the Points of Interest track (subsystem `com.core7.keigobutton`, category
   `InputLatency`) — the same intervals appear as signposts.

Comparing a fix: record a `[FINAL]` table before and after on the same device,
typing the same sentence. p90 matters more than p50 — the felt lag is the
occasional slow keystroke, not the median one.

### Baseline measured 2026-07-30 (real device, romaji layout)

| Metric | p50 | p90 | max |
|---|---|---|---|
| `convert` | 57-62 ms | 122-133 ms | 233 ms |
| `runloop-stall` | 0.0 ms | 0.1-0.3 ms | 0.5-9.4 ms |
| `impactOccurred` | 0.2 ms | 0.3 ms | 0.7 ms |
| `setMarkedText` | 0.0 ms | 0.0 ms | 0.1 ms |
| `textDidChange` | 0.3 ms (**n=1 per session**) | — | — |

Conclusions that came out of it, so nobody re-litigates them:

- **The input path is not the problem.** Physical touch reaches the extension in
  ~15-18 ms, KeyboardKit's `.press` arrives ~2 ms later, and the haptic call
  costs 0.2 ms. Finger to haptic is roughly one frame.
- **`textDidChange` does not fire per keystroke.** It fired once per *session*
  against ~50 keystrokes — marked-text updates aren't a host document change.
  Nothing in that handler is on the hot path, including the `DateFormatter` in
  `markTypedActivityIfNeeded` and the pasteboard read in
  `refreshReplyAvailability`.
- **Zenzai does not starve the main thread** on a modern device: `convert` costs
  57-62 ms per keystroke but `runloop-stall` stays at 0. It runs on the converter
  actor, off the main thread. What it does cost is candidate freshness — the
  candidate bar trails typing by 57-133 ms.
- Do **not** try to measure finger-to-haptic with an observing recognizer on the
  root view. See the warning in `InputLatencyProbe`'s doc comment: the ordering
  isn't guaranteed and the metric degrades into the inter-keystroke interval.

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
