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

Errors collapse the carousel and show a one-line message bar with a close
button.

## Replacement algorithm

The rewrite target is **the whole available host input** — everything
`UITextDocumentProxy` returns from
`documentContextBeforeInput + selectedText + documentContextAfterInput`.
If the cursor is mid-text, replacement moves to the end of the captured
input, deletes that captured text, and inserts the rewrite.

`InputCapture.capture(from:)`:

1. `before = proxy.documentContextBeforeInput ?? ""`
2. `selected = proxy.selectedText ?? ""`
3. `after = proxy.documentContextAfterInput ?? ""`
4. `target = before + selected + after`
5. Reject if `target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`
   → `WholeInputCaptureError.empty`
6. Reject if `target.count > 2000` → `WholeInputCaptureError.tooLong`
7. `moveToEndCharacterCount = after.count`
8. `deleteBackwardCharacterCount = target.count`
9. `documentIdentifierString = String(describing: proxy.documentIdentifier)`

`WholeInputReplacementEngine.replace(...)`:

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

### Why whole-input only

iOS keyboard extensions cannot select arbitrary text in the host. The
proxy gives us before / selected / after, and nothing else. Trying to
replace a "subsection" inside a paragraph would need offsets the host
never gives us. We capture and replace what the host actually exposes —
called "whole available input" in user-facing copy, not "whole document".

If a host gives us only partial context, we rewrite only the partial
context. The product copy must never promise full-document rewrite.

## Failure modes

| Condition | User-visible behavior |
|---|---|
| No prompt configured | `"プロンプトが設定されていません"` error bar |
| Cloud AI toggle off | `"Cloud AIを設定でオンにしてください"` error bar |
| Full Access off | `"フルアクセスを有効にしてください"` error bar |
| Not signed in (no cached token) | `"アプリでサインインしてください"` error bar |
| Input empty | `"入力してからAIを使えます"` error bar |
| Input over 2000 chars | `"入力が長すぎます"` error bar |
| Context changed before replace | `"入力が変わりました。もう一度実行してください"` error bar |
| Backend returns rate_limited | passes the backend message through |
| Network failure / timeout | `"AI rewrite failed."` |

## Privacy contract surfaced to the user

The container's privacy/settings screens must communicate:

- Normal Japanese typing is **never** sent to the network.
- Text is sent **only** when the user taps an AI prompt.
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
- **Reply mode** (Slack / LINE quick replies) — see
  `docs/archive/ai-reply-implementation.md`. Not on the active roadmap.
