# Onboarding — guided button builder (plan)

Status: **proposed, not implemented.** Written 2026-08-02.
Evidence this is built on: `docs/marketing/gtm/stickiness-diagnosis.md` §2, §4.

---

## 1. Why

Authoring a button that does a job the defaults don't cover is the single strongest predictor of
long-term retention we have measured — 32.0% reach 3+ rewrite days and 12.0% reach 10+, against a
7.2% / 0.5% baseline. **Only 1.1% of users ever do it.**

The use-case page shipped in 1.0.16 was supposed to close this and does not, for three measured
reasons:

1. 44% pick 敬語, and that preset is **by design identical to the existing default set**
   (`OnboardingUseCase.swift:70-73`). For nearly half of new users the page is a deliberate no-op.
2. The other presets are permutations of the same built-ins — `polite` and `natural` appear in all
   six. This is why preset selection behaves like "edited a default" (1.3×) rather than "authored
   own" (4.4×).
3. The one path that produces genuinely new content — `custom`, free text → AI-generated buttons —
   is listed **last** of seven, framed as 「その他（AIにおまかせ）」, and was chosen by 7 users (2.5%).
   Those 7 then ran 98.4% of their rewrites on their generated buttons. It works; nobody reaches it.

**The bet:** users cannot author from a blank field, but they can *assemble*. The 54 hand-written
prompts in the wild have a near-constant grammar — who I am · who I'm writing to · which app ·
how formal — so the thing we are asking them to invent is already predictable enough to offer as
choices.

## 2. Success criteria

| Metric | Now | Target |
|---|---|---|
| Users leaving onboarding with a **differentiated main button** | ~2.5% | **≥80%** (structural) |
| Distinct commands used in week 1 ≥2 | 20% | ≥40% |
| 3+ rewrite days after week 1 | 7.2% | ≥15% |

The first is structural — if it isn't ≥80% after shipping, the implementation is leaking, not the
hypothesis. The third is the real outcome and needs ~8–9 weeks to read (§8).

---

## 3. Flow

Replaces page 2 (`KeyboardUseCasePage`) and reshapes page 3 (`KeyboardPromptsPage`) in
`InteractiveOnboardingFlow`. Page count goes 8 → 9.

```
2  用途選択           (kept, simplified — see §4.1)
2a 誰に・どこで        (NEW — slot page A)
2b どのくらいの調子     (NEW — slot page B + result + name)
3  ボタン一覧          (kept — now confirmation / reorder / remove)
```

Two pages rather than one because page B carries live example sentences, which are visually heavy.
Splitting keeps each page to one decision type. Both are chip grids — **completing the whole
builder requires zero typing.**

After the result card on 2b:

- Primary CTA 「このボタンで始める」 → page 3
- Secondary 「もう1つ作る」 → loops back to 2a. **No hard cap** — the toolbar shows 4 and the rest
  live behind the `…` overflow, same as any user who adds buttons later. The naming preview in
  §4.4 shows the first four, so the crowding cost of extra buttons stays visible.

`OnboardingScaffold` already supports this exactly — `secondaryTitle` / `onSecondary`
(`OnboardingSourcePage.swift:19-20`). No new scaffolding.

---

## 4. Screens

### 4.1 Page 2 — 用途選択 (existing, two changes)

- **Remove the 敬語 no-op branch.** Every use case now leads into the builder, so 敬語 selectors get
  a differentiated button like everyone else.
- **Demote free text.** 「その他」 stays as an escape hatch but is no longer the only path to a real
  custom button, so it stops carrying weight it was failing to carry.

### 4.2 Page 2a — 誰に・どこで

```
┌────────────────────────────────────┐
│  ●●●○○○○○○                    スキップ │
│                                       │
│  誰に送りますか？                       │
│  よく使う相手を1つ選んでください           │
│                                       │
│  [友達]  [同僚]  [上司・取引先]          │
│  [家族]  [お客さま] [SNSの相手]          │
│  [＋自分で書く]                         │
│                                       │
│  どこで使いますか？                      │
│                                       │
│  [LINE] [メール] [Slack・Teams]         │
│  [X・Instagram] [社内チャット] [その他]   │
│                                       │
│              [    次へ    ]            │
└────────────────────────────────────┘
```

Chips use the existing `UseCaseOptionCard` press style and `OnboardingPalette`; a compact
wrapping chip variant, not the full-width cards (six options per group would otherwise need
scrolling).

### 4.3 Page 2b — 調子 + 結果 + 名前

```
┌────────────────────────────────────┐
│  ●●●●○○○○○                   スキップ │
│                                       │
│  どのくらいの調子で？                    │
│                                       │
│  ○ くだけて                            │
│    「明日ちょっと遅れるかも！」             │
│  ● ふつう                              │
│    「明日少し遅れそうです」                │
│  ○ きっちり                            │
│    「明日は少々遅れて伺います」             │
│                                       │
│  ひとこと補足（任意）                     │
│  ┌──────────────────────────────┐  │
│  │ 例：私は外国人なので、不自然な        │  │
│  │ 日本語も直してほしい                 │  │
│  └──────────────────────────────┘  │
│                                       │
│  ── できたボタン ──                     │
│  ┌────────┐                          │
│  │ 同僚LINE │ ← タップして名前を変更       │
│  └────────┘                          │
│  同僚へのチャット向けに、硬すぎない敬語へ     │
│                                       │
│         [ このボタンで始める ]           │
│            もう1つ作る                  │
└────────────────────────────────────┘
```

Three things matter here:

- **The example sentences are static, looked up from a `(相手 × 調子)` table.** No network call, so
  the tone selector is instant. Generating them would put a 2-second wait on a radio button.
- **The name is pre-filled and editable, never blank.** See §4.4 — the toolbar imposes a hard
  width budget, so the name is auto-derived from a single slot, not concatenated.
- **The button is generated when the user lands on 2b**, from A's answers with a default tone, and
  regenerated on tone change. If generation fails, fall back to the static preset for the use case
  and continue silently — never block onboarding on an LLM call.

### 4.4 Button naming — the toolbar sets a hard budget

The name is not cosmetic. It renders directly into the keyboard toolbar pill:
`Text(prompt.title)` at `.font(.system(size: 14, weight: .medium))` with `.lineLimit(1)` and
`.padding(.horizontal, 11)` (`AIKeyboardToolbarView.swift:240-245`). There is **no
`minimumScaleFactor` on the pills**, so an over-long title truncates or crowds its neighbours.

Budget, on a 393pt-wide device: ~381pt usable, minus inter-pill spacing and the divider, leaves
roughly **87pt per pill across four buttons**. At 14pt a full-width Japanese glyph is ~14pt and the
pill adds 22pt of padding, so:

| Title | Approx pill width | Fits 4-up |
|---|---|---|
| 敬語 (2) | ~50pt | ✅ |
| 自然に (3) | ~64pt | ✅ |
| カジュアル (5) | ~92pt | ⚠️ borderline |
| 同僚LINE (2 full + 4 half) | ~82pt | ⚠️ borderline |

Every shipped default is 2–3 characters, and observed user-authored titles are 2–6.

**Rules:**

- **Auto-name from the single most distinctive slot, never a concatenation.** 相手 → 「同僚」
  「友達」「上司」; translate → 「英訳」「中訳」; proofread → 「添削」; summarize → 「要約」.
  My earlier 「同僚LINE」 suggestion is too wide — drop it.
- **Cap the field at 6 characters**, counting full-width as 1.
- **Show a live toolbar mock** in the naming row — render the real pill row with their name sitting
  in it. Seeing the crowding beats a character counter or an error message, and it costs one
  small view.
- Verify the 4 × 6-character worst case on the narrowest supported device before shipping; add
  `minimumScaleFactor(0.85)` to the pills only if it actually breaks.

---

## 5. Per-use-case question schema

The questions must differ by use case — translation has no "who are you sending to" in the same
sense, and proofreading has no tone axis. Implement as data, not six hardcoded pages:

```swift
struct ButtonBuilderSpec {          // one per OnboardingUseCase
    let pageA: [SlotGroup]          // 1–2 chip groups
    let pageB: SlotGroup?           // the tone-like axis, nil to skip page B's selector
    let sampleSentences: SampleTable // for the live preview
    let nameTemplate: (Selections) -> String
}
```

| use case | Page A | Page B axis |
|---|---|---|
| keigo | 送る相手 · アプリ | 丁寧さ（くだけて/ふつう/きっちり） |
| email | 宛先（社内/社外/お客さま） · メールの種類（依頼/報告/お詫び/お礼） | 丁寧さ |
| casual | 送る相手 · アプリ | くだけ具合 |
| **translate** | **どの言語へ**（英/中/韓/その他） · 誰に向けて（友達/仕事相手/不特定） | かたさ（口語/中立/ビジネス） |
| **proofread** | **自分の立場**（日本語learner/ネイティブ） · 直す範囲（誤字だけ/不自然さも） | — (skip selector, show preview only) |
| summarize | 何を（チャット/記事/メール/議事録） | どのくらい短く（半分/3行/1行） |
| custom | 自由記述のみ | — |

`proofread` skipping the tone axis matters: for 添削 the whole point is *not* changing the
register, so offering a tone dial would contradict the job. Page B still renders — result card,
name, optional note — just without the selector.

**The 日本語learner branch under proofread is deliberate.** Explicit non-native framing
(「私は外国人です！」) recurs in the stickiest hand-written prompts, and that segment currently has
no path that names it.

---

## 5.5 The practice pages must demonstrate *their* button — and today they can't

This is the largest hidden dependency in the whole plan.

`OnboardingPracticeScenario.make(for:)` (`InteractiveOnboardingFlow.swift:79-172`) picks the worked
example by `switch prompt.builtinKey`, then falls back to **title substring matching**
(`title.contains("カジュアル")`, `"中国語"`, `"添削"`, `"要約"`), then to a generic default.

**Every builder-generated button has `builtinKey = nil` and an arbitrary user-chosen title.** So
unless the title happens to contain one of four hardcoded substrings, every builder user lands on
the generic fallback: 「よろしくおねがいします」 → a politeness upgrade. The user builds a
「友達へのLINE」 button, then practices with a politeness demo. That is worse than the current state,
because it actively contradicts what they just told us.

It cannot be fixed at practice time. Practice mode is deliberately **offline and pre-auth** — the
container writes canned candidates into the App Group
(`KeyboardSettingsStore.onboardingPracticeCandidatesKey`) and
`AIKeyboardController.firePractice()` replays them with no network call. There is no signed-in
session yet, so the real rewrite endpoint is not available.

**Fix: generate the practice scenario at button-creation time, in the same call.**

Extend the `generate-prompt-preset` response schema so the main button also carries a worked
example:

```jsonc
{
  "buttons": [
    {
      "title": "同僚",
      "prompt": "…",
      "sampleInput": "明日ちょっとおくれます",          // NEW
      "sampleOutputs": ["…", "…", "…"]                  // NEW — exactly 3
    }
  ]
}
```

Then:

- `OnboardingPromptSetup` stores `sampleInput` / `sampleOutputs` for the main button alongside the
  prompt (new App Group keys next to the existing practice keys).
- `OnboardingPracticeScenario.make(for:)` reads the stored scenario first; the existing
  `builtinKey` switch and substring chain stay as the fallback for seeded built-ins and for
  generation failures. **Do not delete the existing chain** — it is the safety net.
- No extra latency at practice time, no network, no auth. One LLM call still covers everything.

Two knock-on requirements:

- **The reply practice page (page 6) needs the same treatment or an explicit skip.**
  `replyIncomingMessage` / `replyCandidates` are hardcoded to a scheduling exchange in 敬語. For a
  user who built a translation or casual button, that page demonstrates a function they did not ask
  for. Either generate a matching incoming message in the same call, or skip page 6 when the
  built button's job is not reply-shaped and let the reply feature be discovered later.
- **The generator's sample must obey the button it just wrote.** If the button says "strip keigo",
  `sampleOutputs` that add keigo make the product look broken on first contact. Add this as an
  explicit constraint in the generator prompt and spot-check it during implementation.

---

## 6. Prompt engineering

OpenAI's GPT-5.6 guidance (2026-07-09): state each instruction **exactly once**; prefer outcome +
stop condition over procedure; contradictions cost latency and accuracy; replace adjectives with
behavioural specs; control length with the `verbosity` parameter, not prose.
Reported effect of simplifying: **+10–15% eval, −41–66% tokens.**

### 6.1 Stop duplicating the rewrite system prompt (bug, already live)

`keyboard-rewrite/index.ts:1789-1790` already says:

> `Preserve meaning, names, numbers, URLs, dates, and emoji.`
> `Do not add explanations, markdown, quotes, commentary, or unsupported facts.`

Yet `generate-prompt-preset/index.ts:115-116` instructs the generator to put the same rules into
every button prompt, and the static presets in `OnboardingUseCase.swift` hardcode them too. Of the
~200 characters in the seeded カジュアル prompt, only the first sentence differentiates anything.

```
before: 次の文章を、友達や親しい人に送るカジュアルで自然な日本語に書き直してください。
        敬語や堅い表現は避け、日常会話やSNSでそのまま送れるフレンドリーな口調にして
        ください。ただし乱暴・失礼な印象にはせず、親しみやすさを保ってください。原文
        の意味や意図は変えず、事実を付け足したり省いたりしないでください。絵文字は原
        文にある場合のみ活かし、無理に足さないでください。出力は書き直した文章だけに
        してください。

after:  友達へのLINE。敬語をやめ、文末を「〜だよ / 〜ね」に、一文を短く。乱暴な語は
        使わない。
```

Applies to both the generated prompts and the static presets.

### 6.2 Resolve the contradiction

`index.ts:1781` — `Keep the differences subtle unless the command or refinement explicitly asks for
a stronger change` — directly conflicts with any builder output asking for a strong register shift
(敬語 → タメ口). Per the guidance this produces instability, and it is the same root as the 敬語
under-politeness finding (`stickiness-diagnosis.md` §3). Either drop the sentence or have the
builder emit an explicit strength marker the system prompt can key off.

### 6.3 Move the generator onto `gpt-5.6-terra`

`generate-prompt-preset/index.ts:127-131` runs on `CEREBRAS_API_KEY` / `gpt-oss-120b`, while the
rewrite path runs `gpt-5.6-terra`. **The artifact that best predicts retention is produced by the
weakest model in the stack.** This is one call per user, latency-tolerant, behind a rate limit.

### 6.4 Rewrite the generator's system prompt outcome-first

Current: an eight-line list of writing rules, most of which restate the downstream system prompt.
Target: state the outcome and the stop condition, and say explicitly that the invariants live
downstream so the model does not re-emit them.

Keep: strict JSON schema (already correct), the 200-char input cap, the per-IP rate limit, and
fail-open behaviour.

---

## 7. Analytics

Existing `onboarding_prompts_customized` fires from `OnboardingPromptSetup.save` whenever the set
differs from default — with the no-op branch removed it will fire for nearly everyone, so it stops
discriminating. Add:

| event | properties |
|---|---|
| `onboarding_button_builder_started` | `use_case` |
| `onboarding_button_created` | `use_case`, `slots` (chosen chip ids), `used_free_text`, `renamed`, `button_index` |
| `onboarding_button_builder_skipped` | `use_case`, `page` |
| `onboarding_button_generation_failed` | `use_case` (fell back to static preset) |

Downstream, a differentiated button is identifiable in `ai_rewrite` as `command_key = null`, but
that conflates builder-generated with later self-authored. **Ship `prompt_origin`** — a field on
`UserPrompt` (`builtin` / `onboarding_builder` / `user_authored`), carried through the App Group,
sent by the keyboard with the rewrite request, and logged into the `ai_rewrite` payload next to
`command_key`.

This matters beyond bookkeeping: §2's headline result is that *self-authored* buttons predict
retention at 4.4×, while *preset* buttons predict at 1.3×. Without `prompt_origin` we cannot tell
which of those the builder is actually producing, and the experiment in §8 would only measure
whether the arm differs — not why. Backfill is impossible, so it has to land with the feature.

---

## 8. Rollout — straight ship to everyone

**Decided 2026-08-02: no A/B test.** The 1.0.16 presets are already known not to work (§1: 44% pick
a preset identical to the default set), so there is nothing worth preserving as a control arm. The
builder ships to 100% and the old preset path is deleted, not gated.

An earlier draft of this section proposed a 50/50 local SHA-256 split
(`OnboardingExperiment.swift`) to answer whether authoring *causes* stickiness or merely marks
intent. That file now lives in `archive/onboarding/` and nothing references it. The
`builder_arm` person property and the `onboarding_builder_assigned` exposure event are gone too.

What still reads without an experiment:

- **Before/after by release.** Every onboarding event carries `onboarding_version`
  (`interactive_v3`), and rewrites carry `prompt_origin`, so the builder cohort is separable from
  the 1.0.16 cohort without an arm.
- Secondary, ~2 weeks: differentiated-main-button rate, distinct commands in week 1,
  2nd-rewrite-day rate.
- Primary, ~8–9 weeks: 3+ rewrite days.

The cost of dropping the split is that the read is a before/after comparison across releases, not a
randomised one — seasonality and acquisition-mix shifts are not controlled for. That was judged an
acceptable price for not shipping a known-ineffective flow to half of new users.

---

## 9. Decisions taken (2026-08-02)

- **No A/B test** — straight ship, old preset path deleted (§8).
- **The set that survives onboarding is only what the user built.** The seeded 自然に / メール /
  英訳 are dropped, and so are the three authored complements per use case. One handpicked button,
  plus however many more the user chooses to build.
- **Templates, not the model, produce the button.** The chip combinations are finite, so the prompt
  is assembled from authored fragments with no network call. `generate-prompt-preset` is reached
  only when the user typed a free-text note, and a failure there falls back to the templated button
  silently.
- **「もう1つ作る」 returns to the use-case page**, not the slot page — a second button is usually a
  second job.
- **補足 placeholder** — single example, no locale special-casing. It is illustrative, not
  prescriptive.
- **Button count** — no cap. Overflow behaves as it already does for buttons added later.
- **`prompt_origin`** — ships with the feature (§7). Not backfillable.
- **Naming** — auto-derived from one slot, capped at 6 characters. The live toolbar mock (§4.4) is
  not built; with one button in the bar it no longer earns its place.
- **Practice examples** — keyed by the button's **UUID**, not its title. The review page exists so
  the user can rename, and a title key detached the example the moment they did. Existing scenario
  chain retained as fallback (§5.5).

## 10. Build order

Backend first, because §6 is unflagged and independent of the UI:

1. §6.1 remove duplicated rules from generated prompts and static presets
2. §6.2 resolve the `Keep the differences subtle` contradiction
3. §6.3 move `generate-prompt-preset` to `gpt-5.6-terra`; §6.4 rewrite its system prompt
4. §5.5 extend the response schema with `sampleInput` / `sampleOutputs`
5. `prompt_origin` through `UserPrompt` → App Group → keyboard → edge function payload
6. `ButtonBuilderSpec` + pages 2a / 2b; delete the fixed preset path entirely
7. Practice scenario reads stored samples; reply page tailored or conditionally skipped
   — **still open**, page 8 is hardcoded to a 敬語 scheduling exchange for everyone
8. Analytics events
