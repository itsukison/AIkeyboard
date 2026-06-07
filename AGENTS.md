# AGENTS.md

**Read this file first.** It is the single source of truth for any agent or new
engineer joining this codebase. Everything else under `docs/` is reference
material that this file points to.

Last verified against the code: 2026-06-07.

---

## 1. What this project is

`AIキーボード` is a third-party Japanese iOS keyboard with an AI rewrite
mode. There are two user surfaces:

- **Keyboard extension** — a stock-iOS-looking Japanese keyboard built on
  `KeyboardKit` + `AzooKeyKanaKanjiConverter`. Pure local conversion, no
  network in the typing path.
- **Container app** — onboarding, sign-in, prompt management, settings. Uses
  the Bikey Design System (purple accent on canvas + Liquid Glass on iOS 26+).

The AI rewrite mode lives in the keyboard extension's toolbar and overlay. It
sends the captured input to a Supabase Edge Function (`keyboard-rewrite`) only
when the user explicitly taps an AI command. Every keystroke is **not** sent.

Internal/legacy name: `BikeyJP` (still the Xcode scheme name). User-facing name
is `AIキーボード`.

---

## 2. Hard constraints — read before you change anything

These come from `CLAUDE.md` and Apple's keyboard-extension rules. Violating
them gets users killed by jetsam or rejected by App Review.

- **Memory ceiling**: iOS kills keyboard extensions around 30–60 MB resident.
  Target < 40 MB peak. Don't add heavy frameworks to the extension target.
- **No network in the typing path**: only Cloud AI rewrite calls go over the
  network, and only after the user taps a command. Never send keystrokes,
  never run analytics from the extension.
- **App Group is the only IPC** between container and extension. Identifier:
  `group.co.gastroduce-japan.bikey.japanese`. No URL schemes (except the
  `aikeyboard://settings` deeplink from the keyboard to the container) and
  no shared keychain in v1.
- **Keyboard surface looks native, container looks Bikey**. Do not put purple
  / Liquid Glass / Bikey design tokens on the keyboard. Do not put the iOS
  system-keyboard look on the container.
- **No bilingual logic**. This is a pure Japanese product. Reject any feature
  that only makes sense in mixed JA/EN typing.

---

## 3. Repository layout (current reality)

```
/
├── AGENTS.md                         ← you are here
├── CLAUDE.md                         ← behavioral guidelines for agents
├── README.md                         ← short build/run for humans
├── Package.swift                     ← SPM manifest (4 library products)
├── project.yml                       ← XcodeGen config (container + extension)
├── Config/
│   ├── Local.example.xcconfig        ← copy to Local.xcconfig
│   └── Local.xcconfig                ← gitignored, optional dev settings
├── Sources/                          ← SPM-testable Swift
│   ├── JapaneseKeyboardCore/         ← IME logic (no UI, no UIKit)
│   ├── JapaneseKeyboardUI/           ← SwiftUI keyboard views (KeyboardKit-dependent)
│   ├── JapaneseKeyboardAI/           ← AI rewrite domain (capture, replace, service)
│   └── KeyboardPreferences/          ← App Group settings + auth token cache
├── iOS/
│   ├── Container/                    ← main app target (BikeyJP)
│   │   └── Design/                   ← Bikey Design System (container-only)
│   ├── KeyboardExtension/            ← UIInputViewController + UIKit glue
│   │   └── AI/                       ← AIKeyboardController, toolbar view, proxy adapter
│   └── Shared/                       ← types used by both targets
├── Tests/                            ← swift test
├── supabase/
│   └── functions/keyboard-rewrite/   ← Edge Function (Deno + Groq)
├── docs/                             ← reference docs (see §6)
└── public/                           ← splash + onboarding images
```

### Module dependency rules

```
KeyboardPreferences  ──┐
                       ├──→ JapaneseKeyboardCore ──→ JapaneseKeyboardUI
                       │                                    ↑
              Container app and KeyboardExtension both depend on all three
```

`Sources/` is pure Swift Package — no UIKit lifecycle, no `Bundle.main`
lookups, no `UITextDocumentProxy`. UIKit-dependent glue lives in
`iOS/KeyboardExtension/` and `iOS/Container/`.

---

## 4. How the AI rewrite actually works

Pipeline, end to end:

1. User taps the main prompt pill (or expands `…` → sub-prompt) in
   `AIKeyboardToolbarView` (`iOS/KeyboardExtension/AI/AIKeyboardToolbarView.swift`).
2. `AIKeyboardController.runMain()` / `.runFromOverflow()` flushes any pending
   romaji composition, then calls `InputCapture.capture(from:)` to read
   `documentContextBeforeInput` + `selectedText` + `documentContextAfterInput`
   from `UITextDocumentProxy`. The full string is the rewrite target.
3. The controller checks: Cloud AI toggle ON, Full Access ON, signed-in
   Supabase access token present. If any fails, surface a Japanese error
   string and stop.
4. `CloudRewriteService.rewrite(...)` POSTs to
   `https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite`
   with `Authorization: Bearer <Supabase user JWT>` + `apikey: <publishable>`.
   Refreshes the access token via `auth/v1/token?grant_type=refresh_token` if
   it's within 30 s of expiry.
5. The Edge Function (`supabase/functions/keyboard-rewrite/index.ts`)
   validates the JWT, enforces a daily per-user quota, calls Groq Chat
   Completions (`openai/gpt-oss-120b` by default) with `response_format =
   json_schema` (strict), and returns `{ candidates, language }`.
6. The result card (`AIResultOverlayView`) shows the candidates in a snap
   carousel. The user picks one, taps `置き換え`, and
   `WholeInputReplacementEngine.replace(...)` validates that the proxy
   context still matches what we captured, then performs
   `adjustTextPosition` → `deleteBackward` × N → `insertText(replacement)`.

### Auth model (do not confuse with old docs)

- **Current (live)**: Supabase JWT auth. Container app signs the user in via
  Supabase, caches `{accessToken, refreshToken, expiresAt}` in App Group
  (`AIAuthStore`). Keyboard reads the cached token, refreshes if needed,
  sends as bearer.
- **Old (removed June 2026)**: shared TestFlight token
  `X-AI-Keyboard-Client-Token` + `X-AI-Keyboard-Device-Id`. The
  `AIKeyboardRewriteToken` Info.plist key and `AI_KEYBOARD_REWRITE_TOKEN`
  xcconfig var are gone. Any doc that mentions them is **stale**.

---

## 5. How the Japanese IME actually works

`InputManager` (`Sources/JapaneseKeyboardCore/InputManager.swift`) is the
state machine. The flow:

1. `JapaneseActionHandler` (KeyboardKit subclass) intercepts every key
   gesture in the extension. ASCII letters and `-` get routed into
   `InputManager.appendRomaji`; everything else falls through to KeyboardKit.
2. `RomajiInputBuffer` accumulates romaji and exposes a live `displayKana`.
3. On each change, `InputManager` schedules a 15 ms-debounced async
   conversion through `KanaKanjiAdapter` (wraps AzooKey's converter).
4. Candidates come back, are re-ranked by per-user learning data
   (`ConversionPreferenceStore`), and exposed as `@Published candidates`.
5. The marked-text preview is pushed to `UITextDocumentProxy` via the
   `onMarkedTextDidChange` callback wired in `KeyboardViewController`.
6. Space cycles candidates (`selectNextCandidate`); return commits
   (`commitComposingForReturn`); tapping a candidate in `CandidateBar`
   commits directly. Backspace first cancels candidate selection, then
   shrinks the buffer.

Critical edge cases (do not regress):

- KeyboardKit's `tryChangeKeyboardCase` is overridden to no-op
  (`JapaneseActionHandler.swift`). Without this, every gesture re-uppercases
  the alphabetic layer and the romaji buffer breaks.
- Backspace must consume on `.press`/`.repeatPress`, not `.release`, when
  composing. The `.release` is swallowed to avoid double-firing.
- `viewWillAppear` re-applies `configureJapaneseKeyboardBehavior` after
  `super` runs, because `KeyboardContext.sync(with:)` resets shift state.

---

## 6. Where to read more

Authoritative docs (other docs in `docs/` should be considered noise):

| File | Purpose |
|---|---|
| `docs/architecture.md` | Module boundaries, state machines, why things live where |
| `docs/backend.md` | Supabase Edge Function contract, secrets, deployment |
| `docs/ai-rewrite.md` | Product UX, prompt design, replacement algorithm |
| `docs/development.md` | Build, test, simulator setup, common gotchas |
| `docs/archive/` | Historical plans — do not treat as current truth |

Read in that order if you are new. If a fact in any doc contradicts the
code, the code wins — fix the doc.

---

## 7. Commands you'll actually run

```bash
# generate Xcode project (after editing project.yml or moving files)
xcodegen generate

# open in Xcode
open BikeyJP.xcodeproj

# package-level tests (Core IME logic only — extension and AI flows are
# tested via the JapaneseKeyboardCoreTests / JapaneseKeyboardUITests targets
# inside Xcode)
swift test

# deploy backend
cd supabase
supabase functions deploy keyboard-rewrite
```

---

## 8. Open production-readiness items

Tracked here so they don't get lost. None block TestFlight, all block
public launch.

- DB-backed daily quota in the Edge Function (currently in-memory per warm
  runtime).
- Split `AIKeyboardToolbarView.swift` (currently 720+ lines hosting the
  toolbar, overlay, snap carousel, cards, shimmer, and refinement chips).
- Split `Sources/KeyboardPreferences/Preferences.swift` into
  `KeyboardSettingsStore`, `UserPrompts`, `AIAuthStore` files.
- CI: `.github/workflows/ci.yml` running `swift test` + `xcodebuild` + a
  format/lint check.
- App Store privacy nutrition label and `docs/privacy.md` written for
  review.
- Memory profile on iPhone 12: confirm < 40 MB peak with the AI overlay
  rendered.

---

## 9. House rules

From `CLAUDE.md`:

- Surgical changes only. Don't refactor adjacent code you didn't touch.
- No speculative abstractions, no flexibility that wasn't requested, no
  error handling for impossible cases.
- Match existing style even if you'd do it differently.
- Ask before destructive operations (deletes, force-pushes, dropping
  dependencies). The `fix/` scratch directory and
  `supabase/functions/_deprecated/` rollback folder are untracked — leave
  them alone unless the user asks for cleanup.
- Default to no comments. Add one only when the *why* is non-obvious.
