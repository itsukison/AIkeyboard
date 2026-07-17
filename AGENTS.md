# AGENTS.md

**Read this file first.** It is the single source of truth for any agent or new
engineer joining this codebase. Everything else under `docs/` is reference
material that this file points to.

Last verified against the code: 2026-06-08.

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

Internal name: `KeigoButton` (Xcode project + scheme; the older `BikeyJP` name
survives only in stray docs). User-facing name is `AIキーボード`.

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
  `group.com.core7.keigobutton`. No URL schemes (except the
  `aikeyboard://settings` deeplink from the keyboard to the container) and
  no shared keychain in v1.
- **Keyboard surface looks native, container looks Bikey**. Do not put purple
  / Liquid Glass / Bikey design tokens on the keyboard. Do not put the iOS
  system-keyboard look on the container.
- **Japanese is the default; other languages are opt-in parallel modes.** The
  keyboard ships Japanese and every existing user stays on it. A user may
  explicitly select a different keyboard language (English first; Simplified
  Chinese planned) during onboarding or in settings. The rule that replaced the
  old "pure Japanese, no bilingual logic" constraint: **a non-Japanese mode must
  never alter the Japanese input path.** Each language is a separate branch
  reached only when `KeyboardLanguage` is set to it; when it is `.japanese`
  (the default), the code runs exactly as before. No mixed JA/EN logic inside a
  single mode, no language auto-detection — the active mode is an explicit user
  choice stored in the App Group.

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
│   ├── Container/                    ← main app target (KeigoButton)
│   │   └── Design/                   ← Bikey Design System (container-only)
│   ├── KeyboardExtension/            ← UIInputViewController + UIKit glue
│   │   └── AI/                       ← AIKeyboardController, toolbar view, proxy adapter
│   └── Shared/                       ← types used by both targets
├── Tests/                            ← swift test
├── supabase/
│   └── functions/keyboard-rewrite/   ← Edge Function (Deno + AI providers)
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
   validates the JWT, enforces abuse-oriented usage limits, calls Cerebras
   Chat Completions (`gpt-oss-120b` by default, Groq fallback optional) with
   `response_format = json_schema` (strict), and returns
   `{ candidates, language }`.
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
3. On each change, `InputManager` schedules an async conversion through
   `KanaKanjiAdapter` (wraps AzooKey's converter). There is no debounce:
   the kana preview is already on screen, the converter extends its
   lattice incrementally, and the actor serializes requests, so eager
   conversion trades a few ms off-main for one-for-one candidate latency.
   Once the user starts cycling candidates (space → 次候補), the published
   `candidates` array is frozen so a late-landing result can't rebuild the
   rows and cancel an in-flight tap.
4. Candidates come back, are re-ranked by per-user learning data
   (`ConversionPreferenceStore`), and exposed as `@Published candidates`.
5. The marked-text preview is pushed to `UITextDocumentProxy` via the
   `onMarkedTextDidChange` callback wired in `KeyboardViewController`.
6. Space cycles candidates (`selectNextCandidate`); return commits
   (`commitComposingForReturn`); tapping a candidate in `CandidateBar`
   commits directly. Backspace first cancels candidate selection, then
   shrinks the buffer.

### Zenzai (neural conversion)

Since 1.0.9 the converter runs Zenzai (zenz-v3.1-xsmall GGUF, llama.cpp CPU)
inside the extension. Key facts:

- The converter dependency is our fork
  `itsukison/AzooKeyKanaKanjiConverter` (trait `ZenzaiCPU`), whose
  `llama.xcframework` is Metal-free — upstream's binary has Metal compiled in
  and **aborts at model load inside keyboard extensions**. See the fork's
  `BUILDING.md` before touching this.
- The weight `Sources/JapaneseKeyboardCore/Resources/zenz-xsmall.gguf` is
  committed (gitignore exception). If it's missing, conversion silently falls
  back to classical — check the DEBUG `📕 ZENZAI` log in `prewarmZenzai()`.
- Launch is classical-only: `prewarm()` loads just the dictionary; the zenz
  weight + first decode are deferred to `prewarmZenzai()`, fired from
  `viewDidAppear` so the model load never competes with the first frame.
- One converter per process (`SharedConversionEngine` in
  `KeyboardViewController.swift`): iOS leaks input view controllers, and a
  per-controller llama context stacks dirty memory until jetsam kills the
  keyboard mid-launch. Never build a second `KanaKanjiAdapter` in the
  extension.
- Two gates, both in front of `zenzaiMode: .on`: the user toggle
  (`KeyboardSettingsStore.readZenzaiEnabled`, default true, ProfileScreen
  「高精度変換」) and the jetsam-headroom check
  (`os_proc_available_memory() > 50 MB`) in `KanaKanjiAdapter`.

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
| `docs/privacy.md` | Privacy promise, App Store nutrition label, auditing checks |
| `docs/development.md` | Build, test, simulator setup, common gotchas, memory profiling, CI |
| `docs/archive/` | Historical plans — do not treat as current truth |

Read in that order if you are new. If a fact in any doc contradicts the
code, the code wins — fix the doc.

---

## 7. Commands you'll actually run

```bash
# generate Xcode project (after editing project.yml or moving files)
xcodegen generate

# open in Xcode
open KeigoButton.xcodeproj

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

- Enable DB-backed AI usage guard in production (`USAGE_GUARD_MODE=db`;
  migration already exists under `supabase/migrations/`).
- Schedule retention jobs (`delete_ai_rewrite_events_older_than(30)`,
  `delete_old_ai_rewrite_usage_buckets(48, 35)`) via `pg_cron`.
- Add a feedback endpoint to record `selected_index` into `ai_rewrite_events`
  (the keyboard already knows the selected candidate; it just doesn't POST
  it back yet).
- Environment-specific Supabase URL + publishable key (currently hard-
  coded as defaults in `CloudRewriteConfiguration`). Should read from
  Info.plist via xcconfig so dev/staging/prod can diverge.
- Real-device memory profile run: confirm < 40 MB peak with the AI
  overlay rendered. Checklist in `docs/development.md` §Memory profiling.
- Submit the App Store privacy nutrition label per `docs/privacy.md`.
- Structured-log export to Sentry / Logflare for the Edge Function
  (currently console-log only).

---

## 9. House rules

From `CLAUDE.md`:

- Surgical changes only. Don't refactor adjacent code you didn't touch.
- No speculative abstractions, no flexibility that wasn't requested, no
  error handling for impossible cases.
- Match existing style even if you'd do it differently.
- Keep the profile/settings main page compact. Keyboard-specific controls
  belong in the keyboard detail settings page, not as extra top-level profile
  rows.
- Ask before destructive operations (deletes, force-pushes, dropping
  dependencies). The `fix/` scratch directory and
  `supabase/functions/_deprecated/` rollback folder are untracked — leave
  them alone unless the user asks for cleanup.
- Default to no comments. Add one only when the *why* is non-obvious.
