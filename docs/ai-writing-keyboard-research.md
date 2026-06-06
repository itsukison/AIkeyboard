# AI Writing Keyboard Research

Date: 2026-06-06

Scope: AI rewrite/proofread UX for the Japanese keyboard extension. The target interaction is the reference UX in the screenshots: an AI button at the left edge of the suggestion bar, a compact command strip when opened, a generated suggestion card, and a Replace action that rewrites the active host text.

## Executive Summary

Build the UX as a keyboard-native AI mode, not as a separate app flow:

1. Keep the normal Japanese keyboard visually unchanged by default.
2. Add a single AI button at the left of the candidate/suggestion bar.
3. On tap, swap the suggestion bar into an AI command strip: "校正", "自然に", "丁寧に", "短く", "英訳", "日訳", plus close.
4. On command tap, capture the whole available input text through `UITextDocumentProxy`, send only that explicit user-triggered text to the rewrite engine, and show a result card inside the keyboard area.
5. On Replace, replace the captured input through `UITextDocumentProxy` by cursor movement, `deleteBackward()`, and `insertText(_:)`.

The main constraint: a third-party keyboard cannot directly "detect the input box" as a text-field object. It can only talk to the active text input through `textDocumentProxy`. That proxy can provide context before/after the cursor, selected text, input traits, insertion, deletion, and cursor movement. It does not expose arbitrary host UI, full document bounds, or text selection controls.

Recommendation: use a hybrid AI engine.

- First choice when available: Apple's Foundation Models framework for simple on-device proofread/rewrite. It is private, offline, and has no per-request API cost, but requires iOS 26+, Apple Intelligence-capable hardware, Apple Intelligence enabled, model availability, and supported locale.
- Fallback / premium path: backend-proxied cloud LLM API. This gives better quality and broader device support, but requires keyboard Full Access for network calls and much stronger privacy disclosure.
- Do not rely on system Writing Tools as the keyboard feature. Writing Tools are automatically available in standard text views inside apps that support them; they are not a general "call Writing Tools on any host app text from my keyboard" API.

## Source Notes

Apple custom keyboard and text proxy:

- `UIInputViewController.textDocumentProxy` is the keyboard extension's proxy to the current host text input. It provides insertion, deletion, textual context, and input traits: https://developer.apple.com/documentation/uikit/uiinputviewcontroller/textdocumentproxy
- `UITextDocumentProxy` exposes `documentContextBeforeInput`, `documentContextAfterInput`, `selectedText`, `adjustTextPosition(byCharacterOffset:)`, marked text APIs, and `documentIdentifier`: https://developer.apple.com/documentation/uikit/uitextdocumentproxy
- Apple's text interaction guide shows the exact primitives: `insertText`, `deleteBackward`, `adjustTextPosition`, and combining before/selected/after context: https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards
- Apple's custom keyboard guide states that custom keyboards cannot control text selection, cannot draw outside their primary view, are replaced in secure text fields and phone/name phone pads, and can be rejected by host apps: https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html
- Open Access enables network access and shared App Group write access only after `RequestsOpenAccess = true` and user approval of "Allow Full Access": https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
- App Review guideline 4.4.1 adds privacy limits for keyboard extensions, including collecting user activity only to improve keyboard functionality and following data-use rules: https://developer.apple.com/app-store/review/guidelines/

Apple Intelligence:

- Foundation Models gives apps direct access to the on-device language model behind Apple Intelligence for text generation, structured output, and tool calling: https://developer.apple.com/documentation/FoundationModels/
- Model availability depends on supported device, Apple Intelligence being enabled, and model readiness; apps must check availability and provide fallback: https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models
- Foundation Models can refine/edit text, summarize, extract, classify, and generate text, but Apple says some tasks are unsuitable and must be tested: https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models
- Foundation Models locale support must be checked with `supportsLocale(_:)`; unsupported language/locale can throw `unsupportedLanguageOrLocale`: https://developer.apple.com/documentation/foundationmodels/support-languages-and-locales-with-foundation-models
- Apple Intelligence language support includes Japanese in current Apple support docs: https://support.apple.com/en-us/121115
- Writing Tools automatically work in standard text views and can be customized inside your own UIKit/AppKit app text views, but this is not the same as programmatic control over arbitrary host-app text from a third-party keyboard: https://developer.apple.com/apple-intelligence/get-started/

OpenAI API:

- Use the Responses API for text generation: https://platform.openai.com/docs/guides/text
- Use Structured Outputs so the rewrite service returns parseable JSON with exact fields: https://platform.openai.com/docs/guides/structured-outputs
- Optimize latency by generating fewer tokens, making fewer requests, streaming/loading states, and avoiding LLM calls for deterministic actions: https://platform.openai.com/docs/guides/latency-optimization
- API data is not used to train OpenAI models by default; abuse monitoring logs may be retained by default unless data-retention controls are configured: https://platform.openai.com/docs/guides/your-data

## What "Detecting The Input Box" Really Means

The keyboard does not receive a `UITextField`, `UITextView`, DOM node, app bundle internals, or screen coordinates for the host input. The system selects the active text input and gives the keyboard a `UITextDocumentProxy`.

Available:

- `documentContextBeforeInput`: text before the cursor, if the host provides it.
- `documentContextAfterInput`: text after the cursor, if the host provides it.
- `selectedText`: current selected text, if any.
- `documentIdentifier`: useful for detecting that the active document changed.
- `keyboardType`, `returnKeyType`, `textContentType`, `autocapitalizationType`, `autocorrectionType`: traits for adapting behavior.
- `insertText(_:)`: insert at cursor, and usually replace selected text.
- `deleteBackward()`: delete before cursor.
- `adjustTextPosition(byCharacterOffset:)`: move cursor forward/backward.

Not available:

- Full host text-field object.
- Guaranteed full field contents.
- Selection range indexes.
- A way to select arbitrary text.
- A way to show UI above the keyboard's own primary view.
- Secure fields, phone pads, and apps that disable third-party keyboards.

Product implication: for v1, copy the reference app's whole-input behavior. The AI card rewrites the whole available input text, not a highlighted subsection. Avoid promising full-document replacement because the proxy may only provide partial host context.

## Whole-Input Replacement Strategy

Represent the rewrite target as a whole-input capture:

```swift
struct WholeInputCapture: Equatable {
    let beforeCursor: String
    let selectedText: String
    let afterCursor: String
    let targetText: String
    let deleteBackwardCount: Int
    let moveToEndCount: Int
    let documentIdentifierString: String?
}
```

Capture rule:

1. Read `before = documentContextBeforeInput ?? ""`.
2. Read `selected = selectedText ?? ""`.
3. Read `after = documentContextAfterInput ?? ""`.
4. Build `targetText = before + selected + after`.
5. If the target is empty, disable AI commands.
6. If the target is too long, disable AI or ask the user to shorten the input.
7. Set `moveToEndCount = after.count`.
8. Set `deleteBackwardCount = targetText.count`.

This intentionally matches the observed reference app behavior: if the cursor is in the middle of the input, Replace moves to the end and rewrites the full captured input.

## Replace Algorithm

The replacement engine must operate against the same document and same available context that was captured. Before replacing, re-read the proxy and validate:

- `documentIdentifier` has not changed, if available.
- `before + selected + after` still equals the captured `targetText`.
- If validation fails, do not replace. Re-capture and ask the user to run the command again.

Whole-input replacement:

```swift
if capture.moveToEndCount > 0 {
    proxy.adjustTextPosition(byCharacterOffset: capture.moveToEndCount)
}
for _ in 0..<capture.deleteBackwardCount {
    proxy.deleteBackward()
}
proxy.insertText(replacement)
```

Important details:

- Count user-visible characters, not bytes. Emoji, dakuten combinations, flags, and composed characters need explicit testing.
- Keep a single `TextProxyMutationManager` so all `insertText`, `deleteBackward`, and cursor movements are logged and reconciled.
- Consume expected `textDidChange` callbacks after replacement to avoid the IME state machine thinking the host made an external edit.
- After replacement, clear the AI result card and refresh the normal candidate/suggestion bar from the new context.

## UX State Machine

### State 1: Normal Keyboard

Layout:

- Candidate/suggestion bar stays the same height as the pure Japanese keyboard's candidate bar.
- Leftmost item is a square AI icon button. In screenshots this sits where a magic-wand/smiley button appears.
- The rest of the bar remains Japanese candidates, suggestions, or empty space.

Behavior:

- AI button is enabled only if `captureWholeInput()` returns a target, or if there is active composition.
- Tap AI button: enter AI command mode.
- Long press AI button later: optional direct default command, probably "校正".

### State 2: AI Command Strip

Layout:

- AI icon remains selected on the left.
- Command pills occupy the suggestion bar: `校正`, `自然に`, `丁寧に`, `短く`, `英訳`, `日訳`.
- Close button on right.
- Keep the normal key grid visible and unchanged under the strip.

Behavior:

- Tapping a command captures the whole available input immediately and freezes that capture for the request.
- If text changes while the request runs, keep the result but require validation on Replace.
- Disable second command taps while generating, or allow cancellation + restart.

### State 3: Generating

Layout:

- Command pill changes to spinner/progress state.
- Keyboard remains usable if possible, but commands are disabled.
- For short requests, avoid a full-screen loading card.

Behavior:

- Start with a 300-500 ms minimum visible loading state to avoid flicker.
- Cancel request on close, document change, keyboard dismissal, or command switch.
- Timeout cloud calls at about 8-12 seconds. On-device calls can use a shorter practical timeout if the framework allows cancellation.

### State 4: Result Card

Layout:

- The result panel appears above the lower keyboard area, similar to the screenshot.
- Top label identifies the command result: `校正候補`, `自然な表現`, `丁寧な表現`.
- Main result text uses host-friendly plain text. Highlight changed spans if we can compute a diff locally.
- Bottom actions: copy, dislike/report, Replace primary button.
- Keep the globe/mic/system row behavior intact where possible.

Behavior:

- Replace button validates context and replaces.
- Copy inserts nothing; it copies only inside the keyboard process if pasteboard access is available under current permissions. If pasteboard is unreliable/permissioned, remove copy from v1.
- Dislike stores local feedback only unless the user has Full Access and consented to analytics.
- Close returns to AI command strip or normal candidate bar.

### State 5: Replaced

Behavior:

- Perform haptic feedback.
- Collapse result card.
- Return to normal keyboard candidate bar.
- Invalidate the captured input and AI response.
- Store a short local "last operation" record for undo-like handling if technically feasible.

## Rewrite Commands

v1 recommended commands:

- `校正`: grammar/spelling correction with minimal edits.
- `自然に`: natural Japanese wording.
- `丁寧に`: polite/business Japanese.
- `短く`: concise rewrite.
- `英訳`: translate Japanese to English.
- `日訳`: translate English/mixed input to Japanese.

Defer:

- Long-form summarize. Most keyboard contexts are short, and host context may be partial.
- Tone sliders. Too much UI for the keyboard surface.
- Arbitrary prompt input. It increases privacy risk and slows the flow.

## AI Engine Options

### Option A: Foundation Models

Use when:

- iOS 26+.
- `SystemLanguageModel.default.availability == .available`.
- `supportsLocale(Locale(identifier: "ja_JP"))` or current user locale succeeds.
- The feature compiles and runs inside the keyboard extension. This needs a real-device prototype.

Pros:

- On-device.
- No network.
- No API key.
- No per-request cost.
- Better privacy story for keyboard text.
- Works offline after model is available.

Cons:

- Limited to Apple Intelligence-capable devices and enabled settings.
- Model availability can be `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, `.modelNotReady`, or other unavailable states.
- Quality may be weaker than a cloud model for nuanced Japanese rewrites.
- Context window and latency must be measured on device.
- App extension compatibility should be verified early with a minimal keyboard-extension prototype.

Implementation shape:

```swift
protocol RewriteService {
    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult
}

@available(iOS 26.0, *)
final class FoundationModelsRewriteService: RewriteService {
    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult {
        // Check SystemLanguageModel.default.availability before constructing UI.
        // Use a fresh LanguageModelSession for single-turn rewrite commands.
        // Prefer guided generation if available for a typed RewriteResult.
    }
}
```

Prompt contract:

- Tell the model to rewrite only the target text.
- Preserve meaning, names, numbers, URLs, dates, emoji unless the command requires translation.
- Return plain text without quotes or explanation.
- For correction, make minimal edits.

### Option B: Cloud LLM API

Use when:

- Foundation Models is unavailable.
- User has enabled Full Access.
- User explicitly opts into cloud rewrite.
- Product needs higher-quality tone control or translation.

Keyboard extension networking:

- Set `RequestsOpenAccess = true`.
- The user must enable "Allow Full Access" in Settings.
- Keep the keyboard functional without Full Access. This is both product-critical and App Review-sensitive.
- Do not send every keystroke. Send only the explicit whole-input rewrite text after the user taps an AI command.

Security:

- Do not embed provider API keys in the keyboard extension.
- Use a backend proxy with user auth, rate limiting, abuse controls, and short request logs.
- Store only coarse operation metadata by default: command, length bucket, model, latency, success/failure.
- Never log raw text unless the user explicitly submits feedback with text attached.

OpenAI request shape:

- Use Responses API.
- Use Structured Outputs to force parseable JSON.
- Keep output short to reduce latency.
- Use a small/fast model for keyboard interactions unless quality evaluation proves otherwise.

Example JSON schema:

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

Prompt:

```text
You are a Japanese writing assistant inside a mobile keyboard.
Return only JSON matching the schema.
Rewrite the target text for the requested command.
Preserve meaning, names, numbers, URLs, dates, emoji, and line breaks.
Do not add commentary.

Command: {command}
Target text:
<target>
{text}
</target>
```

### Option C: System Writing Tools

Use only inside our container app's own text views, not as the main keyboard feature.

Rationale:

- Apple says Writing Tools automatically work in standard SwiftUI/UIKit/AppKit text views and can be customized in your app's text views.
- A third-party keyboard operating in another app does not own that host app text view and cannot generally invoke the system Writing Tools UI for it.

## Privacy And Trust UX

The keyboard should have three clear privacy modes:

1. Local only: normal Japanese IME and deterministic features. No network.
2. On-device AI: Foundation Models only. No text leaves device.
3. Cloud AI: explicit opt-in and Full Access required.

Container app copy should be direct:

- "AI rewrite sends only the text you ask us to rewrite."
- "We do not send every keystroke."
- "Cloud AI requires Allow Full Access because iOS blocks network access for third-party keyboards without it."
- "The keyboard still works without Full Access."

In the keyboard:

- If Full Access is off and cloud fallback is needed, show a small disabled state and route user to instructions in the container app. Do not nag after every tap.
- Prefer on-device AI where available, even for paid users, because it is the best trust story.

## Architecture Recommendation

Add these components under `Japanese/Sources` or `Japanese/iOS/KeyboardExtension` after the pure keyboard scaffold exists:

- `AIKeyboardState`: normal, commandStrip, generating, result, error.
- `RewriteCommand`: enum for correction, natural, polite, concise, translateToEnglish, translateToJapanese.
- `InputCapture`: reads `textDocumentProxy` and returns `WholeInputCapture?`.
- `WholeInputReplacementEngine`: validates the capture and applies replacement through the proxy.
- `RewriteService`: protocol.
- `FoundationModelsRewriteService`: on-device implementation.
- `CloudRewriteService`: backend implementation.
- `RewriteDiff`: local diff for highlight display, deferred until after v1.
- `AICommandBarView`: command strip UI.
- `AIResultCardView`: result UI.

Critical dependency:

- The AI replacement engine should share the same proxy mutation manager used by Japanese composition. If the pure Japanese keyboard adds an expected-edit tracker, AI replace must record expected edits through that same path.

## Implementation Phases

### Phase 0: No-AI replacement prototype

Goal: prove we can capture and replace text correctly before adding model calls.

- Add AI button and command strip with one fake command.
- Capture full available input context.
- Return deterministic replacement like `[rewritten] \(text)`.
- Replace through proxy.
- Test selected text, cursor at end, cursor in middle, Japanese text, emoji, multi-line text.

Exit criterion: replacement rewrites the whole captured input and never deletes outside the captured input in Notes, Messages, Safari text fields, and a WKWebView textarea test page.

### Phase 1: Result card microinteraction

Goal: match the reference UX without real AI.

- Loading state.
- Result card.
- Replace/cancel.
- Close behavior.
- Error state.
- Stable keyboard height and no text overlap.

Exit criterion: screenshots match the intended state transitions on iPhone SE-sized width, standard iPhone, large iPhone, and iPad floating keyboard width if supported.

### Phase 2: Foundation Models prototype

Goal: on-device AI path.

- Add compile-time gates for iOS 26.
- Check model availability.
- Check locale support.
- Run correction/natural/polite/concise commands.
- Measure cold latency and warm latency on real devices.

Exit criterion: if available, user can rewrite Japanese text without Full Access or network.

### Phase 3: Cloud fallback

Goal: high-quality fallback/premium path.

- Add backend proxy.
- Add opt-in and Full Access gate.
- Use Structured Outputs.
- Add timeout/cancel/retry.
- Add redaction tests for logs.

Exit criterion: cloud rewrite works only after explicit consent and never blocks normal keyboard typing.

### Phase 4: Quality eval

Create a small eval set:

- 100 Japanese casual sentences with typos.
- 100 business Japanese rewrites.
- 50 mixed Japanese/English chat snippets.
- 50 translation snippets.
- 30 edge cases: names, URLs, dates, emoji, phone numbers, addresses.

Metrics:

- Meaning preservation.
- Politeness/style correctness.
- No unwanted expansion.
- No hallucinated facts.
- Latency p50/p90.
- Replacement safety failures.

## Open Questions

- Is iOS 26+ acceptable for on-device AI as an enhancement, while v1 keyboard still supports lower iOS versions?
- Should the default AI command be `校正` or `自然に`?
- Do we want cloud AI in v1, or keep v1 local-only plus Foundation Models where available?
- Should v2 add selected-section rewriting, or keep whole-input rewriting only?
- Should AI results be allowed while Japanese IME composition is active, or should AI only run after commit?

## Recommended v1 Decision

Ship v1 with the AI UI and replacement engine behind a feature flag after the pure Japanese keyboard is stable. Start with:

- `校正`, `自然に`, `丁寧に`, `短く`.
- Whole available input capture, matching the reference app behavior.
- Cloud backend as the first real AI provider, guarded by Full Access and explicit opt-in.
- Foundation Models later as an on-device enhancement where available.

This keeps the UX close to the reference while avoiding two high-risk behaviors: silently sending arbitrary keyboard context to a server and pretending we can perform arbitrary selection-level rewrites in every host app.
