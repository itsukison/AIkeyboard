# AI Rewrite — Product, UX, and Replacement Algorithm

Last verified against code: 2026-06-07. Backend contract is in
`docs/backend.md`; module boundaries are in `docs/architecture.md`.

## Product shape

`AIキーボード` is a Japanese IME first. AI rewrite is an explicit,
user-triggered mode that lives in the candidate-bar height above the
keyboard. The user must:

1. Have signed in to the container app (Supabase auth).
2. Have toggled Cloud AI on in container settings.
3. Have enabled iOS Allow Full Access for the keyboard.

If any of those is missing, AI commands surface a one-line error in
Japanese and the normal Japanese keyboard keeps working unchanged.

### Prompt model

Unlike the original fixed-strip design (`校正 / 自然に / 丁寧に / 短く /
英訳 / 日訳`), the shipped product uses **user-editable prompts**:

- One `main` prompt — the primary pill in the candidate bar.
- N `sub` prompts — shown horizontally inside the `…` overflow drawer.

Prompts are stored as `UserPrompt` (`Sources/KeyboardPreferences/Preferences.swift`)
and managed in the container's `PromptsScreen`. Each prompt has a `title`
(button label), a `prompt` (instruction sent to the model), an optional
`builtinKey` (for locale hints — `translateToEnglish` switches the
response locale to `en-US`), and an enabled flag.

Built-in defaults (created on first run, fully overridable):

| `builtinKey` | Default title | Default instruction (Japanese) |
|---|---|---|
| `polite` | 敬語 | ビジネスで通用する自然な敬語に書き直してください… |
| `natural` | 自然に | ネイティブが書いたような自然で読みやすい日本語に… |
| `email` | メール | ビジネスメールの本文として送れる文体に書き直し… |
| `translateToEnglish` | 英訳 | 自然で読みやすい英語に翻訳してください… |

Exact strings live in `UserPromptDefaults.defaultPrompt(for:)`.

### Reply mode (返信)

Lets the user reply to a message that lives in **another app** (LINE, Mail,
etc.) and is therefore invisible to `UITextDocumentProxy`. The clipboard is the
bridge.

- **Detection (no banner):** on the keyboard's lifecycle hooks
  (`viewWillAppear` / `selectionDidChange` / `textDidChange`) plus a 0.6 s poll
  while visible (`startClipboardMonitoring`; iOS fires no callback when another
  app copies), `AIKeyboardController` compares `UIPasteboard.general.changeCount`
  against a persisted last-seen value
  (`KeyboardSettingsStore.lastSeenPasteboardChangeCount`, in the App Group). If
  it changed and `hasStrings` is true, a context-appearing **返信** pill appears
  in the main bar. This reads pasteboard *metadata only* — no content, no banner.
- **On tap (`runReplyFromClipboard`):** reads `UIPasteboard.general.string` —
  this triggers the iOS paste permission prompt — then calls
  `runReply(withCopiedText:)`, which captures the compose field with
  `InputCapture.captureForReply` (empty field is allowed — the reply is inserted
  at the cursor) and fires the normal pipeline with `replyTo` set.
- **Deferred — prompt-free `UIPasteControl`:** the bannerless/promptless path
  uses a system `UIPasteControl`, but a SwiftUI-wrapped control collapsed to
  zero width inside the keyboard (the `UIViewRepresentable` deferred-intrinsic-
  size pitfall), and its responder-chain enablement in a keyboard extension is
  unverified. Deferred until it can be made to render and fire reliably; the
  custom pill (with the prompt) ships meanwhile. `runReply(withCopiedText:)` is
  kept generic so that path can reuse it. See `docs/archive/uipastecontrol-research.md`
  for detailed findings from the implementation attempt.
- **Two inputs:** the copied message is sent as `RewriteRequest.replyTo`
  (context, what we reply *to*); the compose field is sent as `text` (the user's
  intent for the reply, may be empty). The Edge Function uses a reply-specific
  system prompt: empty `text` → compose a natural reply; non-empty `text` →
  shape the reply around it. The chosen candidate **replaces** the compose
  field, same as a rewrite.
- The reply command is a synthetic `UserPrompt` (`UserPromptDefaults.replyKey`),
  surfaced only by the pill — it is **not** in the editable prompt list and not
  seeded.
- `regenerate` re-replies to the same message; `refine` (より丁寧に etc.)
  operates on the chosen candidate as a plain rewrite (no `replyTo`).

## UX state diagram

```
        ┌──────────────────────────────────────────────┐
        │           Candidate bar (height ~44)          │
        │  [main prompt pill]  [...]  | candidates ...  │
        └──────────────────────────────────────────────┘
                       │
            tap main   │             tap …
                       ▼                 ▼
              .generating          .overflow
               (spinner pill)    [sub₁][sub₂]...[設定]
                       │                 │
                       │                 │ tap sub
                       │                 ▼
                       │            .generating
                       ▼
                  .result
              ┌──────────────────────────┐
              │ snap-carousel of cards   │
              │ (tap centered → replace) │
              ├──────────────────────────┤
              │ [再作成][より丁寧に]...    │
              └──────────────────────────┘
                       │
              ┌────────┼─────────┐
              │ replace │ refine │ regenerate
              ▼        ▼         ▼
           .hidden  .generating  .generating
        (text replaced, capture cleared)
```

Refinement intents append new candidates to the existing carousel instead
of replacing them, so users can compare. `regenerate` re-runs the
original prompt; the three `refine` chips
(`morePolite`/`moreDetailed`/`moreConcise`) further-edit the currently
focused candidate.

Fresh main/sub prompt generations always start on the leftmost card. For
the default three-card response, the backend asks the model to keep a
stable order: standard, slightly softer, then slightly more polite. The
cards stay unlabeled; the differences should be subtle unless the user
taps a refinement chip.

A candidate taller than the fixed card scrolls vertically inside it
(`CandidateCard` wraps the text in a `ScrollView` with
`scrollBounceBehavior(.basedOnSize)`, so short candidates stay static). The
vertical scroll is orthogonal to the horizontal snap-carousel, so a vertical
drag reads a long candidate while a horizontal drag switches cards. Tapping
the centered card still commits it — a tap never fires mid-drag, so scroll
and tap-to-replace don't collide.

Errors collapse the carousel and show a one-line message bar with a close
button.

## Capture strategies

`WholeInputCapture.mode` (`CaptureMode`) records which of three strategies
produced the capture. The mode is chosen in `AIKeyboardController.runFresh`
and decides how `WholeInputReplacementEngine` puts the rewrite back.

### 1. Selection — the user highlighted text

If `proxy.selectedText` is non-empty (and no romaji composition is in
flight), only the selection is rewritten. `InputCapture.captureSelection`
sets `targetText = selectedText`; the surrounding before/after windows are
kept on the capture as context (see privacy note below) but are not part of
the target. Replacement is a single `proxy.insertText(replacement)`, which
natively replaces the active selection — no cursor moves, no deletes.

`WholeInputReplacementEngine.replace(...)` validates that all three of
`before` / `selected` / `after` still match the capture before inserting. A
**cleared** selection aborts with `contextChanged`, because `insertText`
would otherwise insert at the cursor instead of replacing.

### 2. Full document — cursor walking

Otherwise the whole document is the target. iOS truncates
`documentContextBeforeInput`/`AfterInput` to a window around the cursor, so a
long field would silently be only partially rewritten. `FullDocumentReader`
reconstructs the full document by walking the cursor in window-sized hops:

- Read the visible window, merge it into the accumulator (trimming any
  overlap a hop undershoot leaves behind), hop by the window length, settle
  ~50 ms, re-read. Repeat backward, then forward, then restore the cursor.
- An empty window at a non-edge position marks a paragraph break, crossed
  with a 1-character probe and stitched as `"\n"`. The document edge is the
  probe that leaves both windows unchanged.
- After restoring the cursor, the stitched text is verified against the
  windows visible at the original position. Any drift (a host that ignores
  or overshoots `adjustTextPosition`, text periodic at exactly the window
  length) fails verification and the reader returns `.failed`.

`runFresh` shows the `.generating` UI immediately, then runs the walk inside
`rewriteTask` (so `close()` cancels it and the reader restores the cursor):

- `.tooLong` (stitched over 2000) → `"入力が長すぎます"`.
- `.failed` → fall back to the window capture (strategy 3) — never worse than
  before this feature existed.
- `.snapshot` longer than the window → `.fullDocument` capture. If the walk
  only ever saw the window (short field), the plain window capture is kept so
  replacement stays on the strict synchronous path.

Full-document replacement (`replaceFullDocument`, async) validates
suffix/prefix (strict equality is impossible — the proxy still shows only the
window at replace time), moves to the document end in window-sized hops, then
deletes `deleteBackwardCharacterCount` characters and inserts the rewrite. It
is **not** cancelled by `close()`: interrupting between the move and the
delete loop would leave the document half-replaced.

### 3. Whole available input — window only

The original strategy and the fallback for hosts the walk can't handle.
`InputCapture.capture` captures `before + selected + after` as exposed;
replacement moves to the end of the captured span, deletes it, and inserts.

```swift
let currentTarget = (proxy.documentContextBeforeInput ?? "")
    + (proxy.selectedText ?? "")
    + (proxy.documentContextAfterInput ?? "")
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
```

Document-identifier changes (user switched apps, dismissed keyboard,
focused a different field) trigger
`AIKeyboardController.documentDidChange` which closes the rewrite mode
and discards the in-flight task.

### Honest limitations

Cursor walking is best-effort. Hosts that ignore `adjustTextPosition` (some
web views) fall back to window-only capture; hosts that never report
`selectedText` never enter selection mode. The product copy may now say
full-document rewrite, but must keep the fallback caveat — it is not
guaranteed in every host.

## Failure modes

| Condition | User-visible behavior |
|---|---|
| No prompt configured | `"プロンプトが設定されていません"` error bar |
| Cloud AI toggle off | `"Cloud AIを設定でオンにしてください"` error bar |
| Full Access off | `"フルアクセスを有効にしてください"` error bar |
| Not signed in (no cached token) | `"アプリでサインインしてください"` error bar |
| Input empty | `"入力してからAIを使えます"` error bar |
| Input (or stitched full document) over 2000 chars | `"入力が長すぎます"` error bar |
| Selection cleared before replace | `"入力が変わりました。もう一度実行してください"` error bar |
| Context changed before replace | `"入力が変わりました。もう一度実行してください"` error bar |
| Cursor walk anomaly (host ignores/overshoots adjust) | silent fallback to window capture |
| Backend returns rate_limited | passes the backend message through |
| Network failure / timeout | `"AI rewrite failed."` |

## Privacy contract surfaced to the user

The container's privacy/settings screens must communicate:

- Normal Japanese typing is **never** sent to the network.
- Text is sent **only** when the user taps an AI prompt.
- For **selection mode**, the small on-screen text immediately around the
  selection is sent alongside it as context so the rewrite fits the sentence.
  It is sent only on that same tap and is **never stored** by the backend —
  only its length is recorded as metadata.
- For **reply mode**, the clipboard's contents are read only when the user taps
  the 返信 pill, and are then sent as the message being replied to. That tap
  read triggers the iOS paste permission prompt (a prompt-free `UIPasteControl`
  path is deferred — see Reply mode above). Deciding whether to show the pill
  uses pasteboard metadata only (no read, no banner). The public privacy policy
  (`docs/web/privacy.md`) and App Store nutrition label still need a clipboard
  line — see AGENTS.md §8.
- Cloud AI needs Allow Full Access because iOS blocks keyboard network
  access without it. The base keyboard works without Full Access.
- The backend does not log raw input/output — only command, length
  bucket, latency, status. (See `docs/backend.md` privacy section.)
- Foundation Models (on-device) is not in v1.

## Future work tracked here

- **Foundation Models** as a non-Full-Access on-device path on iOS 26+
  Apple-Intelligence-eligible devices. Plan: add
  `FoundationModelsRewriteService` conforming to `RewriteService`,
  feature-flag with kill switch. Pre-requisite: real-device prototype
  proving keyboard-extension compatibility.
- **Quality eval set** (~330 sentences across casual / business / mixed
  / translation / edge cases) for regression-testing prompt changes.
- **Reply mode** — the LINE-style text-copy core is **shipped** (see "Reply
  mode" above). The richer Slack-link resolution and tone strip from
  `docs/archive/ai-reply-implementation.md` are not implemented.
