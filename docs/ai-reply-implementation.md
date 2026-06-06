# AI Reply Implementation Plan (LINE / Slack, v1)

Status: planning
Targets: LINE (text copy) and Slack (message link copy)
Priority: lowest possible friction
Non-goals (v1): screenshot OCR, X DM, Instagram DM, WhatsApp, thread re-summarization, multi-turn refine

---

## 1. Feature in one paragraph

When the user copies a message in LINE (text) or a message link in Slack and then opens the AI keyboard in the reply field, a "返信案 →" pill appears in the candidate bar. Tapping it opens a tone strip (`丁寧 / カジュアル / 短く / 確認質問`). Backend returns 2–3 reply candidates. Tapping a candidate inserts it into the field. For Slack, the message content is resolved server-side via the Slack Web API using the URL on the pasteboard — the keyboard never reads pasteboard strings, so no "pasted from …" banner appears. For LINE, the keyboard reads the pasteboard string only after the user explicitly taps the pill — exactly one banner per use.

## 2. Architectural constraints (from `keyboard/CLAUDE.md` and Apple)

- Keyboard memory ceiling ~40 MB peak (Jetsam at 30–60 MB).
- App Group `group.co.gastroduce-japan.bikey.japanese` is the only IPC channel between container and keyboard.
- Network from the extension is only allowed when the user has granted Full Access (already required for existing Cloud rewrite).
- Slack OAuth tokens must never live inside the keyboard extension. Backend mediates all Slack API calls.
- Pasteboard reads of `.string` / `.url` show the iOS "pasted from" banner; `changeCount`, `hasStrings`, `detectPatterns`, `detectValues(for:)` do not.

## 3. End-to-end flow

### 3.1 Slack happy path (bannerless)

```
User in Slack iOS app:
  1. long-press message → "リンクをコピー"           (2 taps)
  2. tap reply input in same channel                  (1 tap)
  3. open AI keyboard                                  (0 taps — already default)

Keyboard, on viewDidAppear:
  - reads UIPasteboard.changeCount (no banner)
  - if changed since last seen:
      detectValues(for: [.URL])   // no banner, returns URL
      if host matches *.slack.com and path matches /archives/<C…>/p<ts>:
          parse channel + ts
          show "💬 Slackメッセージへの返信案 →" pill in candidate bar
          do NOT touch pasteboard.string

User taps pill:
  → keyboard POSTs { channel, ts } to /functions/v1/keyboard-reply
  → backend uses user's Slack OAuth token to fetch the message + last 3 turns
  → backend asks OpenAI for 3 reply candidates with chosen tone
  → keyboard renders candidates above keyboard surface
  → user taps a candidate → insertText into reply field
```

Total: 5 user actions, **0 banners**.

### 3.2 LINE happy path (one banner)

```
User in LINE iOS app:
  1. long-press message → "コピー"                    (2 taps)
  2. tap reply input                                  (1 tap)
  3. open AI keyboard

Keyboard, on viewDidAppear:
  - reads UIPasteboard.changeCount (no banner)
  - changed AND hasStrings == true (no banner)
  - URL detect fails (no .slack.com match)
  - show "📋 コピーしたメッセージで返信案 →" pill
  - do NOT touch pasteboard.string yet

User taps pill:
  → keyboard reads pasteboard.string (banner shows once: "AIキーボード pasted from LINE")
  → POST { text, tone } to /functions/v1/keyboard-reply
  → backend asks OpenAI for 3 reply candidates
  → user taps a candidate → insertText
```

Total: 5 user actions, **1 banner** (explicit, gated by user tap).

### 3.3 Dedupe / TTL rules

- Persist `lastSeenChangeCount` in App Group; only re-trigger when it increases.
- Persist `dismissedChangeCount` so the pill doesn't re-appear if user dismisses it.
- Drop detected context after 60 seconds wall-clock to avoid stale offers when the user opens the keyboard in an unrelated app later.

## 4. Module layout

### 4.1 New files

| Path | Purpose |
|---|---|
| `Sources/KeyboardPreferences/ReplyContext.swift` | `ReplyContext` model + App Group read/write |
| `Sources/KeyboardPreferences/SlackLinkParser.swift` | Parse Slack permalink → `(workspace, channel, ts, threadTs?)` |
| `iOS/KeyboardExtension/AI/Reply/PasteboardSnoop.swift` | Bannerless detection (`changeCount`, `detectValues`) |
| `iOS/KeyboardExtension/AI/Reply/ReplyDetector.swift` | Combines snoop + parser → emits `DetectedReplySource` |
| `iOS/KeyboardExtension/AI/Reply/CloudReplyService.swift` | HTTP client for `keyboard-reply` |
| `Sources/JapaneseKeyboardUI/AI/ReplyPillView.swift` | "返信案 →" pill in candidate bar |
| `Sources/JapaneseKeyboardUI/AI/ReplyToneStripView.swift` | Tone selector strip |
| `Sources/JapaneseKeyboardUI/AI/ReplyCandidatesView.swift` | Result overlay with 3 candidates + tap-to-insert |
| `Sources/JapaneseKeyboardUI/AI/ReplyModels.swift` | `ReplyTone`, `ReplyRequest`, `ReplyResult`, `ReplyCandidate` |
| `iOS/Container/Slack/SlackConnectScreen.swift` | OAuth start UI |
| `iOS/Container/Slack/SlackConnectionStore.swift` | Connection status read |
| `supabase/functions/keyboard-reply/index.ts` | Generation endpoint (handles both raw text and slack link) |
| `supabase/functions/slack-oauth-start/index.ts` | Initiates OAuth, returns redirect URL |
| `supabase/functions/slack-oauth-callback/index.ts` | Receives Slack callback, stores token |

### 4.2 Modified files

| Path | Change |
|---|---|
| `Sources/JapaneseKeyboardUI/Common/CandidateBar.swift` | Render reply pill as first item when context exists and `isComposing == false` |
| `iOS/KeyboardExtension/AI/AIKeyboardState.swift` | Add `.replyDetected / .replyToneStrip / .replyGenerating / .replyResult` cases |
| `iOS/KeyboardExtension/AI/AIKeyboardController.swift` | Reply-mode state transitions, distinct from rewrite |
| `iOS/KeyboardExtension/AI/AIKeyboardToolbarView.swift` | Toolbar branches on reply states |
| `iOS/KeyboardExtension/KeyboardViewController.swift` | Trigger `ReplyDetector` from `viewDidAppear` + `textDidChange` |
| `Sources/KeyboardPreferences/Preferences.swift` | Add keys: `slackConnected`, `replyAssistEnabledKey`, `lastSeenPasteboardChangeCount`, `dismissedPasteboardChangeCount` |
| `iOS/Container/HomeScreen.swift` | Entry for Slack 連携 / 返信アシスト settings |

## 5. Data shapes

### 5.1 Swift

```swift
// Sources/JapaneseKeyboardUI/AI/ReplyModels.swift
public enum ReplyTone: String, Codable, CaseIterable, Sendable {
    case polite          // 丁寧
    case casual          // カジュアル
    case concise         // 短く
    case clarifying      // 確認質問
}

public enum ReplySource: Equatable, Sendable {
    case slackLink(workspace: String, channel: String, ts: String, threadTs: String?)
    case rawText(String)   // from LINE copy
}

public struct ReplyRequest: Codable, Sendable {
    public let source: ReplySourcePayload   // tagged union over the wire
    public let tone: ReplyTone
    public let locale: String
    public let appVersion: String
}

public struct ReplyCandidate: Codable, Equatable, Sendable {
    public let id: String
    public let text: String
}

public struct ReplyResult: Codable, Equatable, Sendable {
    public let candidates: [ReplyCandidate]   // 2–3 items
    public let detectedLanguage: String       // "ja" / "en" / "mixed"
}
```

### 5.2 App Group keys

| Key | Type | Owner |
|---|---|---|
| `replyAssistEnabled` | Bool (default true) | Container settings UI |
| `slackConnected` | Bool | Container after OAuth callback succeeds |
| `lastSeenPasteboardChangeCount` | Int | Keyboard |
| `dismissedPasteboardChangeCount` | Int | Keyboard |

### 5.3 Backend (Slack)

A new table `slack_connections` in Supabase:

```
slack_connections
  device_id            text (anonymous device id from existing flow)
  slack_user_id        text
  slack_team_id        text
  access_token         text   (encrypted with Supabase Vault)
  scopes               text[]
  created_at           timestamptz
  refreshed_at         timestamptz
```

We bind connections to the anonymous device id already established for the rewrite endpoint, not to a user account, because the keyboard has no notion of user accounts. The device id is sent on every reply call via `X-AI-Keyboard-Device-Id`.

## 6. Backend design

### 6.1 `keyboard-reply` Edge Function

- Auth: same `X-AI-Keyboard-Client-Token` header pattern as `keyboard-rewrite`.
- Daily quota: reuse the in-memory `consumeDailyQuota` pattern (lift the existing limitation note — same cut as current `keyboard-rewrite`).
- Branches on `source.kind`:
  - `slackLink`: look up `slack_connections.access_token` for the device id, call `conversations.history` with `latest=ts, inclusive=true, limit=1`, then `conversations.replies` if `threadTs != null` (last 3 turns). Concatenate into context block.
  - `rawText`: use the text directly.
- Prompt to OpenAI: same `gpt-5.1` / Responses API call shape as `keyboard-rewrite`. New instructions tailored to reply generation. JSON schema returns array of 2–3 candidates.
- If `slackLink` but `slack_connections` row missing: return `error.code = "slack_not_connected"`. Keyboard surfaces "Slack連携が必要" with a deeplink to container's Slack screen.

### 6.2 `slack-oauth-start` + `slack-oauth-callback`

Standard Slack OAuth v2 with `https://slack.com/oauth/v2/authorize` and these user scopes:

```
channels:history
groups:history
im:history
mpim:history
users:read         (just to label which workspace the connection is for in container UI)
```

Bot scopes: **none** — this is a user-token-only integration so the app doesn't appear in any workspace and doesn't post anything.

`slack-oauth-callback` receives the redirect, exchanges code for token, encrypts via Supabase Vault, upserts on `device_id`.

### 6.3 Prompt (reply)

```
System:
- You are a Japanese reply assistant inside a mobile keyboard.
- Given the OPPONENT'S message (and optional thread context), produce 2–3 reply candidates in the requested tone.
- Preserve names, numbers, URLs, dates, emoji.
- Match opponent's language unless tone implies otherwise (clarifying = same language).
- No greetings, no commentary, no quotes around the reply.
- Each candidate must be self-contained and ready to send.

User:
Tone: <tone instruction in English>
Locale: ja-JP

Opponent message (and optional context):
<message block, with role markers if thread>

Generate 2–3 candidates, varying length and phrasing.
Return JSON: { candidates: [{ id, text }], detectedLanguage }
```

Tone instructions:
- `polite` → "Business-polite Japanese (丁寧語/敬語 where appropriate)."
- `casual` → "Casual Japanese (ため口) friendly tone."
- `concise` → "Shortest natural reply that still answers."
- `clarifying` → "Ask one clarifying question to move the conversation forward."

## 7. State machine extension

```
AIKeyboardState
├── existing: hidden / commandStrip / generating / result / error  (rewrite flow)
└── new:
    ├── replyDetected(source: ReplySource, preview: String)
    ├── replyToneStrip(source: ReplySource)
    ├── replyGenerating(source: ReplySource, tone: ReplyTone)
    ├── replyResult(candidates: [ReplyCandidate])
    └── replyError(message: String, retry: ReplyTone?)
```

Transitions:
- `hidden + detector finds context` → `replyDetected`
- `replyDetected + pill tap` → if rawText with no string yet → read pasteboard.string (banner) → `replyToneStrip`; if slackLink → `replyToneStrip` directly
- `replyToneStrip + tone tap` → `replyGenerating`
- `replyGenerating + response` → `replyResult`
- `replyResult + candidate tap` → `proxy.insertText` → `hidden`
- `* + close / textDidChange to unrelated doc` → `hidden`
- `replyError` allows retry of same tone

User typing kana **dismisses** the pill (composing == true). Resuming an empty field within 60s restores the same pill once.

## 8. UI specs

### 8.1 Reply pill

- Rendered as the leftmost item inside `CandidateBar` when `aiController.state == .replyDetected(...)` and `inputManager.isComposing == false`.
- Visual: capsule, system blue tint at 12% opacity, icon `bubble.left.and.bubble.right` + label.
  - Slack: "💬 返信案 →" (the SF Symbol is the bubble icon, not a literal emoji in production)
  - Raw text: "📋 返信案 →"
- Tap target ≥ 44pt height. Right-edge close button hides pill until next changeCount.

### 8.2 Tone strip

Reuses the existing `commandStrip` layout from `AIKeyboardToolbarView`. Four buttons: `丁寧 / カジュアル / 短く / 確認質問`. Close button on the right.

### 8.3 Reply candidates overlay

Reuses the `AIResultOverlayView` surface. Difference: shows a vertical stack of 2–3 candidate cards (not a single replacement). Tap a card → `proxy.insertText(candidate.text)` and close. No "置き換え" button — replies are inserts.

If the input field already contains user-typed text (rare; user typed something then realised they want help), inserting appends. We do not delete existing user text in reply mode — it isn't ours.

## 9. Privacy & permissions

- Reply assist is gated by `replyAssistEnabledKey` (default ON, but visible toggle).
- Reply assist requires Cloud AI enabled (same gate as existing rewrite).
- Reply assist requires Full Access (same gate as existing rewrite, because network).
- Slack feature additionally requires Slack OAuth connection.
- Disclosure copy in onboarding and settings:
  > AIキーボードは入力欄やクリップボードを自動では読みません。コピーした内容で返信案を作るかは、あなたが返信ピルをタップしたときだけ判断します。Slackの場合はURLだけを使うので、クリップボードの内容は読み取りません。
- Container Privacy screen lists what data is sent to backend and what is stored on Supabase (Slack token only, on connect; reply text on each call, not persisted).

## 10. Phases & ordering

Each phase is independently verifiable.

### Phase 0 — Spike (1–2 days)

- Throwaway iOS sample (or new file in this repo, removed before merging) that calls `UIPasteboard.detectValues(for: [.URL])` on iOS 16, 17, 18 and confirms NO banner appears.
- Confirm Slack permalink format on current iOS Slack client (long-press → "Copy link").
- Confirm LINE copy text format (does it include sender name / timestamp prefix?).
- Decision gate: if `detectValues` does show a banner on any tested version, fall back to "any fresh changeCount + URL pattern via `hasStrings`" + read string once per session.

### Phase 1 — Models & settings (0.5 day)

- Add `ReplyModels.swift`, `ReplyContext.swift`, `SlackLinkParser.swift` (with unit tests in `Tests/`).
- Add settings keys in `Preferences.swift`.

Verify: package tests pass.

### Phase 2 — Pasteboard snoop & detector (1 day)

- `PasteboardSnoop` exposes `currentChangeCount()`, `hasStrings()`, `detectURL() async -> URL?`.
- `ReplyDetector.detect() async -> DetectedReplySource?` combines snoop + parser + TTL + dedupe.
- Unit tests with injected `PasteboardSnoop` protocol (so we can simulate without UIKit in tests).

Verify: on a real device, opening the keyboard after copying a Slack link surfaces a debug log, and no banner appears. Opening after copying LINE text logs `rawText` with no banner.

### Phase 3 — UI: pill, tone strip, candidates (1.5 days)

- `ReplyPillView`, `ReplyToneStripView`, `ReplyCandidatesView`.
- Extend `AIKeyboardState` + `AIKeyboardController` reply branches.
- Mock `CloudReplyService` returning fixed candidates.

Verify on simulator with mock: full UI flow works, candidate tap inserts text into a `UITextView` test host.

### Phase 4 — Backend: `keyboard-reply` for raw text only (1 day)

- New Supabase function. Same auth pattern as `keyboard-rewrite`. Only handles `source.kind = rawText`.
- Wire `CloudReplyService` to it.

Verify: LINE path works end-to-end on device with real OpenAI calls. Measure latency budget (should match rewrite: ~1–2 s).

### Phase 5 — Slack OAuth (2 days)

- `slack-oauth-start` and `slack-oauth-callback` functions.
- `slack_connections` table + Vault-encrypted token column.
- Container `SlackConnectScreen` with `ASWebAuthenticationSession`.
- Connection status pushed into App Group `slackConnected` boolean.

Verify: OAuth round-trip completes, token stored, settings screen shows "接続済み (workspace name)". Token never leaves backend.

### Phase 6 — Backend: Slack branch in `keyboard-reply` (1 day)

- Add `slackLink` handling: fetch via `conversations.history`/`replies`, build context block.
- Add `slack_not_connected` error code.

Verify: Slack path works end-to-end on device. Banner does not appear.

### Phase 7 — Edge cases & hardening (1 day)

- 60s TTL on detected context.
- Dismiss-by-close-button persistence (`dismissedPasteboardChangeCount`).
- "Already composing → hide pill" wiring.
- Memory profile in Instruments: extension peak ≤ 40 MB while pill + tone strip + candidates are all rendered.
- Network failure / timeout copy.

### Phase 8 — Settings & disclosure (0.5 day)

- Settings toggle for reply assist.
- Slack 連携 row in HomeScreen / settings.
- Onboarding pass mentions reply assist.

### Phase 9 — Test matrix & ship (1 day)

| Case | LINE | Slack |
|---|---|---|
| Cloud AI off | hidden | hidden |
| Full Access off | hidden | hidden |
| Slack not connected | works | shows "Slack連携が必要" |
| Pasteboard empty | hidden | hidden |
| Pasteboard non-message URL | hidden | hidden (not a slack.com link) |
| Pasteboard 5 min old | hidden (TTL) | hidden (TTL) |
| Pasteboard fresh, dismissed once | hidden until next change | hidden until next change |
| iOS 16 / 17 / 18 | passes | passes |

Total estimate: **~9–10 engineering days**. Slack OAuth review (Phase 5) can run in parallel with Phases 6–8.

## 11. Open questions / decisions to make before Phase 4

1. **Reply candidate count**: 2 or 3? UI fits 3 cleanly given keyboard height; 2 is faster to generate. Plan: 3, but allow backend to return 2 if model declines.
2. **Default tone**: should the tone strip have a pre-selected default that auto-generates without a tap? Lower friction but removes intent signal. Plan: no auto-gen — explicit tone tap is the user's "I want help" signal.
3. **LINE sender name / timestamp prefix stripping**: LINE includes context lines on copy depending on Chat type. Decide stripping rules in Phase 0.
4. **Quota**: reply calls share rewrite quota or have their own? Plan: share — single daily limit per device.
5. **Foundation Models**: out of scope for v1 (matches existing roadmap).

## 12. Critical risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `detectValues(for: [.URL])` triggers banner on some iOS | medium | Phase 0 spike; fallback plan documented in §10 |
| Slack OAuth app approval delay | medium | Submit app early; pilot internally with dev workspace |
| Slack permalink format changes | low | Parser unit tests; fall back to rawText if parse fails |
| LINE copy format inconsistency | medium | Phase 0 documents observed formats; backend tolerates them |
| Extension memory pressure from new UI | low | All heavy work (HTTP, JSON parse) is async + small payloads; no images |
| User accidentally inserts AI reply into wrong field | low | Reply state cleared on `textDidChange` to a different document identifier |

## 13. What we are deliberately not building (v1)

- Screenshot + share extension + OCR path — defer to v2 once we know reply quality is right.
- Multi-turn refinement ("もう少し丁寧に") — defer.
- Slack thread auto-summary across long threads — fetch only last ~3 turns in v1.
- LINE Official Account / WhatsApp / X DM — defer.
- Inline preview of opponent's message inside the keyboard — pill label is enough in v1, avoids extra rendering.
- Reply translation modes — `英訳`/`日訳` already exist in rewrite for the user's own draft.
