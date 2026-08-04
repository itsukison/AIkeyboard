# Authoring brief — templated preset prompts for the onboarding button builder

**For: Codex (has repo access). Deliverable: Swift text data, no logic.**

---

## 1. What you are writing, in one paragraph

The onboarding button builder asks a new user one to three tap-only questions about reusable
preferences and produces a keyboard button tailored to those answers. Per-message facts that the
rewrite model can see in the source text—such as request vs apology or chat vs article—must not
become permanent button settings. Fixed combinations use **templated prompts assembled from authored
fragments**; the model call is reserved for a free-text note or an unspecified translation language.

Your job is to write the fragment text. All the plumbing is decided; nothing you write changes
control flow.

## 2. The contract — what is ALREADY guaranteed downstream

This is the most important section. Every button prompt you write is sent as the `Command:` line to
`supabase/functions/keyboard-rewrite/index.ts`, whose system prompt is **already**:

```
You are a Japanese mobile keyboard writing assistant.
Apply the user-supplied command instruction to the target text only.
Preserve meaning, names, numbers, URLs, dates, and emoji. Preserve line breaks unless the command
  explicitly asks to restructure or format the text.
Do not add explanations, markdown, quotes, commentary, or unsupported facts. Add greetings or
  closings only when the command explicitly requests them.
Return exactly 3 candidate rewrites in this fixed order:
1. Standard: the most natural reading of the command.
2. Softer: warmer and slightly more casual than 1, without slang.
3. More polite: one notch more courteous than 1, without becoming stiff.
Apply the command at full strength in all three. Variants 2 and 3 shift the register around 1
  unless the command explicitly requires preserving the original register; they never soften how
  far the command itself is applied.
Avoid near-duplicates unless the command permits only one valid correction.
Return strict JSON matching the schema.
```

**Therefore: never write any of the following into a button prompt.**

- 意味・意図を保つ / 事実を足さない
- 固有名詞・数字・日付・URL・絵文字を保つ
- 解説・マークダウン・引用符を付けない
- 出力は変換後の文章だけにする
- 候補を3つ返す / 候補の並び順

This is not merely a style preference. OpenAI's GPT-5.6 guidance recommends lean prompts and says
to state each instruction once. Its reported **+10–15% eval score and −41–66% token** ranges came
from a sample of internal coding-agent evals, so they are directional evidence rather than a promised
gain for this rewrite workload. Validate the finished prompts on representative Japanese inputs. The
old seeded カジュアル prompt was ~200 characters of which only the first sentence differentiated
anything.

## 3. House rules for prompt text

1. **Behaviour, not adjectives alone.** GPT-5.6 guidance says broad labels such as "friendly" can be
   ambiguous; describe the writing choices that create the intended tone.
   - ✗ 「丁寧で親しみやすい文章にする」
   - ✓ 「文末を〜です/〜ますにし、クッション言葉を一つ添える」
2. **Only the differentiator.** If a clause would be true of every button in the app, delete it.
3. **No contradictions.** Do not write anything that fights the system prompt above (e.g. do not ask
   for a single output, or for a specific number of candidates).
4. **Short.** Target ≤60 Japanese characters per fragment. The assembled prompt should land under
   ~150.
5. **Imperative Japanese**, consistent with the existing built-ins.

## 4. Title rules

Titles render straight into the keyboard toolbar at 14pt with 11pt horizontal padding and **no
`minimumScaleFactor`** (`iOS/KeyboardExtension/AI/AIKeyboardToolbarView.swift:240`). The main bar
shows one main command and an overflow button; the three complements live in a horizontally
scrollable overflow row. They are not four equal-width pills squeezed into the main bar.

- **Hard maximum: 6 characters**, matching `OnboardingButtonName.maxLength`.
- Prefer **4 or fewer full-width characters** for authored complement titles so the overflow row is
  quick to scan.
- Existing built-ins for calibration: 敬語 / 自然に / メール / 英訳.

## 5. Where it goes

Add to `iOS/Container/OnboardingButtonBuilder.swift`. The structure to populate:

```swift
struct PresetPromptTemplate {
    /// Slot-group ids joined in this order; missing slots are skipped.
    let slotOrder: [String]
    /// "<groupId>.<chipId>" -> one behavioural clause.
    let fragments: [String: String]
    /// Appended last. The part of this use case's job that never varies.
    let tail: String
    /// The three complements shipped alongside the built button.
    let complements: [OnboardingButtonSpec]
    /// Offline practice examples, keyed by the selected ids that materially
    /// change the result (for example "language.en|tone.casual").
    let practice: [String: OnboardingGeneratedPractice]
}
```

The final prompt is `slotOrder.compactMap { fragments["\($0).\(chosenChipId)"] }.joined(separator: "") + tail`.
Write fragments so they concatenate into grammatical Japanese in that order.

`OnboardingGeneratedPractice(buttonTitle:input:outputs:)` already exists in
`Sources/KeyboardPreferences/UserPrompts.swift`. Use `buttonTitle: ""` — the builder overwrites it
with the user's chosen name. `outputs` must be **exactly 3**, and must obey the button
(if the button strips keigo, none of the three may use keigo).

Key practice examples only by selections that materially change what can be demonstrated offline:

- `keigo`: `politeness.<id>`
- `casual`: `casualness.<id>`
- `email`: `format.<id>|length.<id>`
- `translate`: `language.<id>|tone.<id>`
- `proofread`: `scope.<id>|preservation.<id>`
- `summarize`: `format.<id>|length.<id>`

## 6. The exact slots to fill

Chip ids and labels are already in `OnboardingButtonBuilder.swift`. Reproduced here so you can work
from one document.

Every `other` chip reveals a required inline field for that question. Typed answers go through the
model path; the authored `other` fragment is only its fail-open fallback. Translation-language
`other` has no valid templated fallback because the target language cannot be inferred.

### 6.1 `keigo` — 敬語に整える
| group | chip ids (label) |
|---|---|
| `audience` | `bossTeacher` 上司・先生 · `client` 取引先 · `customer` お客さま · `senior` 先輩・目上 · `other` その他 |
| `channel` | `chat` チャット・LINE · `email` メール · `document` 文書・案内 · `other` その他 |
| `politeness` | `natural` 自然な丁寧語 · `business` ビジネス敬語 · `formal` かなりかしこまる · `other` その他 |

### 6.2 `casual` — カジュアル・フレンドリー
| group | chip ids (label) |
|---|---|
| `channel` | `lineDM` LINE・DM · `groupChat` グループチャット · `socialPost` SNS投稿 · `comment` コメント・返信 · `other` その他 |
| `casualness` | `soft` 丁寧さを少し残す · `natural` 自然で親しみやすい · `veryCasual` かなりくだける · `other` その他 |

### 6.3 `email` — メール・ビジネス文書
| group | chip ids (label) |
|---|---|
| `recipient` | `internal` 社内の人 · `boss` 上司 · `client` 取引先 · `customer` お客さま · `other` その他 |
| `format` | `body` 本文だけ · `complete` あいさつ・結びも入れる · `subject` 件名から整える · `other` その他 |
| `length` | `concise` 簡潔 · `standard` 標準 · `detailed` 丁寧に詳しく · `other` その他 |

Do not ask whether this particular email is a request, report, apology, or thanks. That changes from
message to message and is visible in the source text; the rewrite model should infer it.

### 6.4 `translate` — 翻訳する
| group | chip ids (label) |
|---|---|
| `language` | `en` 英語 · `zh` 中国語 · `ko` 韓国語 · `other` その他 |
| `style` | `natural` 自然な現地表現 · `balanced` 原文とのバランス · `faithful` 原文に忠実 · `other` その他 |
| `tone` | `casual` カジュアル · `polite` 丁寧 · `business` ビジネス · `other` その他 |

Practice `outputs` here must be **in the target language**. The Chinese target is explicitly
Simplified Chinese; plain 「中国語」 leaves the required script unresolved.

### 6.5 `proofread` — 日本語をチェック・添削
| group | chip ids (label) |
|---|---|
| `scope` | `typos` 誤字・文法だけ · `natural` 不自然な表現も直す · `rewrite` 全体を自然に書き直す · `other` その他 |
| `preservation` | `keep` できるだけ残す · `balanced` ある程度残す · `natural` 自然さを最優先 · `other` その他 |

### 6.6 `summarize` — 要約・わかりやすく
| group | chip ids (label) |
|---|---|
| `format` | `paragraph` 短い文章 · `bullets` 箇条書き · `points` 要点リスト · `other` その他 |
| `length` | `slightly` 少し短く · `very` かなり短く · `oneSentence` 一文だけ · `other` その他 |

## 7. Worked example

For `keigo` + `bossTeacher` + `chat` + `formal`:

```
✗ BAD  (repeats the system prompt, uses adjectives, too long)
「次の文章を、上司に送るビジネスメールとして適切な、丁寧で失礼のない敬語に書き直してください。
  原文の意味や意図は変えず、固有名詞や日付はそのまま保ってください。出力は書き直した文章だけに
  してください。」

✓ GOOD (differentiator only, behavioural, concatenates cleanly)
fragments["audience.bossTeacher"] = "上司や先生に送る文章として、"
fragments["channel.chat"]         = "チャットで読みやすい短い文にし、"
fragments["politeness.formal"]    = "文末を「〜いたします／〜申し上げます」調にし、依頼や断りには前置きを添える。"
tail                               = "誤った二重敬語は避ける。"

→ 「上司や先生に送る文章として、チャットで読みやすい短い文にし、文末を
   『〜いたします／〜申し上げます』調にし、依頼や断りには前置きを添える。誤った二重敬語は避ける。」
```

## 8. Deliverable checklist

| Item | Count |
|---|---|
| Slot fragments | 63 (sum of all chips above) |
| `tail` per use case | 6 |
| Complement buttons (title + prompt) | 18 (3 × 6) |
| Practice examples | 42 (3 keigo + 3 casual + 9 each for email/translate/proofread/summarize) |

## 9. How to check your work

1. `xcodebuild -project KeigoButton.xcodeproj -scheme KeigoButton -destination 'platform=iOS Simulator,name=iPhone 17' build`
2. Every title ≤6 characters; authored complement titles should preferably be ≤4 full-width characters.
3. Grep your fragments for the forbidden clauses in §2 — there should be zero hits for
   意味 / 固有名詞 / マークダウン / 出力は / 解説.
4. For each use case, assemble one combination by hand and read it aloud: it must be grammatical
   Japanese, not a list of clauses.
5. Every practice `outputs` array has exactly 3 entries and obeys its own button.

## 10. Context you may want

- `docs/onboarding-button-builder-plan.md` — the full feature plan and why it exists.
- `docs/marketing/gtm/stickiness-diagnosis.md` §2 — the retention evidence behind the builder
  (self-authored buttons: 32% reach 3+ rewrite days vs a 7.2% baseline; presets: 9.3%).
- `supabase/functions/generate-prompt-preset/index.ts` — the model path that stays for free-text
  input. Its system prompt is a good reference for tone and for the same "do not repeat these"
  discipline.
