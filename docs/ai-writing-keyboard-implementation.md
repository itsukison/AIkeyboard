# AI Writing Keyboard Implementation Plan

Date: 2026-06-06

Status: implement after the pure Japanese keyboard reaches a stable v1 keyboard surface.

This document turns `ai-writing-keyboard-research.md` into an implementation plan for the reference UX:

- normal Japanese keyboard by default
- AI button at the left side of the candidate bar
- command strip when AI is opened
- result card inside the keyboard
- Replace rewrites the whole current input text, not a selected subsection

## Product Decision

For v1, copy the reference app's simpler behavior:

- AI rewrite targets the whole available input text.
- Users do not choose/highlight a subsection inside the keyboard UI.
- If the cursor is in the middle of the text, Replace moves the cursor to the end of the captured input, deletes the captured input, then inserts the rewrite.
- If the keyboard cannot confidently capture the full available input text, AI actions are disabled or show a short "cursor to end" state.

This is easier to explain, easier to test, and closer to the screenshots. It also avoids the hardest part of keyboard extensions: arbitrary host text selection.

## iOS API Model

The keyboard extension talks to the active host text input through `UITextDocumentProxy`.

We will use:

- `documentContextBeforeInput`
- `documentContextAfterInput`
- `selectedText`, only to include any current selection in the full capture
- `documentIdentifier`, when available, to detect document changes
- `adjustTextPosition(byCharacterOffset:)`
- `deleteBackward()`
- `insertText(_:)`
- text input traits for gating: secure contexts, return key type, keyboard type, content type

We will not depend on:

- direct access to `UITextField` or `UITextView`
- host app view hierarchy
- screen OCR
- arbitrary text selection APIs
- system Writing Tools invocation inside another app

## UX Overview

### Normal Mode

The pure Japanese keyboard remains visually unchanged except for one AI entry point.

Candidate bar:

```text
[AI icon]  候補1   候補2   候補3   ...
```

Rules:

- AI button sits at the far left of the candidate bar.
- It has the same height as candidate cells.
- Use a magic-wand/sparkle style icon, not a text-heavy button.
- When there is no capturable text and no active composition, the AI icon is disabled with reduced opacity.
- Tapping normal Japanese candidates still behaves exactly as before.

### AI Command Strip

When the AI icon is tapped, the candidate bar becomes a command strip.

```text
[AI selected] [校正] [自然に] [丁寧に] [短く] [英訳] [日訳] [x]
```

Rules:

- Keep the key grid below unchanged.
- Do not resize the keyboard.
- Do not show explanatory copy in the keyboard.
- Command cells are horizontally scrollable if width is tight.
- Close returns to the normal candidate bar.

Recommended v1 commands:

- `校正`: minimal grammar/spelling correction
- `自然に`: natural Japanese rewrite
- `丁寧に`: polite/business tone
- `短く`: concise rewrite
- `英訳`: translate to English
- `日訳`: translate to Japanese

### Generating State

After tapping a command:

```text
[AI selected] [校正 ...] [自然に disabled] [丁寧に disabled] ... [x]
```

Rules:

- Freeze the captured input text immediately.
- Show a small spinner or shimmer in the tapped command.
- Keep the keyboard height stable.
- Cancel the request if the user closes AI mode, switches document, dismisses keyboard, or taps another command.
- If the user keeps typing while generation runs, keep the result but validate before Replace.

### Result Card

The result appears in the keyboard area like the reference screenshot.

```text
┌──────────────────────────────────────┐
│ 校正候補                              │
│                                      │
│ This is very cool.                   │
│                                      │
└──────────────────────────────────────┘

[copy] [bad]                         [Replace]
```

Rules:

- Result card appears above the key rows or temporarily replaces the top part of the keyboard area.
- The visual weight should match iOS keyboard chrome: light blurred/gray background, rounded card, restrained shadow.
- Primary button is `Replace`.
- For Japanese UI, label the primary button `置き換え`; for English mode, `Replace`.
- Highlight changed spans later if local diff is reliable. Do not block v1 on diff highlighting.
- Close returns to the command strip.

### After Replace

Rules:

- Move cursor to the end of the captured input if needed.
- Delete the original full captured input.
- Insert the rewritten text.
- Clear the AI result card.
- Return to normal candidate bar.
- Refresh Japanese suggestions from the new context.

## Implementation Modules

Add these after the pure Japanese keyboard exists.

```text
Japanese/
  iOS/KeyboardExtension/
    AI/
      AIKeyboardState.swift
      AIKeyboardController.swift
      AICommandBarView.swift
      AIResultCardView.swift
      InputCapture.swift
      WholeInputReplacementEngine.swift
      RewriteService.swift
      CloudRewriteService.swift
      FoundationModelsRewriteService.swift
      RewriteModels.swift
```

### `AIKeyboardState.swift`

Owns UI mode only.

```swift
enum AIKeyboardState: Equatable {
    case hidden
    case commandStrip
    case generating(command: RewriteCommand, capture: WholeInputCapture)
    case result(command: RewriteCommand, capture: WholeInputCapture, result: RewriteResult)
    case error(command: RewriteCommand?, message: String)
}
```

### `RewriteModels.swift`

Shared models for capture, backend, and UI.

```swift
enum RewriteCommand: String, Codable, CaseIterable {
    case proofread
    case natural
    case polite
    case concise
    case translateToEnglish
    case translateToJapanese
}

struct WholeInputCapture: Equatable, Codable {
    let beforeCursor: String
    let selectedText: String
    let afterCursor: String
    let targetText: String
    let moveToEndCharacterCount: Int
    let deleteBackwardCharacterCount: Int
    let documentIdentifierString: String?
    let capturedAt: Date
}

struct RewriteRequest: Codable {
    let command: RewriteCommand
    let text: String
    let locale: String
    let appVersion: String
}

struct RewriteResult: Codable, Equatable {
    let replacement: String
    let language: String
    let changed: Bool
}
```

Note: if `documentIdentifier` is not directly codable, convert it to `String(describing:)` for validation/logging only.

### `InputCapture.swift`

Reads the proxy and returns whole-input capture.

Algorithm:

1. Read `before = proxy.documentContextBeforeInput ?? ""`.
2. Read `selected = proxy.selectedText ?? ""`.
3. Read `after = proxy.documentContextAfterInput ?? ""`.
4. Build `target = before + selected + after`.
5. Reject if `target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`.
6. Reject if `target` exceeds configured length, probably 2,000-4,000 characters for v1.
7. Set `moveToEndCharacterCount = after.count`.
8. Set `deleteBackwardCharacterCount = target.count`.
9. Store `documentIdentifier`.

Important:

- For v1, use Swift `Character` counts consistently. Later, add tests for composed characters.
- Treat this as "full available input", not guaranteed full document.
- If a host app gives only partial context, we rewrite only what the proxy provides. The UI should avoid saying "entire document".

### `WholeInputReplacementEngine.swift`

Applies replacement through the proxy.

Algorithm:

```swift
func replace(capture: WholeInputCapture, with replacement: String, proxy: UITextDocumentProxy) throws {
    let currentBefore = proxy.documentContextBeforeInput ?? ""
    let currentSelected = proxy.selectedText ?? ""
    let currentAfter = proxy.documentContextAfterInput ?? ""
    let currentTarget = currentBefore + currentSelected + currentAfter

    guard currentTarget == capture.targetText else {
        throw ReplacementError.contextChanged
    }

    if capture.moveToEndCharacterCount > 0 {
        proxy.adjustTextPosition(byCharacterOffset: capture.moveToEndCharacterCount)
    }

    for _ in 0..<capture.deleteBackwardCharacterCount {
        proxy.deleteBackward()
    }

    proxy.insertText(replacement)
}
```

Reality check:

- Some hosts may change context after cursor movement. For those, re-read after `adjustTextPosition` in a later hardening pass.
- If context changed, do not try to be clever. Show a short error and ask the user to run AI again.
- All proxy mutations should go through the same mutation manager used by the Japanese IME so expected `textDidChange` callbacks do not corrupt composition state.

### `AIKeyboardController.swift`

Coordinates capture, service calls, cancellation, and replacement.

Responsibilities:

- expose `state`
- `openCommandStrip()`
- `close()`
- `run(command:)`
- `replaceCurrentResult()`
- own one `Task<Void, Never>?`
- cancel on keyboard dismissal/document change
- choose provider: Foundation Models if available, otherwise cloud if Full Access and enabled

Provider selection:

```swift
if FoundationModelsRewriteService.isAvailable {
    service = FoundationModelsRewriteService()
} else if preferences.cloudAIEnabled && hasFullAccess {
    service = CloudRewriteService()
} else {
    state = .error(command: nil, message: "AI unavailable")
}
```

For v1 cloud-first implementation, this can temporarily be:

```swift
guard preferences.cloudAIEnabled && hasFullAccess else {
    state = .error(command: nil, message: "Full Access required")
    return
}
service = CloudRewriteService()
```

## Backend API Contract

The keyboard should call one backend endpoint:

```http
POST https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite
Content-Type: application/json
X-AI-Keyboard-Client-Token: <shared TestFlight token>
X-AI-Keyboard-Device-Id: <anonymous stable device id>
```

Request:

```json
{
  "command": "proofread",
  "text": "今日はとてもいい天気ですね",
  "locale": "ja-JP",
  "appVersion": "1.0.0"
}
```

Response:

```json
{
  "replacement": "今日はとてもいい天気ですね。",
  "language": "ja",
  "changed": true
}
```

Errors:

```json
{
  "error": {
    "code": "text_too_long",
    "message": "Text is too long."
  }
}
```

Recommended server rules:

- Max input length v1: 2,000-4,000 characters.
- Timeout: 10-12 seconds server side.
- Rate limit by user/device.
- Do not log raw text by default.
- Log only command, length bucket, latency, model, status.
- API key lives only on the backend.
- Backend response must be strict JSON.
- Do not call the legacy/reference Supabase project `wsttwofhxbcgfpwvxazj`; AIキーボード uses `eercsucvxnszqletxued`.

## OpenAI Backend Shape

Use OpenAI from the backend, not from the keyboard extension.

Recommended implementation:

- Responses API for generation.
- Structured Outputs or equivalent schema enforcement.
- A fast, capable text model selected at implementation time from current official docs.
- One prompt per command, kept short.
- Temperature low for proofread and translation; slightly higher for natural/polite rewrite only if evals show benefit.

System instruction:

```text
You are a Japanese mobile keyboard writing assistant.
Rewrite only the target text for the requested command.
Preserve meaning, names, numbers, URLs, dates, emoji, and line breaks.
Do not add explanations.
Return strict JSON matching the schema.
```

Command instruction examples:

```text
proofread: Correct grammar, spelling, punctuation, and obvious typos with minimal edits.
natural: Rewrite into natural Japanese while preserving meaning.
polite: Rewrite into polite, business-appropriate Japanese.
concise: Make the text shorter while preserving the core meaning.
translateToEnglish: Translate into natural English.
translateToJapanese: Translate into natural Japanese.
```

Schema:

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["replacement", "language", "changed"],
  "properties": {
    "replacement": { "type": "string" },
    "language": { "type": "string", "enum": ["ja", "en", "mixed"] },
    "changed": { "type": "boolean" }
  }
}
```

## Full Access UX

iOS blocks network access for third-party keyboards unless the keyboard requests Open Access and the user enables Allow Full Access.

Container app settings:

- toggle: `Cloud AI`
- status row: `Full Access: On/Off`
- explanation: "AI rewrite sends only the text you ask to rewrite. Normal typing is not sent."
- setup guide: Settings > General > Keyboard > Keyboards > AIキーボード > Allow Full Access

Keyboard behavior:

- If Full Access is off, keep normal Japanese keyboard working.
- AI command strip can open, but cloud commands show a short disabled state.
- Do not show repeated nag screens inside the keyboard.
- If Foundation Models is available, AI can run without Full Access.

## Container App Settings

Add a settings page section:

```text
AI Rewrite
  Cloud AI                 [toggle]
  Full Access              On / Off
  Default command          校正 / 自然に
  Privacy                  opens detail screen
```

Privacy detail copy:

```text
AI rewrite sends text only when you tap an AI command.
The keyboard does not send every keystroke.
Normal Japanese input works without Cloud AI.
Cloud AI requires Allow Full Access because iOS blocks keyboard network access without it.
```

## Testing Matrix

Host apps:

- Notes
- Messages
- Safari search field
- Safari web textarea
- Mail
- LINE
- Slack
- Google Docs, if context is usable

Text cases:

- cursor at end of one sentence
- cursor in middle of one sentence
- cursor in middle of multi-sentence paragraph
- selected text exists
- Japanese
- English
- mixed Japanese/English
- emoji
- dakuten/handakuten composed characters
- URLs
- dates
- line breaks
- very long input
- context changes while generation is running

Expected v1 behavior:

- The whole available input is replaced, not a subsection.
- Cursor-in-middle replacement moves to the end, deletes the full captured text, inserts rewrite.
- If context changed, Replace refuses and asks user to run again.

## What I Need From You For Cloud AI

To implement the cloud API path, I need these decisions/assets from you:

1. Backend host choice

   Recommended for fastest implementation: Supabase Edge Function if you already want Supabase auth/storage later, or Vercel/Cloudflare if you prefer a standalone API.

   I need one concrete choice.

2. OpenAI project/API key

   Create the OpenAI API key in your OpenAI project. Do not put it in the iOS app and do not commit it.

   Give it to me only as a local backend secret, for example:

   ```text
   OPENAI_API_KEY=...
   ```

   If we use Supabase, set it as a Supabase secret. If we use Vercel/Cloudflare, set it in that platform's encrypted environment variables.

3. Auth decision

   Choose one for v1:

   - no login, anonymous device token, rate limited
   - app login required
   - TestFlight-only shared test token

   Recommended first: TestFlight-only shared test token for early development, then real auth before public release.

4. Billing/rate limits

   Tell me the initial budget/rate limits:

   - max requests per device per day
   - max characters per request
   - whether AI is free, paid, or internal test only

   Recommended first:

   - 50 requests/device/day
   - 2,000 characters/request
   - internal/TestFlight only

5. Privacy policy wording

   Confirm the product promise:

   - normal typing is not sent
   - text is sent only when user taps an AI command
   - raw text is not logged by our backend by default
   - provider processing follows provider/API terms

6. Apple keyboard setting

   Confirm that the AI build may set `RequestsOpenAccess = true`.

   Without this, cloud AI cannot run from the keyboard extension. The normal keyboard can still work without Full Access.

7. Endpoint/domain

   If you already have a production API domain, tell me it.

   If not, I will create a dev endpoint first and keep the iOS client endpoint configurable through build settings.

## Implementation Order After Pure Keyboard

1. Add AI button and command strip with fake local rewrite.
2. Implement whole-input capture and replacement.
3. Test replacement in host apps before adding real AI.
4. Add result card microinteractions.
5. Add cloud backend endpoint.
6. Add iOS `CloudRewriteService`.
7. Add Full Access and privacy settings.
8. Add Foundation Models as optional on-device provider after cloud path is stable.
9. Run quality evals and host-app replacement tests.

## Final Recommendation

For v1, implement the reference behavior exactly:

- whole available input rewrite
- cloud backend as the first real AI provider
- no API key in the app
- Full Access required only for AI
- Foundation Models later as a privacy-friendly local enhancement

This gives us the UX in the screenshots without blocking on Apple Intelligence availability or overcomplicating span selection.
