# Product + data diagnosis — 敬語ボタン, 2026-08-12

All numbers pulled live from Supabase MCP and PostHog MCP (project 465060) on **2026-08-12**,
plus code verification at commit `cb69705`.

**Supersedes for its own claims:** `pmf-diagnosis-2026-08-02.md` (10 days stale; three of its
numbers are corrected here). **Does not supersede:** `metrics-baseline.md` retention-definition-v2
section, which uses a different (harder) denominator and is still valid on its own terms.

---

## 0. Instrumentation confidence assessment — read before the numbers

Overall confidence: **MEDIUM for the AI-rewrite funnel, LOW for anything keyboard-side.**

| Question | Answer | Confidence |
|---|---|---|
| What counts as `ai_rewrite`? | A **successful** server-side rewrite. Emitted only from `captureRewriteAnalytics`, which is called only on `status:"ok"` paths (`index.ts:277`, `:1638`). The `catch` branch console-logs and emits nothing. | HIGH |
| Are failed rewrites separated? | **No — they are invisible.** There is no `ai_rewrite_failed` event. Provider errors, timeouts, usage-guard rejections, and every client-side abort (no Full Access, signed out, no token) produce a Japanese error string and **zero analytics**. | HIGH |
| Can keyboard usage happen unobserved? | **Yes, and it usually does.** The extension emits no analytics by design (`AGENTS.md` §2). `keyboard_usage_day` is accrued in the App Group and flushed by the container on next open (`App.swift:96`), median ~5 days late. A user who types daily and never reopens the container is completely invisible. | HIGH |
| Are container opens meaningful engagement? | Mostly **noise, but small noise.** Measured below: crediting container opens adds only **1–3.5 pt** to W1. It is not the reason retention looks the way it does. | HIGH |
| Can reinstall/login/device changes distort identity? | **Slightly.** `identify` uses a lowercased UUID matching the Edge Function's `distinct_id`, so the old case-mismatch split is fixed. Residual: **54 persons (2.1% of rewriting persons) have server-side events but no client events** — orphaned identities. Merged persons average 2.94 distinct_ids, which is normal. | HIGH |
| Does anonymous pre-signup activity attach correctly? | **Yes.** 2,549 persons carry both client and server events. Install → signup → rewrite chains resolve onto one person. | MEDIUM-HIGH |
| Did app updates affect tracking? | **Yes, materially.** `keyboard_enabled` / `full_access_granted` ship from 1.0.14–1.0.15 (first seen 2026-07-13/07-20); `onboarding_started` from 1.0.15 (07-27); acceptance feedback is version-gated. **No install cohort before ~2026-07-20 can be scored on the enable/Full-Access steps.** Currently-active users are 86% on 1.0.16+, so coverage is now good going forward. | HIGH |
| Important actions we cannot observe | See §7. The big ones: rewrite failures, typing volume, crashes, reply-pill exposure, host app. | HIGH |

**Three specific measurement traps in this dataset:**

1. **`keyboard_usage_day.typed` is a `Bool`, not a count** (`KeyboardUsageDailyStore.swift:11`). There
   is **no typing-volume metric anywhere**. The hypothesis "users keep the AI but type less" is
   structurally unmeasurable today.
2. **Relay lag censors recent weeks.** `keyboard_usage_day` persons read 149 → 128 → 62 → 10 across
   the last four weeks. That decline is mostly flush lag, not churn. Never read the last ~7 days of
   any typing-day series.
3. **`ai_rewrite_events` retains only 30 days** (oldest row now **2026-07-12**). Any Supabase-side
   claim about June/early-July is impossible. PostHog holds full history — use it for anything
   longitudinal.
4. **`payload.locale` on `ai_rewrite` is ~99% `ja`** — it is the keyboard language, not the device
   locale. Do not segment channel or nationality on it. Use PostHog `$locale` only.

---

## 1. Executive diagnosis — ranked

1. **The onboarding change that forced custom-button creation worked mechanically and did nothing
   for activation.** Button creation went **0% → 70%** of onboarding starters. `≥1 rewrite in 48 h`
   went 23.9% → 25.0% (p≈0.83). `≥2 rewrites` went **down** (17.9% → 15.0%). The one metric that
   moved favourably — 2nd rewrite day within 7 d, 6.0% → 9.0% — is not significant (p≈0.34). See §4.

2. **Worse: the same change halved the users' button set and cut command breadth — the strongest
   known retention predictor.** `OnboardingButtonBuilderService.commit` explicitly drops the seeded
   自然に / メール / 英訳. Average buttons per user fell **4.01 → 2.12**; the share of rewriting users
   who ever use 2+ distinct commands fell **25.6% → 16.2%**. Users with 2+ commands on day 0 retain
   at 15.8–21.1% W1 vs 9.8% for one-command users. The change optimised for a correlate and damaged
   a stronger one.

3. **A randomized experiment for exactly this question was built and then archived after 4 users.**
   `archive/onboarding/OnboardingExperiment.swift` implements a clean 50/50 device-hash split with an
   exposure event. It fired for **2 control + 2 builder persons on 2026-08-02** and was moved to
   `archive/` (excluded from builds) in the same commit that shipped the builder to 100%
   (`c45d17b`, 2026-08-04). The causal question is one release away from being answerable and is
   currently unanswerable.

4. **The ~20% retention metric is roughly right in magnitude but wrong in composition.** Anchored on
   first successful rewrite: rewrite-only W1 is **9.4–16.0%**; any-product W1 is **13.7–25.3%**.
   Container-only returns are **0.1–3.5 pt**. So the headline was **overstating true product usage by
   ~1.3–1.7×**, and the inflation comes from crediting typing days and app opens — not from a broken
   definition.

5. **The product works extremely well for ~16 people.** Users active 7+ days in 30 days: **16 users
   (2.2% of monthly actives) generating 24.5% of all rewrite volume**, at **70.3% acceptance**, with
   **59.7% of their volume on self-authored custom prompts** and only 18.9% on `polite`. They are a
   different product's users.

6. **Refinement is a failure signal, and it is now unambiguous.** Share of volume that is a
   refinement falls monotonically with stickiness: **29.1%** (1-day users) → 23.4% → 19.6% → 6.6% →
   **5.6%** (7+ day users). Churning users are the ones who keep asking for another try.

7. **There is no free-text per-request instruction, and this is a real ceiling.** `RefinementIntent`
   is a closed 3-case enum (より丁寧に / より詳しく / より短く). "Make this slightly softer" is partly
   served by the fixed candidate ladder (candidate 2 is "Softer"); **"keep this part unchanged" has no
   expression at all** except manually selecting a fragment. Your pain point #3 is confirmed as a
   capability gap, not a discoverability gap.

8. **Acquisition quality is not the dominant problem.** No self-reported source separates meaningfully
   (W1 range 6–18%, mostly n<60), and 1,836 of ~2,400 attributed users sit in `other`/no-answer
   because neither "App Store" nor "RED/小紅書" is a survey option. Critically, the highest-intent
   proxy available — `google` (i.e. searched for a solution) — retains at **10.9% W1**, no better than
   average. **Even high-intent users fail to retain.**

9. **The toolbar does cost real suggestion-bar width, permanently.** On a 393 pt device the AI chrome
   consumes ~119 pt (**~30%**) in the default state, and ~193 pt (**~49%**) when the reply pill is
   showing. This applies on every keystroke whether or not AI is used. See §6/H3.

10. **Growth is decaying and AI WAU is falling faster than installs.** Signups **8.6/day** last 7 d
    (was ~21/day on 08-02). AI WAU **163**, down from 209 the prior week (**−22% WoW**) and 246 on
    08-02.

---

## 2. Funnel

Install-anchored, one row per person, 14-day observation window, cohorts with ≥14 days maturity.
PostHog `execute-sql`; methodology in §9.

| Install week | Installs | Signed up | Onboarding done | Keyboard enabled | Full Access | Any typing day | Tried rewrite | Kept ≥1 | ≥3 rewrites | 2nd rewrite day |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-06-22 | 1,753 | 1,393 (79%) | 1,612 (92%) | n/a | n/a | 93 (5%) | 1,191 (68%) | 233 (13%) | 727 (41%) | 399 (23%) |
| 2026-06-29 | 1,620 | 1,185 (73%) | 1,471 (91%) | n/a | n/a | 164 (10%) | 956 (59%) | 509 (31%) | 649 (40%) | 239 (15%) |
| 2026-07-06 | 213 | 149 (70%) | 175 (82%) | n/a | n/a | 21 (10%) | 101 (47%) | 49 (23%) | 60 (28%) | 26 (12%) |
| 2026-07-13 | 123 | 85 (69%) | 100 (81%) | 8 | 3 | 12 (10%) | 55 (45%) | 31 (25%) | 34 (28%) | 14 (11%) |
| 2026-07-20 | 402 | 200 (**50%**) | 291 (72%) | 235 (58%) | 31 (8%) | 41 (10%) | 75 (**19%**) | 38 (9%) | 55 (14%) | 23 (6%) |
| 2026-07-27 | 135 | 79 (**59%**) | 98 (73%) | 95 (70%) | 32 (24%) | 5 (4%) | 41 (**30%**) | 16 (12%) | 26 (19%) | 12 (9%) |

`n/a` = event did not exist in that app version, not zero.

**Biggest drop-offs, in order:**

- **Install → signup collapsed from 79% to 50–59%** across the interactive-onboarding ships. This is
  new and is the single largest *change* in the funnel. The new flow front-loads onboarding before
  auth (`onboarding_pre_auth_completed`), and `onboarding_completed` now exceeds `signed_up` in every
  recent cohort — people finish onboarding and do not create an account.
- **Install → tried a rewrite fell from 68% to 19–30%.** Partly the same cause, partly the Full-Access
  gate below.
- **Keyboard enabled → Full Access confirmed is the hardest capability gate**: 235 → 31 and 95 → 32.
  (Detection is a floor — it needs a container reopen — so treat "not confirmed" as an upper bound.)
- **Tried → kept** remains the classic leak: 61–75% of triers never keep a single candidate.

**Cannot be measured at all:** "first actual keyboard usage" as distinct from "keyboard enabled".
`keyboard_usage_day` only exists for users who reopen the container, so the 4–10% typing-day column
is a floor of unknown tightness, not a conversion rate.

---

## 3. Retention, three ways

Anchored on each user's **first successful `ai_rewrite`** (= day 0), which is the denominator you
have been quoting. Cohorts require ≥21 days maturity for W1/W2.

### Exact-day and cumulative (rewrite-only, definition A)

| Cohort (first rewrite) | n | D1 | D3 | D7 | D14 | any rewrite D1–7 | any rewrite D1–14 |
|---|---|---|---|---|---|---|---|
| 2026-06-22 | 1,170 | 12.3% | 6.5% | 3.3% | 2.6% | 27.6% | 34.0% |
| 2026-06-29 | 978 | 10.3% | 4.5% | 3.2% | 0.7% | 22.4% | 25.3% |
| 2026-07-06 | 124 | 8.9% | 4.8% | 2.4% | 3.2% | 19.4% | 25.8% |
| 2026-07-13 | 75 | 5.3% | 4.0% | 8.0% | 4.0% | 24.0% | 30.7% |
| 2026-07-20 | 92 | 16.3% | 5.4% | 3.3% | 1.1% | 27.2% | 35.9% |
| 2026-07-27 | 38 | 5.3% | 5.3% | 0.0% | 5.3% | 10.5% | 26.3% |

Exact-day D7/D14 of 1–3% is what you would expect for a punctual utility; the cumulative window is
the honest read for this product shape.

### Weekly buckets — A vs B vs C

W1 = days 7–13, W2 = days 14–20, W4 = days 28–34.

| Cohort | n | **A** rewrite W1 | A W2 | A W4 | **B** any-product W1 | B W2 | B W4 | **C** container-only W1 |
|---|---|---|---|---|---|---|---|---|
| 2026-06-22 | 1,170 | 13.2% | 9.1% | 6.4% | 16.4% | 11.0% | 9.5% | 12 users (1.0%) |
| 2026-06-29 | 978 | 9.4% | 5.7% | 4.4% | 13.7% | 9.1% | 7.2% | 1 user (0.1%) |
| 2026-07-06 | 124 | 10.5% | 11.3% | — | 12.1% | 13.7% | — | 0 (0.0%) |
| 2026-07-13 | 75 | 16.0% | 10.7% | — | 25.3% | 14.7% | — | 0 (0.0%) |
| 2026-07-20 | 57 | 15.8% | 7.0% | — | 22.8% | 14.0% | — | 2 (3.5%) |

**Verdict on the ~20% number: it has been overstating real usage retention, by ~1.3–1.7×, but not
catastrophically and not mainly because of container opens.**

- Container-only returns (C) are **0.1–3.5%** — the "app opens inflate it" worry is essentially wrong.
- The gap between A and B is ~3–9 pt and is split roughly half container opens, half typing-only days.
  Typing-only days are arguably *real* engagement, so B is defensible — but it is not "used the AI".
- The honest headline for "came back and used the AI again a week later" is **~10–16% W1**, best
  estimate **~13%** on the two large cohorts.
- W4/D30 rewrite retention is **4.4–6.4%**, n adequate only for the two June cohorts.

---

## 4. The custom-button experiment: correlation or causation?

### 4.1 When the change shipped

| Date | Version | `onboarding_version` | What changed |
|---|---|---|---|
| 2026-07-27/28 | 1.0.15 → 1.0.16 | `interactive_v1`/`v2` | Interactive onboarding; practice pages; user *edits* prompts (`onboarding_prompts_customized`) |
| **2026-08-04/05** | **1.0.18** | **`interactive_v3`** | **Button builder.** User builds a button from a use case. `OnboardingButtonBuilderService.commit` **drops the seeded 自然に / メール / 英訳** — the user leaves onboarding with only what they built |
| 2026-08-11 | 1.0.19 | `interactive_v3` | (same flow) |

### 4.2 Before/after — the six questions

Anchored on `onboarding_started`, 48 h maturity, PostHog. `interactive_v2` = before, `v3` = after.

| Metric | v2 (before) n=201 | v3 (after) n=100 | Change | Significance |
|---|---|---|---|---|
| 1. Onboarding completion | 51.2% | 46.0% | −5.2 pt | z=0.85, **p≈0.40** |
| Full Access confirmed | 44.8% | 43.0% | −1.8 pt | ns |
| 3. Custom button created | **0.0%** | **70.0%** | **+70 pt** | **p<0.001** |
| Prompts customised (any) | 34.3% | 71.0% | +36.7 pt | p<0.001 |
| 2. ≥1 real rewrite in 48 h | 23.9% | 25.0% | +1.1 pt | z=0.21, **p≈0.83** |
| ≥2 rewrites in 48 h | 17.9% | 15.0% | **−2.9 pt** | ns |
| ≥3 rewrites in 48 h | 14.4% | 12.0% | **−2.4 pt** | ns |
| Kept ≥1 rewrite | 10.9% | 12.0% | +1.1 pt | ns |
| 4/5. 2nd rewrite day within 7 d | 6.0% | 9.0% | +3.0 pt | z=0.96, **p≈0.34** |

Independently reproduced server-side from Supabase, signup-anchored, **equal 3-day windows**
(this removes the maturity bias that makes the newest cohort look worse):

| Signup era | users | tried | ≥2 rewrites | kept | 2+ days | 2+ commands (of triers) |
|---|---|---|---|---|---|---|
| A: legacy preset (07-12…07-27) | 344 | 49.4% | 39.5% | 23.8% | 9.3% | 22.4% |
| B: v2 interactive (07-28…08-04) | 146 | 51.4% | 39.7% | 24.0% | 11.6% | 25.3% |
| C: **v3 builder (08-05+)** | **38** | 55.3% | **28.9%** | 26.3% | **15.8%** | **14.3%** |

### 4.3 Answer

**6. Did we simply force low-intent users to create a button without increasing real value? — On the
evidence available, yes.**

The reasoning is a power argument, not a null-result argument. The correlational claim was large:
custom-prompt users showed ~4.9× rewrite volume and 28.6% reaching 5+ days vs 4.2%. If authoring a
button *caused* that, then moving authoring from ~3% to 70% of starters should have moved the
2nd-rewrite-day rate from 6% toward ~20%. At n=100 treatment that effect would be detectable with
~95% power. **Observed: 9.0%, CI comfortably including no effect.** The large causal effect is
rejected; a small one (a few points) cannot be ruled out and would need the archived RCT to detect.

**And the correlation itself is weaker than reported once the origins are separated properly**
(`user_prompts.origin` now distinguishes `onboarding_builder` / `onboarding_preset` / `user_authored`
/ legacy-null):

| Segment | users | with rewrite | avg rewrites | avg active days | 2+ days | 5+ days | accept |
|---|---|---|---|---|---|---|---|
| Never created a custom button | 3,171 | 655 | 5.2 | 1.80 | **39.2%** | 4.4% | 31.5% |
| Created 1, never used it | 63 | **7** | 6.4 | 1.71 | 57.1% | 0.0% | 41.2% |
| Created 1, used it | 33 | 33 | **25.1** | 2.85 | **30.3%** | 6.1% | 31.3% |
| Created 2+, never used | 29 | **3** | 9.0 | 3.67 | 33.3% | 33.3% (n=1) | 32.6% |
| Created 2+, used | 12 | 12 | 3.8 | 1.50 | 33.3% | 0.0% | 6.3% |
| **Used a custom button 5+ times** | **8** | 8 | 22.6 | 3.25 | **75.0%** | **25.0%** | 39.3% |

Read this carefully:

- The advantage of "created 1, used it" is entirely in **volume** (25.1 vs 5.2 rewrites), not in
  **frequency** — its 2+ active-days rate (30.3%) is *lower* than the never-created group (39.2%).
  Volume is exactly what a heavy user has anyway. This is the signature of selection.
- **92 users created a custom button and only 10 of them ever ran a single rewrite.** That is the
  builder cohort. Creating the button is not the hard part.
- The only genuinely distinct segment is **"used a custom button 5+ times" (n=8)** — 75% at 2+ days,
  25% at 5+ days. But *using* a custom button 5+ times is downstream of already being retained. It is
  a definition of a power user, not a lever.

**Selection bias verdict:** the earlier finding was measuring "heavy users author buttons", and the
intervention tested the reverse arrow and found nothing.

### 4.4 The unintended cost

Because `commit` drops the seeded presets, v3 users leave onboarding with ~2 buttons instead of ~4:

| Signup era | avg buttons | of which built-in | of which custom | % of triers using 2+ commands |
|---|---|---|---|---|
| A legacy | 4.01 | 3.86 | 0.15 | 22.4% |
| B v2 | 3.99 | 3.60 | 0.39 | 25.3% |
| **C v3 builder** | **2.12** | **1.20** | **0.91** | **14.3%** |

And command breadth is a **stronger** predictor than button authorship (§5/§6). Within 08-05+ signups,
builder users use 2+ commands at 6.3% vs 33.3% for non-builder users (n=16/6 — directional only, but
the same sign as the era-level number, which has more n).

**This is the finding I would act on: the change plausibly traded a strong predictor for a weak one.**

---

## 5. Power-user profile

Segments by distinct AI-rewrite days in the last 30 days (Supabase, n=720 active users):

| Segment | users | avg rewrites/user | avg active days | 2+ commands | share of ALL rewrite volume |
|---|---|---|---|---|---|
| 1 day | 438 | 3.1 | 1.00 | 11.0% | 29.7% |
| 2 days | 155 | 5.9 | 2.00 | 23.2% | 20.0% |
| 3–4 days | 93 | 9.5 | 3.27 | 34.4% | 19.5% |
| 5–6 days | 18 | 16.0 | 5.33 | 38.9% | 6.3% |
| **7+ days** | **16** | **69.5** (max 572) | **12.31** | **62.5%** | **24.5%** |

Volume-weighted behavioural profile of the same segments:

| Segment | accept % | % volume on custom prompt | % volume `polite` | % volume refinement | avg input chars | avg latency |
|---|---|---|---|---|---|---|
| 1 day | 23.4% | 9.8% | 80.1% | **29.1%** | 22.4 | 1,745 ms |
| 2 days | 27.9% | 11.1% | 76.2% | 23.4% | 37.0 | 1,804 ms |
| 3–4 days | 31.9% | 3.6% | 84.0% | 19.6% | 31.8 | 1,780 ms |
| 5–6 days | 48.3% | 9.7% | 59.7% | 6.6% | 39.2 | 1,935 ms |
| **7+ days** | **70.3%** | **59.7%** | **18.9%** | **5.6%** | 22.7 | 1,996 ms |

**What most strongly distinguishes a long-term user** — ranked by strength of separation, and
labelled predictor vs plausible cause:

| # | Signal | 1-day → 7+ day | Type |
|---|---|---|---|
| 1 | Acceptance rate | 23.4% → **70.3%** (3.0×) | Predictor; plausibly partly causal (getting a usable answer) |
| 2 | Volume on self-authored prompts | 9.8% → **59.7%** (6.1×) | **Predictor only** — §4 shows forcing it does nothing |
| 3 | Refinement share (inverse) | 29.1% → **5.6%** (0.19×) | Predictor of *failure*; refinement = the first output missed |
| 4 | Escape from `polite` | 80.1% → **18.9%** | Predictor; confounded with placement (`polite` is the only one-tap pill) |
| 5 | Command breadth (2+ commands) | 11.0% → **62.5%** (5.7×) | Strongest *early* predictor (§6) |
| 6 | Latency | 1,745 → 1,996 ms | **Not a discriminator** — power users tolerate *more* latency |
| 7 | Input length | 22.4 → 22.7 chars | **Not a discriminator** |
| 8 | Device locale | no usable signal (see §8) | — |

Notably **latency and input length do not separate the segments at all**, replicating the 08-02
appendix Q4 finding on fresh data.

---

## 6. The aha moment

Anchored on first successful rewrite, ≥14 days maturity, PostHog. Outcome = another rewrite in W1
(days 7–13).

**Day-0 rewrite volume — a weak, gradual signal:**

| Rewrites on day 0 | n | W1 rewrite return | accepted on day 0 | 2+ commands | 2+ sessions |
|---|---|---|---|---|---|
| 1 | 638 | 9.1% | 15.4% | 0.0% | 0.0% |
| 2 | 483 | 9.7% | 23.6% | 10.1% | 3.5% |
| 3 | 373 | 12.3% | 26.3% | 20.6% | 10.5% |
| 4 | 244 | 11.9% | 33.2% | 18.9% | 10.7% |
| 5 | 176 | 14.2% | 27.3% | 33.0% | 20.5% |
| 6+ | 583 | 15.6% | 40.8% | 35.5% | 33.1% |

Only a 1.7× spread across a 6× volume range. **"Do more rewrites on day 1" is a weak aha.**

**Command breadth × acceptance:**

| Distinct commands day 0 | accepted day 0 | n | W1 rewrite return | avg lifetime rewrite days |
|---|---|---|---|---|
| 1 | no | 1,540 | 10.5% | 1.74 |
| 1 | yes | 511 | 11.9% | 1.70 |
| 2 | no | 190 | 15.3% | 2.38 |
| 2 | yes | 103 | 17.5% | 2.43 |
| 3+ | no | 86 | **23.3%** | 2.49 |
| 3+ | yes | 58 | 12.1% | 2.19 |

Day-0 acceptance adds only ~1.5 pt. **Command breadth adds ~6 pt.**

**The smallest behaviour set that separates — breadth × sessions:**

| Day-0 behaviour | n | W1 rewrite return | avg lifetime rewrite days | reach 5+ days |
|---|---|---|---|---|
| 1 command, 1 session | 1,844 | **9.8%** | 1.67 | 3.8% |
| 1 command, 2+ sessions | 216 | 19.0% | 2.25 | 9.7% |
| 2+ commands, 1 session | 342 | 15.8% | 2.15 | 8.8% |
| **2+ commands, 2+ sessions** | **95** | **21.1%** | **3.23** | **17.9%** |

**The aha moment is: use two different commands, in two separate sittings, on day one.**
That group is **2.2× more likely to return in W1 and 4.7× more likely to reach 5+ active days** than
the one-command/one-sitting majority — and it is 3.9% of the population.

"Two separate sittings" matters because it means the user found a *second occasion of need* on their
own, rather than completing a prompted onboarding trial. That is the closest thing in this dataset to
evidence of value realisation.

**This is precisely the behaviour the v3 onboarding made harder**, by shipping users a 2-button
toolbar instead of a 4-button one.

---

## 7. Product-quality hypotheses

### H1 — Keyboard friction — **plausible, and almost entirely unmeasurable**

| Proxy | Status |
|---|---|
| AI usage up while typing declines | **Impossible to measure** — `typed` is a Bool, no volume metric |
| Crashes / exceptions | **No data** — `$exception` has not been seen in 30 days; no crash reporting in the extension |
| Extension memory / jetsam kills | **No data** — a jetsam kill produces no event by construction |
| Keyboard switching behaviour | **No data** |
| Zenzai auto-disable (latency/memory gate fired) | Instrumented (`zenzai_auto_disabled`) but negligible volume |
| Setup/permission abandonment | **Measured, and severe** — keyboard enabled → Full Access confirmed is 235→31 and 95→32 (§2) |
| Qualitative | `churn-signals.md`: keyboard "feel" is the #1 named churn reason, explicitly including the AI button's placement in the candidate bar |

The one hard number: **typing-path latency work landed in 1.0.14 and there is no measurable retention
response to it** (cohorts 07-20 and 07-27 do not separate from 07-06/07-13). But given the
instrumentation, absence of evidence here is genuinely weak evidence of absence.

### H2 — Rewrite trust / output mismatch — **supported, with one correction**

- **Model actually running (last 14 d): `gpt-5.6-terra` / openai on 100% of 1,639 rewrites.** The
  `pmf-diagnosis-2026-08-02.md` claim that 1.0.14 moved to "GPT-Soul" **does not describe production
  today** — either it was reverted or never deployed. Worth settling.
- **Latency: p50 1,883 ms, p95 3,683 ms, mean 2,076 ms.** It never came back down from the July step
  up (~1.2 s → ~2.1 s). But §5 shows power users tolerate *higher* latency, so this is a
  perceived-quality risk, not a demonstrated churn driver.
- **Outcome coverage (30 d): 4,386 rewrites → 1,719 accepted, 921 dismissed, 103 regenerated, 58
  replace_failed, 3,304 with no recorded outcome.** Coverage ≈ **64%**; acceptance of *resolved*
  outcomes ≈ **65%**, naive acceptance 39.2% (47.5% over the last 14 d). **Always publish coverage
  alongside acceptance.**
- **`replace_failed` is 58 events / 1.3% — it is not a hidden bug inflating the gap.** This closes the
  open question in `churn-signals.md`.
- **Refinement runs backwards** (29.1% for one-day users vs 5.6% for power users): users who need a
  second attempt are the ones who leave.
- **Prompt design is sound.** The system prompt is specific and well-constrained; the 3 candidates are
  a deliberate register ladder (Standard / Softer / More polite). So "make it slightly softer" is
  *partly* already served — the user just may not know candidate 2 is always the softer one.
- **The real gap is control.** `RefinementIntent` is a closed enum of 3. There is **no free-text
  follow-up instruction**. "Keep this part unchanged" is expressible only by manually selecting a
  fragment (`systemInstructionsForSelection` exists and is well written, but requires the user to
  discover text selection inside a keyboard).

**Assessment: yes, the lack of per-request instruction plausibly creates a major usability ceiling** —
and the refinement gradient is the empirical fingerprint of it. Users whose first output misses have
exactly three canned escapes, and those users churn.

### H3 — Toolbar opportunity cost — **confirmed structurally**

`AIKeyboardToolbarView.signedInMainBar` lays out, left to right:
`[update pill?] [reply pill?] [main prompt pill] […] [8pt] [divider] [8pt] [CandidateBar]`,
inside `.padding(.horizontal, 6)`.

Pill geometry: `pillLabel` = 14 pt text + 12 pt horizontal padding each side, height 36 pt.

| State | AI chrome consumed | Candidate bar left (393 pt device) |
|---|---|---|
| Default (2-char main pill + …) | ~119 pt (**30%**) | ~274 pt |
| With reply pill visible | ~193 pt (**49%**) | ~200 pt |
| With update pill too | ~267 pt (**68%**) | ~126 pt |

Your intuition is correct and the cost is worse than "two buttons": the reply pill is
context-appearing (`replyAvailable = pasteboard.hasStrings`), so the suggestion bar **changes width
unpredictably** — which is exactly the "手感が変わる" complaint in the churn emails. The native iOS
Japanese keyboard gives 100% of that strip to candidates.

This cost is paid on **every keystroke of every session**, by 100% of users, while the AI is used by a
minority a handful of times. That is the single clearest asymmetry in the product.

---

## 8. Acquisition quality

Retention by self-reported source × device locale, anchored on first rewrite, ≥14 d maturity,
cells with n≥25:

| Source | Locale | n | W1 rewrite | avg rewrite days | avg rewrites | 5+ days |
|---|---|---|---|---|---|---|
| other | en | 1,231 | 12.9% | 1.89 | 6.8 | 6.6% |
| other | zh | 403 | 10.2% | 1.74 | 7.8 | 3.5% |
| other | ja | 202 | 11.4% | 1.61 | 6.4 | 4.0% |
| friend | en | 165 | 13.9% | 1.93 | 7.7 | 6.1% |
| instagram | en | 58 | 12.1% | 1.93 | 7.3 | 8.6% |
| **google** | en | 55 | **10.9%** | 1.93 | 5.9 | 9.1% |
| friend | zh | 48 | 6.2% | 1.60 | 7.2 | 2.1% |
| reddit | en | 36 | 8.3% | **2.89** | **13.6** | 8.3% |
| friend | ja | 33 | 6.1% | 1.42 | 8.6 | 0.0% |
| tiktok | en | 26 | 11.5% | 1.92 | 6.5 | 11.5% |
| twitter | en | 26 | 7.7% | 1.62 | 6.6 | 0.0% |

**Attribution is inadequate — say so rather than reading these.** Reasons: (a) neither "App Store"
nor "RED/小紅書" is a survey option, so 1,433 of these users sit in `other`; (b) TikTok — your main
current channel — has n=26, because the survey predates the channel; (c) `$locale` is a device
setting, not a nationality or channel (`en` dominates everything); (d) `payload.locale` is useless
(99% `ja`).

**What can be said with confidence:**

- **No source separates by more than ~6 pt on W1, and every cell is within noise of ~11%.**
- The **zh vs ja gap does not replicate** on rewrite retention (10.2% vs 11.4%) — the large gap in
  `metrics-baseline.md` was measured on `keyboard_usage_day`, which undercounts differently by
  segment. zh is still worst on 5+ days (3.5% vs 4.0–6.6%).
- **`google` — the closest available proxy for "actively searched for this problem" — retains at
  10.9% W1, below the `other` average.**

**Answer to your framing: this is not "a good product receiving low-quality installs". Our
highest-intent identifiable users fail to retain at essentially the same rate as everyone else.**
That points the diagnosis at the product, not the channel.

---

## 9. Reproducibility

All PostHog queries run via `mcp__posthog__exec` → `call execute-sql`; Supabase via
`mcp__supabase__execute_sql`.

**Canonical retention (§3):** anchor `d0 = min(toDate(timestamp))` where `event='ai_rewrite'`;
pre-aggregate an `acts` CTE of (person_id, date) with `countIf(event='ai_rewrite')`,
`maxIf(event='keyboard_usage_day')`, `maxIf(event IN ('$screen','Application Opened'))`; join
`fr × acts` on person_id and bucket `dateDiff('day', d0, d)`. **Do not join `fr` directly to raw
`events`** — that intermediate is large enough to fail the query.
A = rewrite; B = rewrite ∪ typing-day ∪ open; C = B ∧ ¬rewrite ∧ ¬typing.

**Before/after (§4.2):** anchor `onboarding_started`, `argMin(properties.onboarding_version)` as era,
join events within `[t0, t0+7d]`, require `t0 <= now() - 48h`. Cross-check signup-anchored in Supabase
with an equal 3-day window and `created_at <= now() - interval '3 days'`.

**Aha moment (§6):** same `acts` CTE plus
`uniqExactIf(toString(properties.command_key), event='ai_rewrite')` and
`uniqExactIf(toStartOfHour(timestamp), event='ai_rewrite')` for day 0; outcome = rewrite at offset
7–13; require `d0 <= today()-14`.

**Code references:** `supabase/functions/keyboard-rewrite/index.ts:277,871,932,1779,1845`;
`iOS/Container/App.swift:96,124,138`; `iOS/Container/UserSession.swift:43`;
`iOS/Container/OnboardingButtonBuilderService.swift:110,131`;
`iOS/KeyboardExtension/AI/AIKeyboardToolbarView.swift:97,414`;
`Sources/JapaneseKeyboardAI/Models/RewriteModels.swift:3`;
`Sources/KeyboardPreferences/KeyboardUsageDailyStore.swift:11`;
`archive/onboarding/OnboardingExperiment.swift`.

---

## 10. Missing instrumentation, ranked by what it blocks

| # | Missing | Blocks | Cost |
|---|---|---|---|
| 1 | **`ai_rewrite_failed`** (provider error, timeout, guard rejection) + client-side abort reasons (no Full Access / signed out / no network) | Separating "AI is bad" from "AI never ran". Today a failed rewrite is indistinguishable from no attempt | Small — one `capture` in the Edge Function catch block; client side needs the App Group relay pattern |
| 2 | **Un-archive `OnboardingExperiment`** | The entire causation question in §4. It is written, tested, and one release away | Trivial — move the file back and call `logExposureIfNeeded()` |
| 3 | **Typing volume** (change `typed: Bool` → keystroke/character count) | H1 entirely: "do AI users type less over time", native-keyboard retreat | Small |
| 4 | **Crash / exception reporting in the extension** | Whether jetsam kills or crashes are a churn cause. Currently zero visibility | Medium — must respect the 40 MB ceiling |
| 5 | **Reply pill `shown` / `tapped` / gate-reason** | Whether reply is an exposure, affordance, or quality problem. Flagged on 08-02, **still not implemented** at 1.0.18 despite the reply-pill work | Small |
| 6 | **Host app bundle id** (LINE / Mail / Slack / X) on `ai_rewrite` | Where the product is actually used — the highest-value missing field for positioning | Small, but a privacy-policy decision |
| 7 | **Acceptance feedback coverage to 100%** | Acceptance is a floor at ~64% coverage; every acceptance comparison is confounded by it | Medium |
| 8 | **Survey options for App Store and RED/小紅書; UTM or App Store campaign attribution** | All of §8 | Small |
| 9 | **Command breadth as a first-class metric** | It is the best early predictor found and nothing tracks it | Trivial (derived) |

---

## 11. Product conclusion

**Primary: B + G, with C as the leading untested hypothesis. Explicitly not E.**

**B — the core product works strongly for a very narrow segment.** 16 users produce 24.5% of all
rewrite volume at 70% acceptance, doing translation and register-shift work on self-authored prompts,
with `polite` at 19% of their usage. That is a real, healthy product — for roughly 2% of monthly
actives, and for a job the app does not advertise, name itself after, or put on a one-tap button.

**G — the evidence is insufficient on the decisive question, and that is itself the finding.** The
question "do users leave because the keyboard is worse than Apple's?" cannot be answered with current
instrumentation: no typing volume, no crash data, no rewrite failures, no keyboard-side events at
all. Every retention number in this document is anchored on the AI, which ~40% of installers never
successfully reach. §10 items 1, 3, 4 are the prerequisite for any confident answer.

**C — value exists but keyboard UX plausibly prevents habit formation** is the best-supported
*untested* hypothesis, on three converging strands: the toolbar demonstrably costs 30–49% of the
suggestion bar on every keystroke (§7/H3); the churn emails name keyboard feel first; and users who
reach the AI's value moment still only return at ~13% W1, which is what you would expect if the
surrounding keyboard is quietly pushing them back to the native one.

**Not E.** Acquisition quality is not the dominant problem: the highest-intent identifiable cohort
retains at 10.9% W1, no better than the average.

**Not A.** Onboarding/activation has been optimised hard for six weeks across four flow versions, and
the activation rate has not moved — while install→signup actually **fell from 79% to ~50–59%** across
those same ships. Continuing to iterate on onboarding is the least promising available direction.

### Previous decisions this contradicts

1. **Forcing custom-button creation in onboarding was not supported by the evidence, and the
   implementation added a second, unexamined change** (dropping the seeded presets) that cut the
   stronger predictor. Recommend: keep the builder, but **stop dropping the seeded buttons** — that
   is a two-line change to `OnboardingButtonBuilderService.commit` and it is directly testable.
2. **Archiving the RCT was the single costliest decision in this dataset.** It converted an answerable
   causal question into an unanswerable one, on the exact intervention that then shipped to 100%.
3. **"Acceptance doubled to 47%"** — still a coverage artifact (coverage 64%; resolved-basis
   acceptance ~65% and roughly flat). Already flagged on 08-02; repeating because 47.5% appears again
   in the last-14-day pull.
4. **"GPT-Soul is the production model"** — not true today; 100% of the last 14 days is
   `gpt-5.6-terra`.

### The three measurements that would change this diagnosis

1. Un-archive the experiment; run builder vs control for 3 weeks (§10 #2).
2. Ship `ai_rewrite_failed` + typing volume; re-run §3 with a keyboard-anchored denominator (§10 #1, #3).
3. A/B the toolbar: default-collapse the AI chrome to a single narrow affordance and measure
   `keyboard_usage_day` frequency + rewrite retention against the current layout. This is the only
   direct test of H3, and H3 is currently the most consequential untested hypothesis in the product.
