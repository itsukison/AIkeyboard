# Second-stage investigation — power users, custom prompts, and per-request instructions

敬語ボタン, 2026-08-13. Live pulls from Supabase MCP + PostHog MCP (project 465060), code verified at
`cb69705`. Follows `product-data-diagnosis-2026-08-12.md`.

**Scope caveat, stated once and binding throughout:** the power-user analysis is **n=16**. It is a
qualitative investigation of extreme users, used to generate hypotheses. No causal or population-wide
claim in this document rests on it.

---

## 0. Corrections to the 2026-08-12 report

Three claims from the previous report are wrong or overstated. Correcting them changes the conclusions.

### 0.1 The install→signup decline was NOT caused by onboarding — retracted

The previous report listed "install→signup collapsed 79% → 50–59%" as a leading finding and attributed
it to the interactive-onboarding ships. **The timing falsifies that.**

| Install week | Installs | Signup rate | Onboarding flow live that week |
|---|---|---|---|
| 2026-07-13 | 123 | **69%** | legacy |
| **2026-07-20** | **402** | **50%** | **still legacy** — 1.0.15 first `onboarding_completed` is 07-26 |
| 2026-07-27 | 135 | 59% | interactive_v1/v2 |

**The drop happened in the 07-20 install week, before interactive onboarding shipped.** That week also
carries a 3.3× install spike (402 vs 123) and, per `metrics-baseline.md`, an onboarding-completion
spike to 78–94/day against a ~15/day baseline. A traffic-mix shift is the better-supported
explanation, consistent with Itsuki's note that the large early cohorts were RED/小紅書-driven and
unusually high-intent.

**Revised statement:** install→signup varies with acquisition mix and is not currently attributable to
any product version. Attribution is too weak to decompose the two; do not use this metric to judge
onboarding changes.

### 0.2 "Power users spend only 18.9% of volume on `polite`" — misleading

That figure is **volume-weighted and dominated by one user**. PU-A alone contributes 572 of the
segment's 1,112 rewrites. **Per user, `polite` is the most common command among power users:**

- 5 of 16 are **100% `polite`** (PU-H, L, N, O, P)
- 3 more are majority-`polite` (PU-F 75%, PU-I 63%, PU-M 51%)
- 4 are majority-`natural` (PU-D 97%, PU-G 100%, PU-J 96%, PU-K 77%)
- 1 is majority-`email` (PU-E 89%)
- 2 are majority-custom (PU-A 99%, PU-B 82%)
- 1 mixes polite/email/translate (PU-C)

**Half of the retained cohort sustains a habit on the built-in 敬語 button alone.** The "retained users
escape 敬語" narrative does not survive unweighting.

### 0.3 "Power users: 59.7% of volume on self-authored prompts" — driven by two users

**13 of 16 power users have never used a custom prompt.** PU-A + PU-B account for **664 of ~809 total
custom-prompt uses in the entire product (82%)**. The custom-prompt/retention association reduces to
two individuals.

---

## 1. The 16 power users

Users with ≥7 distinct rewrite days in the retained 30-day event window (2026-07-14 → 08-13).
Anonymized; no PII reproduced.

| # | Days | Rewrites | /day | Sessions | Cmds | %custom | %accept | %refine | %reply | %sel | %non-JA out | Custom buttons | Country |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| PU-A | 31/31 | 572 | 18.5 | 167 | 3 | **99** | **81** | 0 | 0 | 0 | 6 | 1 | JP |
| PU-B | 22 | 121 | 5.5 | 40 | 4 | **82** | **87** | 1 | 0 | 1 | 14 | 1 | JP |
| PU-C | 17 | 64 | 3.8 | 27 | 4 | 0 | 66 | 5 | 6 | 2 | **48** | 0 | JP |
| PU-D | 16 | 32 | 2.0 | 24 | 2 | 0 | 69 | 3 | 0 | 3 | 0 | 0 | JP |
| PU-E | 14 | 54 | 3.9 | 21 | 4 | 0 | 56 | 19 | 0 | 0 | 2 | 0 | JP (zh) |
| PU-F | 11 | 32 | 2.9 | 19 | 2 | 0 | 41 | 0 | 0 | 0 | 0 | 0 | JP |
| PU-G | 11 | 19 | 1.7 | 14 | 1 | 0 | 26 | 11 | 0 | 0 | 0 | 0 | JP |
| PU-H | 10 | 26 | 2.6 | 14 | 1 | 0 | 50 | 23 | 0 | 0 | 0 | 0 | JP |
| PU-I | 10 | 24 | 2.4 | 14 | 3 | 0 | 71 | 4 | **21** | 0 | 0 | 0 | SG |
| PU-J | 10 | 24 | 2.4 | 17 | 2 | 0 | 54 | 0 | 0 | 0 | 0 | 0 | JP |
| PU-K | 9 | 22 | 2.4 | 11 | 2 | **0** | 73 | 0 | 0 | 5 | 0 | **2 (unused)** | JP |
| PU-L | 8 | 24 | 3.0 | 11 | 1 | 0 | 71 | 8 | 0 | 0 | 4 | 0 | JP |
| PU-M | 7 | 45 | 6.4 | 7 | 2 | 0 | **7** | **67** | 0 | 2 | 0 | 0 | CN (zh) |
| PU-N | 7 | 27 | 3.9 | 13 | 1 | 0 | 56 | 11 | 0 | **56** | 0 | 0 | US |
| PU-O | 7 | 13 | 1.9 | 8 | 1 | 0 | 54 | 8 | 0 | 0 | 0 | 0 | JP |
| PU-P | 7 | 13 | 1.9 | 9 | 1 | 0 | 0\* | 0 | 0 | 0 | 0 | 0 | JP |

\* PU-P runs app 1.0.5 only — no acceptance instrumentation. The 0% is a measurement artifact.

Geography: 13 JP, 1 SG, 1 CN, 1 US. Two zh-locale users (PU-E in Japan, PU-M in China). All 16 were
active within the last 8 days — **the power cohort is intact, not decaying.**

**14 of 16 have never relayed a typing day**, meaning they almost never reopen the container app. They
live entirely inside the keyboard. This is why keyboard-side metrics are blind to exactly the users
who matter most.

### Natural clusters

Four clusters appear; two hypothesized categories do **not**.

**Cluster 1 — Personalized casual-chat rewriter (PU-A, PU-B). n=2, but 62% of the segment's volume.**
Both authored a button literally titled **「友達」**. Very short inputs (11–16 chars), very high
acceptance (81–87%), near-zero refinement, high daily frequency. PU-A ran the same button 565 times in
31 consecutive days. This is the most successful usage pattern in the product — and it is the
*opposite* of 敬語.

**Cluster 2 — 敬語/business single-button habit (PU-H, L, N, O, P, F, I, M). n=8.**
Sustain on `polite` (often 100% of usage) at 1.9–3.9 rewrites/day and 41–71% acceptance. Modest
volume, real recurrence. **This cluster is the evidence that the 敬語 wedge does retain some people.**

**Cluster 3 — "natural Japanese" polishers (PU-D, G, J, K). n=4.**
Majority `natural`, longer inputs (42–62 chars), 26–73% acceptance. Reads as non-native or
uncertain-register writers cleaning up their own Japanese.

**Cluster 4 — Multi-tool / cross-language (PU-C, PU-E, PU-B partly). n=2–3.**
PU-C: 47% polite / 31% email / 16% translate / 6% reply, 48% non-JA output. PU-E: 89% email.

**Categories that did NOT appear:**
- **No reply-generation cluster.** Only PU-I uses reply meaningfully (21%); reply is ≤6% for everyone
  else and 0.8% of power-segment volume.
- **No "highly customized workflow" cluster.** Only 3 of 16 have custom buttons at all, and one of
  those (PU-K) never uses theirs.
- **One genuine outlier: PU-M.** 45 rewrites over 7 days, **67% refinement rate, 7% acceptance.** A
  high-effort, high-failure user — the clearest single case of someone trying hard to steer the model
  and failing. Notably zh-locale in China, average input 102 chars on `email`.

---

## 2. Jobs-to-be-done

| Job | Users | Evidence |
|---|---|---|
| **"Make my short chat message sound like me, casually"** | 2 (PU-A, B) | 「友達」buttons, 11–16 char inputs, LINE-register prompts, 565+99 uses |
| **"Make this polite enough to send to someone senior"** | 8 | 100%-`polite` habits, 22–47 char inputs |
| **"Fix my Japanese so it doesn't read as foreign/awkward"** | 4 | `natural`, 42–62 char inputs, one explicit EN→JA translation button |
| **"Write/soften a work email"** | 2 | `email` at 89% and 31% of usage, 24–102 char inputs |
| **"Translate, keeping terms intact"** | 1–2 | 48% non-JA output; PU-K's 和訳 button preserves proper nouns |
| **"Rewrite just this fragment"** | 1 | PU-N, 56% selection usage |

The dominant job by user count is **register control** — polite-enough, casual-enough,
natural-enough. Translation and reply are minority jobs. That is a narrower and more coherent product
than "AI keyboard".

---

## 3. What the self-authored prompts actually do

Only 4 rich self-authored prompts exist among the 16. Decomposed by instruction component
(paraphrased, not reproduced):

| Component | PU-A (28 ch) | PU-B (243 ch) | PU-K カジュアル (335 ch) | PU-K 和訳 (325 ch) |
|---|---|---|---|---|
| Transformation | casual chat | natural JA | casual LINE JA | EN→JA |
| **Channel** (LINE/messages) | — | ✓ | ✓ | — |
| **Speaker persona/identity** | — | ✓ *(man living in Osaka; natural Kansai register, not comedic)* | — | — |
| **Audience / relationship** | ✓ friend | ✓ Japanese friends | ✓ friends, *especially women* | ✓ unknown → default politeness |
| **Register ceiling — "don't overdo it"** | — | ✓ *not stiff, not over-polite* | ✓ *not too hard* | ✓ *explicitly forbids heavy keigo forms* |
| **Negative constraints** | — | ✓ no fake dialect | ✓ no gyaru/slang/over-sweet | ✓ no literal-English artifacts |
| **Formatting** | — | — | ✓ emoji guidance, "don't overuse" | — |
| **Preserve X** | — | — | ✓ meaning | ✓ proper nouns / product / company names |
| **Output hygiene** | — | — | ✓ "output only the rewritten text" | ✓ same |

### The categories, with volume

| Category | Users | Approx. usage volume | Reusable or context-dependent? |
|---|---|---|---|
| Audience / relationship | 4/4 | ~800 | **Reusable** if the user writes to one audience |
| Register ceiling ("polite but not too much") | 3/4 | ~700 | **Reusable as a preference**, but the *level* is per-recipient |
| Personality / style preservation (persona) | 1/4 | ~120 | **Reusable** — it is identity |
| Channel/medium | 2/4 | ~700 | **Reusable** |
| Negative constraints ("don't sound like X") | 3/4 | ~700 | **Reusable** |
| Language switching | 1/4 | 0 (never used) | Reusable |
| Preserve specific information | 2/4 | 0–small | **Context-dependent** — the thing to preserve changes per message |
| Formatting (emoji) | 1/4 | 0 (never used) | Reusable |
| Output hygiene | 2/4 | 0 (never used) | Artifact of ChatGPT habits; unnecessary here |

### Answer to the key question

> Are power users creating reusable transformations, or encoding contextual instructions that belong
> at the message level?

**Overwhelmingly the former.** Every one of these prompts encodes *stable* facts — who I am, who I
usually write to, what channel, how far to go. PU-A ran one unchanged for 565 messages. Only one
component ("preserve this specific term") is genuinely per-message, and it generated no measurable
usage.

**This is the single strongest piece of evidence against the free-text hypothesis in its pure form.**
The most successful users in the product solved their problem with a *persistent* instruction, not a
per-request one.

**However** — note *what* they had to encode to succeed. Three of four prompts contain a "be polite but
don't overdo it" clause and a "don't sound artificial" clause. Those are precisely the intentions in
Itsuki's list. The demand is real; the two users who satisfied it did so by paying a large one-time
authoring cost that essentially nobody else pays.

---

## 4. Persistent vs per-request intent — architecture

### How it works today

`RewriteRequest` (`Sources/JapaneseKeyboardAI/Models/RewriteModels.swift:25`) carries `prompt`, `text`,
`replyTo`, `selection` + `selectionContextBefore/After`, `commandKey`, `title`, `refinement`, `locale`,
`appVersion`, `candidateCount`.

The Edge Function's `userPrompt()` (`index.ts:1848`) assembles:

```
Command: <the button's prompt text>        ← persistent instruction
Locale / Candidates requested / App version
[Refinement: <one of 3 canned sentences>]  ← the ONLY per-request control
[<context_before> / <context_after>]       ← selection mode
Target text: <target>
```

**A saved button's prompt text is injected verbatim as the `Command:` line.** There is no separate
channel for anything else.

### The conflation

| | Persistent | Per-request |
|---|---|---|
| Example | "Translate JA→natural American English" | "Keep the first two sentences; make the closing apology lighter" |
| Where it can live today | The button's `prompt` field — full free text, up to `MAX_PROMPT_CHARS` | **Nowhere.** `RefinementIntent` is a closed 3-case enum: `morePolite` / `moreDetailed` / `moreConcise` |
| Interaction cost | One-time authoring in the container app's Prompts screen | n/a |

**Yes, the architecture conflates them — by omission.** It offers a rich, unbounded channel for
persistent intent and a 3-valued channel for per-request intent. Every per-request need must be
squeezed into one of three canned sentences, or into a new saved button, or abandoned.

Two secondary observations:

- **The candidate ladder is a hidden per-request control.** `systemInstructions()` always returns
  Standard / Softer / More-polite. So the product *already* answers "make it softer" — silently, as
  candidate 2. Users must discover this by scrolling the carousel. §5 shows this matters enormously.
- **Adding a per-request field is architecturally trivial.** It is one optional string on
  `RewriteRequest` and one line in `userPrompt()`. **All of the cost is UI and interaction design**, not
  backend.

### Slot placement is a real tax

| Slot | Origin | Buttons | Users | Avg prompt chars | Ever used | Total uses |
|---|---|---|---|---|---|---|
| sub (behind `…`) | self-authored | 100 | 81 | 124 | **20** | 642 |
| main | onboarding_builder | 47 | 47 | **72** | 24 | 96 |
| main | self-authored | 46 | 46 | **189** | 17 | 167 |
| sub | onboarding_builder | 9 | 5 | 71 | 2 | 9 |

**PU-A's 「友達」 button sits in the `sub` slot** — behind the `…` overflow. They tapped through the
overflow **565 times** rather than move it. That is either extreme tolerance or a discoverability
failure in the Prompts screen; either way it says the default slot assignment does not match the
user's actual job.

**And builder-generated buttons are thin.** `OnboardingButtonBuilderService.templated()` assembles them
from **fixed authored fragments** with no network call; the model is invoked only for free-text/その他.
Result: 72 chars average, versus 189 for self-authored main-slot and 243–335 for the prompts that
actually work. **The v3 "custom button" is much closer to the old onboarding presets — which the
08-02 analysis showed do nothing — than to the prompts that mark power users.** This is a mechanistic
explanation for why the button-builder intervention moved nothing.

---

## 5. Churner behaviour — the strongest evidence in this investigation

Rewrites grouped into **bursts** (consecutive rewrites by one user with <5 min gaps), segmented by the
user's lifetime active days.

| Segment | Users | Bursts | Attempts/burst | ≥2 attempts | ≥4 attempts | Bursts w/ refinement | **Burst ends accepted** | Accept when refined | Accept without refining |
|---|---|---|---|---|---|---|---|---|---|
| 7+ days | 16 | 557 | **2.00** | 41.8% | 11.0% | **5.4%** | **84.4%** | 80.0% | 84.6% |
| 5–6 days | 18 | 138 | 2.12 | 41.3% | 15.9% | 12.3% | 71.0% | 52.9% | 73.6% |
| 3–4 days | 93 | 385 | 2.30 | 48.1% | 15.6% | 21.3% | 58.4% | 50.0% | 60.7% |
| 2 days | 155 | 374 | 2.43 | 49.5% | 15.5% | 23.8% | 52.4% | 43.8% | 55.1% |
| **1 day** | 438 | 494 | **2.73** | **56.3%** | **23.7%** | **34.6%** | **44.7%** | 45.6% | 44.3% |

### Answer to the central question

> Are churned users less interested in customization, or trying harder to get the AI to understand
> them and failing?

**Trying harder and failing.** One-day users make **37% more attempts per burst**, refine **6.4× more
often**, and are **23.7%** likely to grind through 4+ attempts — yet their burst ends in an accepted
rewrite only **44.7%** of the time versus **84.4%** for power users. Effort is inversely correlated
with success.

### And refinement does not rescue anything

In every segment with adequate n, **refining a burst leaves it *less* likely to end in acceptance**
than not refining (80.0 vs 84.6; 52.9 vs 73.6; 50.0 vs 60.7; 43.8 vs 55.1). For one-day users it is a
wash (45.6 vs 44.3).

The three canned refinements are not a working escape hatch. Whatever users need after a miss, "より丁寧に
/ より詳しく / より短く" is not it.

### Validating that this isn't a tracking artifact

Outcome coverage differs sharply by segment (84.4% for power users → 51.1% for one-day users), so raw
acceptance is confounded. **On the resolved basis the gradient survives intact:** 83.3% / 64.1% / 52.9%
/ 49.8% / **45.7%**. The quality gap is real.

### Confound to keep on the table

85% of first real rewrites occur within 5 minutes of finishing onboarding (`metrics-baseline.md`). Some
one-day multi-attempt bursts are **curiosity and exploration**, not frustrated intent. This dataset
cannot separate "grinding because it's wrong" from "trying it out". That distinction is the single most
important thing the instrumentation cannot currently tell us.

---

## 6. Accepted vs rejected — where the product's boundary actually is

Accept rate **of resolved outcomes**, by command × input length, with user-segment controlled.

| Segment | Command | Input | Resolved | Accept | **% who chose candidate 1** |
|---|---|---|---|---|---|
| 7+ days | polite | 1–15 ch | 42 | 69.0% | 75.9% |
| 7+ days | polite | 16+ ch | 95 | 69.5% | 71.2% |
| 7+ days | other built-in | 1–15 | 80 | 83.8% | 82.1% |
| 7+ days | CUSTOM | 1–15 | 401 | **86.8%** | **92.0%** |
| 3–6 days | polite | 1–15 | 188 | **42.0%** | 55.7% |
| 3–6 days | polite | 16+ | 381 | 61.2% | 65.7% |
| **1–2 days** | **polite** | **1–15** | **492** | **42.9%** | **48.8%** |
| 1–2 days | polite | 16+ | 417 | 57.1% | 63.4% |
| 1–2 days | CUSTOM | 1–15 | 45 | **20.0%** | 77.8% |
| 1–2 days | other built-in | 1–15 | 97 | 35.1% | 58.8% |

### What it reliably satisfies

- A **personalized custom prompt on a short message**: 86.8% accepted, 92% on the first candidate. The
  best-performing cell in the product — but 100% of it is PU-A and PU-B.
- **Longer inputs generally.** `polite` on 16+ chars beats `polite` on 1–15 chars in every segment
  (+14 pt for churners, +19 pt for mid users).

### What it systematically fails at

**`polite` on a very short message.** For 1–2 day users this is **492 resolved outcomes — the single
largest cell in the dataset — and it accepts at 42.9%.** When it *is* accepted, only **48.8% take the
standard candidate**: more than half the time the user has to hunt to candidate 2 or 3 for the right
register.

### The mechanism

A 10-character Japanese message ("遅れます", "了解しました", "ありがとう") contains almost no information about the
correct politeness level. That depends on **who the recipient is and how close you are** — facts that
exist only in the user's head and are transmitted nowhere. **The shorter the message, the more the
right answer depends on unstated context.**

That is why:
- short inputs fail more than long ones;
- the candidate-1 rate falls monotonically as user maturity falls (75.9% → 55.7% → 48.8%);
- PU-A and PU-B succeed at 87% on 11–16 character inputs — they pre-loaded the missing context into
  their button.

**The product boundary is a context boundary, not a model-quality boundary.**

### Critical counter-test: does giving an ordinary user a custom prompt help?

**No — it makes short-input performance worse.** For 1–2 day users, CUSTOM on short inputs accepts at
**20.0%** versus 42.9% for `polite`. And outside PU-A/PU-B there is **no evidence that longer custom
prompts perform better** (accept-of-resolved by prompt length: 47.7% / 49.4% / 22.6% / — across
<60 / 60–119 / 120–219 / 220+ chars; n = 44 / 83 / 31 / 1 resolved — too small to conclude either way,
but certainly not supportive).

**Customization is not self-evidently good. Craft is. And craft does not scale by asking users for it.**

---

## 7. Evidence for and against free-text per-request instructions

### For

1. **Churners grind and fail.** 2.73 attempts/burst, 34.6% refinement rate, 44.7% success vs 84.4%.
   They are trying to steer and cannot.
2. **The existing escape hatch demonstrably does not work.** Refining leaves a burst *less* likely to
   end accepted in 4 of 5 segments. A closed 3-option set is not expressive enough.
3. **Register intent is unstated and message-specific.** Only 48.8% of churners' accepted
   `polite`-short outputs are the standard candidate. The correct register is a coin flip and is
   currently guessed, never specified.
4. **The failure concentrates exactly where context is missing** — short messages, where the recipient
   relationship carries all the information.
5. **The successful users' prompts are made of precisely the missing information** — audience,
   relationship, channel, persona, register ceiling, negative constraints. Three of four contain a
   literal "be polite but don't overdo it" clause, matching Itsuki's examples almost word for word.
6. **Backend cost is near-zero.** One optional string on `RewriteRequest`, one line in `userPrompt()`.

### Against

1. **The two most successful users solved it persistently, not per-request.** PU-A: one unchanged
   button, 565 uses, 0% refinement. If per-message steering were the winning behaviour, the best users
   would exhibit it. **They exhibit the opposite** — refinement falls to near zero as users succeed.
2. **Giving ordinary users prompt control backfired.** CUSTOM on short inputs: 20.0% accept for
   churners vs 42.9% for `polite`.
3. **Users do not return to their own configuration.** 63% of self-authored buttons were **never used
   once**; only ~11% were ever edited.
4. **Users do not iterate.** Regeneration is 1.7–2.9% in every segment. The dominant response to a bad
   output is `dismissed` (≈24%) and leaving — not another attempt.
5. **Typing an instruction competes with just fixing the text yourself.** Inside a keyboard, at
   11–47 characters of input, the instruction may cost more keystrokes than the edit.
6. **The 08-02 appendix already weakly falsified "more command choice → better D7"** (`polite` 25.5%
   vs `natural` 22.1%). More control has not previously converted into retention.
7. **It is the ChatGPT interaction.** The product's stated advantage is not leaving the app you are
   typing in; a free-text prompt box re-imports the thing users already have elsewhere.

### Synthesis

The **context deficit is well evidenced**. The claim that **free-text per-request instruction is the
right remedy is not**. The same evidence supports a cheaper remedy the product has never tried:
**capture the persistent context once, so candidate 1 is right more often**, which is exactly what the
only two highly successful users did by hand.

Free text is best supported as a **repair tool for the tail** — replacing the 3 canned refinements
after a miss — not as the primary interaction.

---

## 8. Product positioning implication

| Candidate positioning | Verdict |
|---|---|
| 敬語 utility | **Partly right, under-credited.** 8 of 16 power users sustain on `polite`. It is a real job; it is also the worst-performing command on short inputs |
| Preset rewriting keyboard | **This is what it is today**, and it is the shape the best user's behaviour takes (one button, 565 taps) |
| Customizable AI keyboard | **Not supported.** 13/16 power users never made a button; 63% of made buttons are never used; forcing creation moved nothing |
| Contextual AI writing assistant | **Not supported by behaviour.** Regeneration 2%, refinement falls with expertise, editing rate 11% |
| **Personalized one-tap rewriter** | **Best supported.** The winning pattern is one button, tapped many times, whose transformation has been fitted to *this user's* voice and audience |

### Part 8 — is 敬語 the wedge or a trap? Ranked

1. **E — Placement bias. Strongly supported.** `polite` is provisioned to 3,112 of 3,210 users and is
   the only one-tap pill; everything else sits behind `…`. Its 71% volume share is an artifact of
   placement, and it is the worst-performing cell in the product (42.9% on short inputs).
2. **B — The polite transformation isn't good enough. Supported, but specifically for short inputs**
   (42.9% vs 57.1% on longer). This is a context problem, not a model problem.
3. **D — Wrong mental model. Partly supported.** The two heaviest users in the product built buttons
   called 「友達」 and use them for casual chat — the opposite of keigo.
4. **C — Good wedge, retained users expand. Weakened by this investigation.** 5 of 16 power users are
   100% `polite`. Retained users do *not* reliably expand.
5. **A — Keigo isn't frequent enough. Weakly supported.** Several users sustain 1.9–3.9 keigo rewrites
   per day for weeks. Frequency can be sufficient.

**Not a trap — but mis-served.** The 敬語 button is doing the highest-volume job with the least context.

---

## 9. Recommended interaction model — ranked

| Rank | Approach | Interaction cost | Keyboard space | Likely 1st-attempt gain | Casual users | Power users | ChatGPT-like? | Impl. |
|---|---|---|---|---|---|---|---|---|
| **1** | **E′ — "Context once, not every time."** Capture persistent register context (who you usually write to, how far to go, your voice) once, inject into every rewrite | **Zero per message** | **Zero** | **High** — directly attacks candidate-1-wrong-half-the-time | High | High | No | Low–med |
| **2** | **D/B — optional free-text note, offered *after* the first output**, replacing the 3 canned refinements | Zero on the happy path; one input on a miss | Zero (reuses the refinement row) | Medium–high on the failing tail | Medium | Medium | Slightly | **Low** |
| 3 | B — instruction field always available pre-rewrite but optional | Low but visible | Small | Medium | Low | Medium | Yes | Low |
| 4 | A — every AI tap opens an instruction input | **High** | Medium | Medium | **Low** | **Negative** | Yes | Medium |
| 5 | C — natural language as the primary interaction | Highest | High | Unknown | Very low | Negative | **Yes — this is ChatGPT** | High |

**Why E′ ranks first:** it is the only option with a proven in-product existence proof (PU-A, PU-B at
81–87% acceptance), it costs nothing per message, it consumes no toolbar width — the scarcest resource
per the 08-12 report — and it preserves the one-tap advantage completely.

**Why D ranks second and should ship with it:** the refinement row already exists and already fails.
Replacing three canned options with a free-text field is a small change that touches only the failing
tail, and it will *generate the data* needed to decide whether per-request control matters at all.

**A and C should be rejected on this evidence.** They tax the 84%-success happy path to serve a tail,
and they convert the product into the thing users can already get elsewhere.

---

## 10. Smallest validation experiment

### The power problem, and the way around it

At ~10 signups/day and ~50% trying a rewrite, a conventional retention A/B needs months. **But the
Edge Function can randomize server-side with no App Store release and full existing volume
(~4,500 rewrites/month, ~1,900 resolved outcomes).** Use that first.

### Experiment 1 (ship first — zero client work, ~2 weeks)

**"Does supplying missing context improve first-attempt fit?"**

- **Unit:** rewrite request, hashed on user id (stable per user, so no within-user flip-flop).
- **Control:** current `systemInstructions()` + candidate ladder.
- **Treatment:** identical, but the model is instructed to bias candidate 1 toward the *user's observed
  register history* (their modal accepted `selected_index` over prior rewrites), with the ladder
  otherwise unchanged.
- **Eligibility:** `command_key = 'polite'`, `input_length <= 15`, user has ≥3 prior resolved outcomes.
  This is the largest, worst-performing cell (492 resolved outcomes for 1–2 day users alone).
- **Primary metric:** **candidate-1 selection rate among accepted rewrites** (currently 48.8%).
- **Secondary:** accept-of-resolved; attempts per burst; refinement rate.
- **Guardrail:** latency p95 (currently 3,683 ms); dismissal rate.
- **Ship if:** candidate-1 rate rises ≥10 pt with accept-of-resolved not falling.
- **Reject if:** no movement — that falsifies "the register guess is the problem" and redirects
  everything below.

This tests the *mechanism* (unstated register context) without building any UI, and it is the single
cheapest decisive test available.

### Experiment 2 (only if 1 succeeds — client, ~4 weeks)

**"Does an optional free-text note rescue failed bursts?"**

- **Control:** current 3-option refinement row.
- **Treatment:** refinement row gains a free-text field alongside the 3 chips.
- **Eligibility / exposure event:** `refinement_row_shown` — fires when a result overlay renders. Only
  users who see a first output enter the analysis.
- **Primary metric:** **burst rescue rate** — share of bursts containing ≥1 refinement that end in an
  accepted rewrite. Baseline: 43.8–52.9% for non-power segments, and *below* the no-refine rate.
- **Secondary:** free-text usage rate; attempts per burst; accept-of-resolved; D7 rewrite return.
- **Guardrails:** total time-to-accept; happy-path rewrites unaffected (no change for bursts with no
  refinement); toolbar width unchanged.
- **Sample:** ~500 refined bursts/month exist today. Detecting +12 pt on rescue rate (44% → 56%) at
  80% power needs ~270/arm → **~4–6 weeks**. Retention is *not* powered — treat D7 as directional only.
- **Ship if:** rescue rate rises ≥10 pt **and** free-text is used in ≥25% of refinements.
- **Reject if:** free-text usage <10% — that means users will not type instructions in a keyboard,
  which kills Options A–C outright.

### Required new instrumentation (all cheap, all container/server side)

| Event | Why |
|---|---|
| `ai_rewrite_failed` (+ reason) | Still missing. Without it, "no attempt" and "failed attempt" are indistinguishable |
| `refinement_row_shown` | Exposure denominator for Experiment 2 |
| `refinement_freetext_used` (+ char length, **not content**) | Treatment uptake |
| `candidate_scrolled` / candidate dwell | Whether users *see* candidates 2–3 or never scroll — currently unknowable, and §6 makes it central |
| Host app bundle id | Still the highest-value missing field |

### Qualitative track — run in parallel, do not wait

n=16 is too small for statistics but ideal for interviews, and **all 16 were active in the last 8
days**. Two questions only:

1. To PU-A and PU-B: *what made you write your own button, and what would have made it unnecessary?*
2. To PU-M (67% refinement, 7% acceptance): *what were you trying to get it to do?*

PU-M is the highest-information single user in the dataset — a person who used the product 45 times
across 7 days and almost never got what they wanted.

---

## 11. What we should not conclude

- **n=16 generates hypotheses, not population claims.** Clusters 1 and 4 are n=2–3.
- **Custom-prompt usage remains correlational**, and this investigation *weakened* it further: 82% of
  all custom-prompt usage comes from two people, and giving churners custom prompts made short-input
  acceptance worse.
- **Acceptance is partly a measure of retention, not only a cause of it.** Users who accept become
  power users partly by definition. The length and candidate-index gradients *within* segment are the
  non-tautological findings; the cross-segment acceptance gap is not.
- **Outcome coverage varies 51–84% by segment.** All acceptance figures here are on the resolved basis
  where stated; naive rates are floors.
- **`ai_rewrite_events` retains 30 days.** Nothing here describes June.
- **Acquisition attribution remains too weak** to attribute any funnel movement to a product version
  — including, now explicitly, the install→signup decline (§0.1).
- **Churn interviews (n≈6) remain hypothesis-generating only.**
- **Keyboard friction remains unmeasured**, and 14 of 16 power users never relay a typing day — the
  measurement blind spot is worst exactly where the best users are.

---

## 12. Strategic conclusion

> **What should KeigoButton become?**

**A personalized one-tap rewriter — not a contextual AI writing assistant.**

The behaviour of the best users is unambiguous: one button, tapped hundreds of times, at 81–87%
acceptance, with **zero** refinement. Nobody in this dataset behaves like an agent user. Regeneration
is 2%, refinement *falls* as users succeed, and 63% of the buttons people make are never used again.
The product's advantage is that it removes a decision, not that it accepts instructions.

What is broken is not the interaction model — it is that **the one tap is currently under-informed.**
`polite` fired at a 10-character message is the most common request in the product and the one it most
reliably fails, because the information that determines the right answer — who you are writing to and
how close you are — is never transmitted. Two users fixed this by hand-writing a paragraph of context
into a button, and they became the two heaviest users in the product.

**So the answer to the free-text question is: partly wrong, and right about the underlying problem.**
The diagnosis — that intent is under-specified and message-specific — is correct and well evidenced.
The proposed remedy inverts the cost structure of the only interaction that has been shown to work.
Ship the context **once**, not every message; keep free text as the repair path for the tail, where the
three canned refinements are already provably failing.

**And stop treating "custom button creation" as the goal.** The evidence now says it is neither
necessary (8 of 16 power users are pure-`polite`) nor sufficient (63% of created buttons go unused;
churners given custom prompts do *worse*). What separated PU-A and PU-B was not that they customized —
it was that their button knew who they were.
