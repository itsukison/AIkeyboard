# Design brief — the onboarding builder's questions

**Task: design the questions each use case asks. Not the prompt text — that is
`docs/preset-prompt-authoring-brief.md`.** Written 2026-08-03.

You are deciding *what to ask a brand-new user so we can build them a keyboard button they will
keep pressing.* Everything else is settled; the question taxonomy is not.

---

## 1. What the app is

`敬語ボタン` is a third-party Japanese iOS keyboard. Alongside normal typing it has a row of **AI
rewrite buttons** in its toolbar. The user types (or selects) text in any app — LINE, Gmail, Slack,
X — taps a button, and gets three rewritten candidates to swap in.

The four buttons shipped by default are 敬語 / 自然に / メール / 英訳. Each is a stored
`(title, prompt)` pair: the title is the pill on the toolbar, the prompt is a Japanese instruction
sent to GPT-5.6 along with the user's text.

Users can edit these and add their own. That matters enormously — see §4.

## 2. What a button *is*, and the single most important constraint

**A button is a standing tool, not a message composer.** The same メール button gets pressed for a
request today, an apology tomorrow, a thank-you next week. The user answers your questions **once**,
during onboarding, and lives with the result for months.

This gives the test every question must pass:

> **Would this answer still be correct the 50th time they press the button?**
> Yes → standing context. Valid question.
> No → it is content. The model already has it from the input text. Do not ask.

Corollary: **GPT-5.6 reads the content.** It can see that this particular message is an apology. It
*cannot* see who the user is, who they are writing to, how formal their workplace is, or what the
channel expects. Those blind spots are the entire legitimate subject of your questions.

A question that narrows *what the button can be used for* is a bug, not a feature.

## 3. Where the questions live

Onboarding, pages 3–4 of 11:

```
2  用途選択          user picks one of seven use cases (§5)
3  Q1 + Q2          compact chip groups (one group when the purpose has two questions)
4  最終質問 + 任意メモ + CTA  example-backed register/length choice
5  ボタン確認         name + instruction, editable inline; 「もう1つ作る」 loops back
```

- **Chips, not typing.** Every common answer must be selectable by tapping. This is the whole reason the
  builder exists (§4).
- **Two or three questions per use case.** Three-question purposes place two compact groups on page
  3, so the onboarding page count does not grow.
- **The page-4 question gets the example-sentence treatment** when it is a
  register/preservation/length axis — each option shows
  the same sentence rendered at that setting, so the choice is made by reading the outcome rather
  than parsing a label.
- **`その他` must accept free text.** Tapping it reveals an inline required field belonging to that
  question. Its value is carried into the generated button description, rather than being mixed
  into the optional note.
- **A free-text 「ひとこと補足」 field already exists on page 4**, for cross-cutting facts that
  belong to no slot (「私は外国人です」). Do not duplicate it in a question.

The answers feed two things: the **button's prompt**, assembled from authored fragments, and the
**button's name**, taken from one designated slot (so one slot per use case must yield something
namable — see §7).

## 4. What the production data says about how these buttons are used

This is the evidence base. Do not design against intuition alone.

**Command volume (31 days, 6,307 rewrites, 1,014 users)**

| command | rewrites | users | acceptance |
|---|---|---|---|
| 敬語 | 4,635 (73%) | 956 | **25.8%** |
| 自然に | 493 | 142 | **42.6%** |
| メール | 204 | 72 | 22.5% |
| 英訳 | 130 | 38 | 37.7% |
| 返信 | 71 | 31 | 25.4% |

敬語 is the overwhelming default *and* the worst-performing. Controlled within-user, same version
band: 自然に accepts at 44.9%, 敬語 at 27.0%.

**What users write when they author their own button** (54 hand-written prompts; owner stickiness
in rewrite-days)

| theme | prompts | avg rewrite days of owner | owners reaching 5+ days |
|---|---|---|---|
| Translation (英/中/韓/仏, 互訳, +romaji) | 22 | 4.3 | 6 |
| Casual / friend register | 17 | 4.6 | 4 |
| Naturalise / proofread my Japanese | 13 | 3.4 | 6 |
| **敬語 / business politeness** | **9** | **1.0** | **0** |
| Summarise | 6 | 0.7 | 0 |

**Nobody who wrote their own 敬語 button stuck.** Zero of nine. The stickiest user in the whole
dataset (25 rewrite days, 447 rewrites, 78.8% acceptance) runs a 「友達」 button — the inverse of the
product's name.

**What people encode when given a blank field** — recurring shapes in those 54 prompts:

- **Who they are.** 「私は外国人です！」「大阪在住の日本人男性」「30代イギリス人女性」
- **Who they are writing to.** 「友達」「同僚」「高校生」
- **Which channel.** 「LINE」「Google Chat」「X・Instagramのコメント、FF外から失礼します的な」
- **Register.** 「カジュアル」「硬すぎず」

Note that users volunteer *both* addressee and register. They are related but not redundant to
users — the redundancy in §6 is an artefact of our chip design, not a fact about the domain.

**Declared intent** (`onboarding_use_case_selected`, since 2026-07-20)

keigo 125 · email 60 · proofread 45 · translate 27 · casual 19 · custom 7 · summarize 6

45% declare keigo — the job with the worst acceptance and zero retained authors. **What users say
they came for and what keeps them are not the same thing.** Your questions serve the second.

**Friction reality.** 73% of new users type fewer than 12 characters on their first day, and only
2.5% ever chose the old free-text path. Every question you add is paid for by everyone.

## 5. The seven use cases

From `iOS/Container/OnboardingUseCase.swift`. Titles and captions are what the user reads on page 2.

| id | title | caption |
|---|---|---|
| `keigo` | 敬語に整える | 目上の人・ビジネス向けの丁寧な言い方に |
| `email` | メール・ビジネス文書 | そのまま送れるメール本文に整える |
| `casual` | カジュアル・フレンドリー | 友達やSNS向けの自然でやわらかい口調に |
| `translate` | 翻訳する | 英語・中国語などに翻訳する |
| `proofread` | 日本語をチェック・添削 | 文法や誤字、不自然な言い回しを直す |
| `summarize` | 要約・わかりやすく | 長い文章を短く、読みやすくする |
| `custom` | その他（AIにおまかせ） | 使いたい用途を書くと、AIがボタンを作成 |

`custom` skips the builder entirely — the user has already described the job in prose.

## 6. What is wrong with the current questions

Diagnosed 2026-08-03. Do not reproduce this.

| use case | Q1 | Q2 | Q3 | problem |
|---|---|---|---|---|
| 敬語 | 相手 | どこで | 丁寧さ | Q1 and Q3 both measure formality |
| カジュアル | 相手 | どこで | くだけ具合 | same |
| メール | 宛先 | 用件 | 丁寧さ | Q1/Q3 overlap **and** Q2 is content |
| 翻訳 | 言語 | 相手 | かたさ | Q2 and Q3 are near-identical |
| 添削 | 立場 | 範囲 | — | fine |
| 要約 | 何を | 長さ | — | Q1 is arguably content |

Two distinct failures:

1. **Formality asked twice.** 上司/取引先/お客さま/先輩/同僚 is already five levels of formality
   *plus* relationship; a 3-point dial on top is a strictly worse duplicate. 翻訳 is the clearest
   case — 友達→口語, 仕事相手→ビジネス, 不特定多数→中立 is nearly a bijection.
2. **Content masquerading as context.** メール's 用件（依頼/報告/お詫び/お礼）fails the §2 test
   outright: people send all four from the same button. 要約's 何を is the same failure, milder.

Note the two use cases without the first problem — 添削 and 要約 — are exactly the two with no tone
dial. The dial was built as a shared component and then bolted onto use cases whose Q1 already
answered it.

## 7. Constraints your design must satisfy

1. **Every question passes the §2 test.**
2. **Questions within a use case must be orthogonal.** If you can predict Q2 from Q1, Q2 is
   friction.
3. **One slot per use case must be namable.** The button's default name comes from
   `spec.nameSlotId` — that slot's chosen chip supplies it, via an optional `shortName`. Names are
   hard-capped at **6 characters** and should be ≤4 full-width: they render into the toolbar pill at
   14pt with no `minimumScaleFactor` (`AIKeyboardToolbarView.swift:240`). Calibrate against 敬語 /
   自然に / メール / 英訳.
4. **A question may not contradict its own use case.** 添削 deliberately has no register axis —
   preserving the writer's register *is* the job, so a politeness dial would fight it. Check each
   use case for its equivalent.
5. **Chip order is frequency order.** The first chip should be what most users would pick. An
   earlier version put 友達 and 家族 at the top of the 敬語 flow, which is close to nonsense.
6. **`その他` where the tail is real**, with free-text substitution.

## 8. Prompt-engineering rules (context for why questions are shaped this way)

Your questions become fragments that concatenate into the button's instruction. Two things bound
what a good question looks like.

**The downstream contract.** Every button prompt is sent as the `Command:` line to
`supabase/functions/keyboard-rewrite/index.ts`, whose system prompt already guarantees: preserve
meaning / names / numbers / dates / emoji; no markdown, commentary or invented facts; output the
rewritten text alone; return exactly three candidates in a fixed order. **A question whose answer
would only restate one of those is worthless** — it is already true.

**OpenAI's GPT-5.6 guidance**, which the codebase now follows:

- State each instruction exactly once. Repetition costs tokens and degrades adherence.
- Prefer outcome and stop conditions over procedure.
- Contradictions produce instability — the model burns effort reconciling them and gets slower and
  less accurate.
- Replace adjectives with behavioural descriptions: not 「丁寧に」 but 「文末を〜です/〜ますにする」.

The practical consequence for you: **a good question is one whose answers translate into distinct,
non-contradicting behavioural clauses.** If two options would produce prompt text that differs only
by an adjective, they are not two options.

## 9. Approved question taxonomy (2026-08-03)

| use case | page 3 | page 4 |
|---|---|---|
| 敬語 | 主な相手 · 主な利用場所 | 丁寧さ（自然な丁寧語 / ビジネス敬語 / かなりかしこまる） |
| メール | 主な相手 · メールとして整える範囲 | 長さ（簡潔 / 標準 / 丁寧に詳しく） |
| カジュアル | 主な利用場所 | くだけ具合（丁寧さを少し残す / 自然で親しみやすい / かなりくだける） |
| 翻訳 | 翻訳先の言語 · 訳し方 | 口調（カジュアル / 丁寧 / ビジネス） |
| 日本語添削 | 直す範囲 | 元の書き方を残す程度 |
| 要約 | 出力の形 | 短さ（少し短く / かなり短く / 一文だけ） |

Every group also has 「その他」. Selecting it reveals a required inline field for that group;
the optional page-4 note remains separate.

## 10. Deliverable

Edit `iOS/Container/OnboardingButtonBuilder.swift`:

- `BuilderSlotGroup` values per use case (id, question, chips with ids/labels/shortNames)
- the `spec(for:)` switch wiring them, including `nameSlotId` and `toneSamples`
- `PresetPromptTemplate.slotOrder`, `fragments`, `practiceKeyOrder` updated to match

Then update `docs/preset-prompt-authoring-brief.md` §6 so the prompt-fragment author is working from
the same taxonomy.

**⚠️ Silent-failure hazard.** `fragments` and `practice` are dictionaries keyed by
`"<groupId>.<chipId>"`, and `slotOrder` / `practiceKeyOrder` are plain strings. Renaming a chip or a
group **compiles clean and silently drops that answer from the assembled prompt.** After any
taxonomy edit verify, by hand: every group asked on screen appears in `slotOrder`; every chip has a
fragment; every practice-key combination exists. There is no container test target, so nothing will
catch this for you.

Build check:
`xcodebuild -project KeigoButton.xcodeproj -scheme KeigoButton -destination 'platform=iOS Simulator,name=iPhone 17' build`

## 11. Further reading

- `docs/onboarding-button-builder-plan.md` — the feature, the flow, the rollout
- `docs/preset-prompt-authoring-brief.md` — writing the fragment text (downstream of you)
- `docs/marketing/gtm/stickiness-diagnosis.md` §2–3 — why authored buttons matter: 32% of users who
  author one reach 3+ rewrite days vs a 7.2% baseline; picking a preset gets 9.3%
- `docs/marketing/gtm/value-proposition-2026-08.md` §3 — the full custom-prompt theme analysis
