# Architecture

Last verified against code: 2026-06-07. If you see drift, the code wins.

## Targets

There are two product targets and three SPM library products.

| Target | Type | Where |
|---|---|---|
| `BikeyJP` | iOS app | `iOS/Container/` + `iOS/Shared/` |
| `KeyboardExtension` | iOS app extension (`com.apple.keyboard-service`) | `iOS/KeyboardExtension/` + `iOS/Shared/` |
| `JapaneseKeyboardCore` | SPM library | `Sources/JapaneseKeyboardCore/` |
| `JapaneseKeyboardUI` | SPM library | `Sources/JapaneseKeyboardUI/` |
| `KeyboardPreferences` | SPM library | `Sources/KeyboardPreferences/` |

`BikeyJP` depends on all three SPM products plus `KeyboardKit` and
`Supabase`. `KeyboardExtension` depends on all three SPM products plus
`KeyboardKit` (no Supabase — the extension uses raw `URLSession`).

## Why the split

`Sources/` is everything that should run under `swift test` without UIKit:

- `JapaneseKeyboardCore` — `InputManager`, `RomajiInputBuffer`,
  `KanaKanjiAdapter`, `Candidate`, `ConversionPreferenceStore`. Pure IME
  state machine.
- `JapaneseKeyboardUI` — SwiftUI views. Imports `KeyboardKit`. Also hosts
  the AI domain models (`RewriteRequest`, `RewriteResult`,
  `WholeInputCapture`) and `RefinementIntent` — see "Planned restructure"
  below; these models do not actually belong in a UI module.
- `KeyboardPreferences` — App Group `UserDefaults` wrappers
  (`KeyboardSettingsStore`, `UserPromptStore`, `AIAuthStore`).

`iOS/KeyboardExtension/AI/` is everything that needs `UITextDocumentProxy`
or the keyboard's `UIInputViewController` lifecycle:

- `KeyboardViewController` (`KeyboardInputViewController` subclass)
- `JapaneseActionHandler` (KeyboardKit subclass)
- `AIKeyboardController` (owns rewrite state, talks to the proxy)
- `InputCapture`, `WholeInputReplacementEngine`,
  `CloudRewriteService` — currently here, planned to move to a new
  SPM target.

## Critical state machines

### IME composition state (`InputManager`)

```
empty ──appendRomaji──▶ composing(kana)
                            │
                            ├─ appendRomaji ─▶ composing(kana)  [updates display, re-converts]
                            ├─ space ───────▶ composing(kana, selectedIndex=n)  [cycles candidates]
                            ├─ candidate tap ▶ committed       [via commitCandidate]
                            ├─ return ───────▶ committed       [via commitComposingForReturn]
                            ├─ backspace #1 ─▶ composing(kana) [cancels selection if any]
                            ├─ backspace #2+ ▶ composing(kana−1 unit) or empty
                            └─ reset ────────▶ empty            [external trigger]
```

Marked text shown in the host: kana while composing, candidate text once
the user has cycled. Commit always inserts the currently-shown text — never
"guesses" a kanji the user didn't see.

### AI rewrite state (`AIKeyboardState`)

```
.hidden ──┬─ runMain ──────────────────▶ .generating
          │                                  │
          ├─ toggleOverflow ──▶ .overflow ───┤
          │                                  ▼
          └─ ◀────────── error ───── .result  ──┬─ regenerate / refine ─▶ .generating
                                                ├─ replaceFocused ──▶ .hidden (text replaced)
                                                └─ close ───────────▶ .hidden
```

`.error` transitions out via `close()` or the next user-initiated command.

### Replacement contract (`WholeInputReplacementEngine`)

Capture and replace must operate on the same available context. Replace
re-reads the proxy, validates that `before + selected + after` still
equals the captured `targetText`, and aborts (`ReplacementError.contextChanged`)
if not. This is the safety net against the user typing while generation
runs.

The replacement itself is:

```
adjustTextPosition(byCharacterOffset: capture.moveToEndCharacterCount)
deleteBackward × capture.deleteBackwardCharacterCount
insertText(replacement)
```

Character counts are Swift `Character` counts. Tests for composed
characters (dakuten / emoji ZWJ sequences) live alongside the engine.

## Data flow between container and extension

Only the App Group `group.co.gastroduce-japan.bikey.japanese` is shared.
Keys (in `KeyboardSettingsStore`):

| Key | Writer | Reader |
|---|---|---|
| `keyboardStyle` | container | extension |
| `hapticsEnabled` | container | extension |
| `cloudAIEnabled` | container | extension |
| `userPromptEntries` (encoded `[UserPrompt]`) | container | extension |
| `conversionPreferenceEntries` (learning data) | extension | extension |
| `anonymousDeviceId` | first reader | both |
| `lastKnownFullAccessEnabled` | extension | container (debug only) |
| `aiAccessToken` / `aiRefreshToken` / `aiTokenExpiresAt` | container | extension |

The container app holds the Supabase session; the extension is a read-only
consumer of the cached token. Token refresh runs inside the extension
when the cached token is within 30 s of expiry — see
`CloudRewriteService.ensureFreshAccessToken`.

## Planned restructure

The single biggest production-readiness gap is that AI domain logic lives
in the extension target, so `swift test` can't reach it. Target shape:

```
Sources/
  JapaneseKeyboardCore/            ← unchanged
  JapaneseKeyboardUI/              ← unchanged, minus AI/ models
  KeyboardPreferences/             ← split into per-store files
  JapaneseKeyboardAI/              ← NEW
    Models/                        ← moved from JapaneseKeyboardUI/AI/
      RewriteModels.swift
      AIKeyboardState.swift
      RefinementIntent.swift
    Capture/
      WholeInputCapture.swift
      WholeInputReplacementEngine.swift  ← UIKit boundary as a protocol
    Service/
      RewriteService.swift
      CloudRewriteService.swift
      CloudRewriteConfiguration.swift    ← endpoint via build setting
```

`AIKeyboardController` stays in the extension because it depends on
`UIInputViewController`, but it shrinks to coordination only — capture and
replacement become protocol calls against `Sources/JapaneseKeyboardAI/`.

This is not done yet. Track in the open items list in `AGENTS.md` §8.

## Performance and memory

- Keyboard extension peak target: < 40 MB resident. Jetsam kills around
  30–60 MB. AzooKey's default dictionary is the dominant cost (10–20 MB).
- Live conversion debounce: 15 ms (`InputManager.scheduleConversion`).
  Aggressive but fine because AzooKey conversion is fast and we cancel
  in-flight tasks on every keystroke.
- AI request timeout (client side): 20 s
  (`CloudRewriteService.urlRequest.timeoutInterval`).
- AI request timeout (server side): 8 s default (`GROQ_TIMEOUT_MS`).
