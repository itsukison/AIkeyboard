# Retention & user behaviour — 敬語ボタン

**The single evidence doc for how users actually behave.** Owns: funnel, retention, power-user
profile, churner profile, observed failure modes, measurement blind spots, re-pull queries.

Last full pull: **2026-08-13** (PostHog project 465060 + Supabase, live). Code verified at `cb69705`.
Consolidates and replaces `metrics-baseline.md`, `pmf-diagnosis-2026-08-02.md`,
`product-data-diagnosis-2026-08-12.md`, `instruction-model-investigation-2026-08-13.md`,
and the data half of `churn-signals.md`. Hypothesis outcomes live in `hypothesis-ledger.md`.

---

## 0. Read this before any number below

| Question | Answer | Confidence |
|---|---|---|
| What counts as `ai_rewrite`? | A **successful** server-side rewrite only. Emitted from `captureRewriteAnalytics` on `status:"ok"` paths. The `catch` branch emits nothing. | HIGH |
| Are failed rewrites visible? | **No.** There is no `ai_rewrite_failed`. Provider errors, timeouts, usage-guard rejections and every client-side abort are indistinguishable from "never tried". | HIGH |
| Can keyboard usage happen unobserved? | **Yes, and it usually does.** The extension emits no analytics by design. `keyboard_usage_day` accrues in the App Group and flushes on next container open (median ~5 days late). | HIGH |
| Is acceptance fully counted? | **No — 75.5% coverage.** 4,408 rewrites → 1,733 accepted, 1,596 negative, 1,079 (24%) unresolved. Every acceptance figure is a **floor**. | HIGH |
| Does `ai_rewrite_action_events` log successes? | **No.** Only `dismissed` / `regenerated` / `replace_failed` rows exist — zero `selected`/`inserted`/`copied`, despite the schema allowing them. Acceptance is read from `ai_rewrite_events.selected_index`. | HIGH |
| How far back does Supabase go? | **30 days only** (`ai_rewrite_events`, oldest row 2026-07-13). Use PostHog for anything longitudinal. | HIGH |
| Is raw text representative? | **Consent-gated: 1,498 of 4,408 rewrites (34%).** Consent plausibly correlates with engagement, so §4 carries selection risk. | MEDIUM |
| Is `payload.locale` a device locale? | **No** — it is the keyboard language, ~99% `ja`. Never segment nationality or channel on it. Use PostHog `$locale`. | HIGH |

**Three standing traps.** (1) `keyboard_usage_day.typed` is a `Bool`, not a count — there is no
typing-volume metric anywhere. (2) Relay lag censors the last ~7 days of any typing-day series.
(3) `keyboard_enabled` / `full_access_granted` ship from 1.0.14–1.0.15 (first seen 2026-07-13/07-20),
so **no cohort before ~2026-07-20 can be scored on the capability gates**.

---

## 1. Funnel — install to first rewrite

PostHog, install-anchored, one row per person, ≥7 days maturity.

| Install week | Installs | Signed up | Kbd enabled | Full Access | Tried a rewrite | % tried |
|---|---|---|---|---|---|---|
| 2026-06-29 | 615 | 425 | 31* | 26* | 348 | 56.6% |
| 2026-07-06 | 215 | 150 | 13* | 7* | 106 | 49.3% |
| 2026-07-13 | 123 | 85 | 11* | 8* | 55 | 44.7% |
| 2026-07-20 | 403 | 202 | 237 | 36 | 77 | **19.1%** |
| 2026-07-27 | 261 | 144 | 200 | 92 | 82 | 31.4% |
| 2026-08-03 | 98 | 41 | 67 | 36 | 21 | 21.4% |

\* instrumentation not yet shipped — not a real zero.

**Full Access is the binding gate.** Onboarding starters since 2026-07-20, n=244, ≥7d maturity:

| Gate state | Users | Tried a rewrite | Reached 2+ rewrite days |
|---|---|---|---|
| Full Access confirmed | 119 | **50.4%** | 16.8% |
| Keyboard enabled, no Full Access | 83 | **10.8%** | 3.6% |
| Neither | 42 | **0.0%** | 0.0% |

51% of onboarding starters never confirm Full Access, and the cloud rewrite is *impossible* without
it. Note `full_access_granted` requires a container reopen to fire, so the gap is **inflated by
detection bias**. What survives the caveat: 59 of 119 confirmed users still never rewrote (so
confirmation is not purely downstream of usage), and a rewrite needs no reopen, yet only 9 of 83
unconfirmed users managed one.

**Do not attribute the install→signup or install→try decline to any product version.** The drop
landed in the 07-20 install week, *before* interactive onboarding shipped (1.0.15's first
`onboarding_completed` is 07-26), in a week carrying a 3.3× install spike. Acquisition mix is the
better-supported explanation and attribution is too weak to decompose the two.

---

## 2. Retention — flat across every version shipped

PostHog, anchored on each user's **first successful `ai_rewrite`** (= day 0), ≥21 days maturity.

| Cohort | n | 2nd rewrite day ever | W1 (d7–13) | W2 (d14–20) |
|---|---|---|---|---|
| 2026-06-22 | 1,170 | 41.5% | 13.2% | 9.1% |
| 2026-06-29 | 978 | 32.2% | 9.4% | 5.7% |
| 2026-07-06 | 124 | 31.5% | 10.5% | 11.3% |
| 2026-07-13 | 75 | 37.3% | 16.0% | 10.7% |
| 2026-07-20 | 64 | 37.5% | 14.1% | 6.2% |

**Seven weekly cohorts spanning four onboarding versions, and the curve does not move.** This is the
strongest single fact in the dataset: onboarding is not where the retention lever is.

Honest headline for "came back and used the AI a week later": **~10–16% W1, best estimate ~13%** on
the two large cohorts. W4/D30 rewrite retention is 4.4–6.4%. Crediting container opens adds only
**0.1–3.5 pt** — the "app opens inflate retention" worry is essentially wrong.

### Canonical activated-user definition (keep quoting this one)

> **Activated** = kept at least one AI rewrite **and** returned for a 2nd distinct rewrite day. The
> clock starts on that 2nd rewrite day.

On that denominator, retention is **~30% W1 / ~16–18% W2** — not a crisis. There is **no comparable
external benchmark** for this denominator, so never call it top-quartile. The gradient that justifies
the definition (90d, mature cohorts):

| Denominator | n | W1 | W2 |
|---|---|---|---|
| First `ai_rewrite` (≈ completed setup) | 2,287 | 20.4% | 12.9% |
| First accepted rewrite | 804 | 23.3% | 15.0% |
| 2nd distinct rewrite day | 677 | 31.9% | 18.6% |
| **Kept a rewrite + 2nd rewrite day (canonical)** | **333** | **32.1%** | **17.1%** |

**Why "tried a rewrite" is not activation:** 85% of first *real* rewrites happen within 5 minutes of
`onboarding_completed`, and 66% of those never return. The onboarding practice pages are separately
clean — they run locally with canned candidates and emit no `ai_rewrite` at all.

---

## 3. There is no middle class of users

Supabase, 30-day window, n=699 active users / 4,408 rewrites.

| Active rewrite days | Users | % of users | Rewrites | % of volume |
|---|---|---|---|---|
| 1 | 442 | **63.2%** | 1,461 | 33.1% |
| 2 | 140 | 20.0% | 754 | 17.1% |
| 3 | 59 | 8.4% | 540 | 12.3% |
| 4 | 28 | 4.0% | 296 | 6.7% |
| 5–6 | 14 | 2.0% | 272 | 6.2% |
| **7+** | **16** | **2.3%** | **1,085** | **24.6%** |

A single user accounts for **588 rewrites — 13.3% of all volume.** The product either becomes a
near-daily habit or it becomes nothing.

**Return timing** — among the 257 users who reached a 2nd day, days from 1st to 2nd active day:

| 1 day | 2 days | 3 days | 4–7 days | 8–14 days | 15+ days |
|---|---|---|---|---|---|
| 23.0% | 14.0% | 9.3% | 19.5% | 23.7% | 10.5% |

Only 46% return within 3 days; **34% take more than 8 days.** The 30-day window truncates the tail,
so 15+ is undercounted. Consequence: W1 (d7–13) is a poor instrument for this product shape, and the
job does not recur on a reliable daily cadence for most people who do come back.

**Timing of use** — spread across all hours (peak 20:00 and 11:00 JST), with only a mild weekday
tilt (Tue 918 rewrites vs Sun 320 = 35% of peak). This is **not primarily a business-hours work
tool**, which sits awkwardly against the 敬語/business-email positioning.

---

## 4. What the product actually fails at

Raw-text subset, n=1,490 rewrites with input and candidate text (34% of volume, consent-gated).

### Half of all invocations are fired at the wrong text

| Input type | Share | Candidate 1 = input | Accepted |
|---|---|---|---|
| ≤3 chars (fragment / mistap) | 8.7% | 19.4% | 14.7% |
| Short unpunctuated fragment | 16.3% | 9.9% | 19.3% |
| Short **and already polite** | 24.2% | 16.7% | 19.2% |
| Short casual (the legitimate job) | 16.0% | 12.1% | 26.8% |
| 16+ chars (complete message) | 34.8% | **3.7%** | **34.9%** |

Real no-op inputs: 「承知しました」「わかりました」「おはようございます」「よろしいでしょうか？」— already correct
Japanese. And 「ふ」「いい」「いまなんk」 — the last is someone mid-romaji-typing who hit the AI pill
instead of a candidate. This is the tappable-toolbar cost (`CLAUDE.md`) showing up as text.

**This reframes the "polite fails on short inputs" finding.** Two mechanisms are stacked: unstated
recipient context (real — short casual text still accepts at only 26.8% vs 34.9% for long), *and*
invocation targeting (short text is often already fine, or isn't a message).

### Observed defect rates

| Failure mode | Rate | Note |
|---|---|---|
| Candidate 1 byte-identical to input | **10.5%** | "I pressed the button and nothing happened" |
| All three candidates identical to input | 3.5% | Complete dead end |
| All three candidates identical to each other | 6.1% | The 3-candidate promise collapses to 1 |
| Kana input → output with no kana at all | 2.8% | Language flip |
| Output in Korean | 1.3% (19/1,498) | e.g. 「いい写真」→「좋은 사진」 |
| `replace_failed` | 1.3% (58 events) | **Not** a hidden bug inflating the gap |

Acceptance when candidate 1 changed the text: **26.8%**. When it didn't: **14.6%**.

**No-op exposure predicts non-return, and it survives volume control:**

| Day-0 volume | No no-op | Hit a no-op |
|---|---|---|
| 1–2 rewrites | 35.1% (n=74) | 22.2% (n=9) |
| 3–5 | 34.2% (n=38) | **13.6%** (n=22) |
| 6+ | 50.0% (n=18) | 32.0% (n=25) |

Consistent −13 to −21 pt in all three strata. **Not causal:** a user whose text is already polite
gets a no-op *and* plausibly has less underlying need. Both stories fit the data.

### Satisfaction does not rescue retention

Day-0 outcome vs return, new signups with ≥7d observation:

| Day-0 accepts | Users | Returned 2nd day | Still active at d7 |
|---|---|---|---|
| 0 | 141 | 29.8% | 13.5% |
| 1 | 62 | 38.7% | 25.8% |
| 2+ | 39 | 41.0% | 17.9% |

Ending day 0 on an accepted rewrite adds ~+10–14 pt at low volume (32.4→42.9 at 1–2 rewrites,
29.8→43.8 at 3–5). **But ~59% of users the product demonstrably worked for still never come back.**
Any theory of the form "fix output quality and retention follows" has to explain this row.

### Churner burst behaviour

Rewrites grouped into bursts (<5 min gaps), segmented by lifetime active days:

| Segment | Users | Attempts/burst | Bursts w/ refinement | Burst ends accepted |
|---|---|---|---|---|
| 7+ days | 16 | **2.00** | **5.4%** | **84.4%** |
| 5–6 days | 18 | 2.12 | 12.3% | 71.0% |
| 3–4 days | 93 | 2.30 | 21.3% | 58.4% |
| 2 days | 155 | 2.43 | 23.8% | 52.4% |
| **1 day** | 438 | **2.73** | **34.6%** | **44.7%** |

Churners try **harder** and succeed **less**: 37% more attempts per burst, 6.4× the refinement rate,
half the success. On the resolved basis the gradient survives intact (83.3 / 64.1 / 52.9 / 49.8 /
45.7%).

**Refinement rescues nothing.** In every segment with adequate n, refining a burst leaves it *less*
likely to end accepted than not refining (80.0 vs 84.6; 52.9 vs 73.6; 50.0 vs 60.7; 43.8 vs 55.1).
The three canned options (より丁寧に / より詳しく / より短く) are not a working escape hatch.

**Users do not iterate.** Regeneration is 160 events (3.6% of rewrites) on mobile and 5/130 (3.8%)
on desktop. The dominant response to a bad output is dismissal — 1,378 dismissals to 160
regenerations, roughly 9:1 — with a p50 dwell of 6.5s before dismissing (they read it, then reject).

**Confound to keep on the table:** 85% of first rewrites happen within 5 minutes of onboarding, so
some one-day multi-attempt bursts are curiosity, not frustrated intent. This dataset cannot separate
"grinding because it's wrong" from "trying it out".

---

## 5. The 16 power users

Users with ≥7 distinct rewrite days in the 30-day window. **n=16 — hypothesis-generating only, no
population claims.** All 16 were active within the last 8 days; the power cohort is intact.

Geography: 13 JP, 1 SG, 1 CN, 1 US. **14 of 16 have never relayed a typing day** — they live entirely
inside the keyboard, which is why keyboard-side metrics are blind to exactly the users who matter.

### Volume-weighted profile by stickiness

| Segment | Accept % | % volume custom prompt | % volume `polite` | % volume refinement |
|---|---|---|---|---|
| 1 day | 23.4% | 9.8% | 80.1% | **29.1%** |
| 2 days | 27.9% | 11.1% | 76.2% | 23.4% |
| 3–4 days | 31.9% | 3.6% | 84.0% | 19.6% |
| 5–6 days | 48.3% | 9.7% | 59.7% | 6.6% |
| **7+ days** | **70.3%** | 59.7% | 18.9% | **5.6%** |

### Three corrections that matter

1. **`polite` is the most common command among power users, per user.** The 18.9% figure above is
   volume-weighted and dominated by one user. Unweighted: **5 of 16 are 100% `polite`**, 3 more are
   majority-`polite`. **Half the retained cohort sustains a habit on the built-in 敬語 button alone.**
2. **13 of 16 power users have never used a custom prompt.** Two users account for 664 of ~809 total
   custom-prompt uses in the entire product (**82%**).
3. **Latency and input length do not separate the segments at all.** Power users tolerate *more*
   latency (1,996 ms vs 1,745 ms).

### Clusters and jobs-to-be-done

| Job | Users | Evidence |
|---|---|---|
| "Make this polite enough for someone senior" | 8 | 100%-`polite` habits, 22–47 char inputs |
| "Fix my Japanese so it doesn't read as foreign" | 4 | `natural`, 42–62 char inputs |
| "Make my short chat message sound like me, casually" | 2 | 「友達」buttons, 11–16 char inputs, 565+99 uses |
| "Write/soften a work email" | 2 | `email` at 89% and 31% of usage |
| "Translate, keeping terms intact" | 1–2 | 48% non-JA output |
| "Rewrite just this fragment" | 1 | 56% selection usage |

The dominant job by user count is **register control** — polite-enough, casual-enough,
natural-enough. **Categories that did NOT appear:** no reply-generation cluster (reply is 0.8% of
power-segment volume; only 1 of 16 uses it meaningfully), and no highly-customized-workflow cluster.

**One high-information outlier:** a user with 45 rewrites over 7 days at **67% refinement and 7%
acceptance** — the clearest single case of someone trying hard to steer the model and failing. Worth
an interview.

### What the two successful custom prompts encode

Audience/relationship (4/4), register ceiling — "polite but don't overdo it" (3/4), negative
constraints — "don't sound like X" (3/4), channel (2/4), speaker persona (1/4). **Every component is
a *stable* fact**, not a per-message one. The heaviest user ran one unchanged prompt for 565
messages at 0% refinement.

Counter-test: **giving an ordinary user a custom prompt makes short-input performance worse** —
1–2 day users on CUSTOM short inputs accept at **20.0%** vs 42.9% for `polite`. Customization is not
self-evidently good; craft is, and craft does not scale by asking users for it.

---

## 6. Desktop — too small to use, but two schema lessons

`desktop.rewrite_events`: **130 events, 6 users, 2026-08-07 → 08-12.** Nothing conclusive.

Two things mobile should copy:

1. **`status` enum** — `ok` / `provider_error` / `brake_day` / `quota_month`. This *is* the missing
   `ai_rewrite_failed`, already designed and shipping on the other platform.
2. **`host_app_bundle_id`** — the highest-value field mobile lacks.

Note: there is **no per-request instruction field** in the desktop schema. `prompt_origin` only
records saved-prompt provenance (`builtin` / `onboarding_preset` / `user_authored`). If the desktop
app offers free-text-per-rewrite, it is not instrumented — confirm before using desktop as precedent.

---

## 7. Segment and channel reads (both weak — do not steer on them)

**Language segment.** zh-locale is the largest keyboard-active segment (RED-driven) and worst on
`keyboard_usage_day` (W1 15% vs ja 29%; 89% one-and-done vs 75%). **But the gap does not replicate on
rewrite retention** (zh 10.2% vs ja 11.4%) — the original gap was measured on `keyboard_usage_day`,
which undercounts differently by segment. zh remains worst on 5+ days (3.5% vs 4.0–6.6%). Verdict:
acquisition channel, not primary ICP. Intent confound (RED = viral/low-intent, App Store = search/
high-intent) is unresolved.

**Acquisition quality is not the dominant problem.** No self-reported source separates by more than
~6 pt on W1 and every cell sits within noise of ~11%. Critically, **`google` — the closest proxy for
"actively searched for this problem" — retains at 10.9% W1, below the average.** Even high-intent
users fail to retain, which points the diagnosis at the product, not the channel.

**Attribution is inadequate — say so rather than reading it.** Neither "App Store" nor "RED/小紅書" is
a survey option, so 1,836 of ~2,400 attributed users sit in `other`. TikTok — the main current
channel — has n=26 because the survey predates it.

---

## 8. Missing instrumentation, ranked by what it blocks

| # | Missing | Blocks | Cost |
|---|---|---|---|
| 1 | **`ai_rewrite_failed`** + client abort reasons | Separating "AI is bad" from "AI never ran". Copy desktop's `status` enum | Small |
| 2 | **Invocation intent** — `ai_rewrite_invoked` before the network call + `dismissed_within_2s` | Mistaps vs deliberate low-value invocations. Gates the whole toolbar question | Small |
| 3 | **Typing volume** (`typed: Bool` → keystroke count) | Whether AI users retreat to the native keyboard | Small |
| 4 | **Crash / exception reporting in the extension** | Whether jetsam kills cause churn. `$exception` unseen in 30 days | Medium (40 MB ceiling) |
| 5 | **Host app bundle id** on `ai_rewrite` | Where the product is actually used — the highest-value missing field for positioning | Small + privacy decision |
| 6 | **Reply pill `shown` / `tapped`** | Whether reply is an exposure, affordance, or quality problem. Flagged 08-02, still absent at 1.0.18 | Small |
| 7 | **`candidate_scrolled` / candidate dwell** | Whether users ever see candidates 2–3. §4 makes this central | Small |
| 8 | **Acceptance coverage to 100%** | Every acceptance figure is a floor at 75.5% | Medium |
| 9 | **Survey options for App Store and RED; UTM/campaign attribution** | All of §7 | Small |

### What we still cannot know at all

- **Whether churners kept typing.** Measured directly: only 9.2% of churned users show a typing day
  after their last rewrite, but just 10.4% opened the app at all — the typing signal is ~90%
  gated on a container reopen. Among the observable ~10%, most *were* still typing, but that sample
  is unrepresentative by construction. **"Kept the keyboard, dropped the AI" vs "abandoned
  everything" is unanswerable today.**
- **Whether the AI pill is tapped accidentally.** The 8.7% ≤3-char invocations are strongly
  suggestive; nothing distinguishes a deliberate tap from a mistap.
- **First actual keyboard use** as distinct from `keyboard_enabled`.

---

## 9. How to re-pull

PostHog via `mcp__posthog__exec` → `call execute-sql`; Supabase via `mcp__supabase__execute_sql`.

**Retention (§2):** anchor `d0 = min(toDate(timestamp))` where `event='ai_rewrite'`; pre-aggregate an
`acts` CTE of (person_id, date) with `countIf(event='ai_rewrite')`,
`maxIf(event='keyboard_usage_day')`, `maxIf(event IN ('$screen','Application Opened'))`; join
`fr × acts` on person_id and bucket `dateDiff('day', d0, d)`. **Do not join `fr` directly to raw
`events`** — that intermediate is large enough to fail the query. HogQL rejects nesting `maxIf`
inside `countIf`; pre-aggregate, then join.

**Funnel + gates (§1):** one `GROUP BY person_id` scan over
`('Application Installed','signed_up','keyboard_enabled','full_access_granted','ai_rewrite')` with
`countIf` per event, `HAVING` the anchor event, then bucket by `toStartOfWeek(min(timestamp), 1)`.
Require `min(timestamp) <= now() - INTERVAL 7 DAY`.

**Failure modes (§4):** Supabase only, and only where `payload ? 'candidates'`.
No-op = `(payload->'candidates'->0->>'text_redacted') = (payload->>'input_redacted')`.
**`payload.output_length` is the sum across all candidates — it is useless as a no-op proxy**
(validated: 0/157 true no-ops have `input_length = output_length`).

**Cohorting new users (§4, §5):** join `auth.users` on `created_at >= '<window start + 2d>'` and
`created_at <= now() - interval '7 days'` so the first observed rewrite is genuinely the first and
the observation window is complete.

**Saved tiles** (dashboard *Product KPIs — code-aligned (v2)*, `1887280`):
- [Retention — activated users](https://us.posthog.com/project/465060/insights/bOO86jSD) — canonical
- [Value-realization funnel](https://us.posthog.com/project/465060/insights/bhsljVns)

Edit SQL in the tiles, not here, so the dashboard and this doc cannot diverge.

---

## 10. History log

| Date | Users | AI WAU | Activation | W1 (activated) | W2 (activated) | W1 (first-rewrite) | Opt-ins |
|---|---|---|---|---|---|---|---|
| 2026-07-18 | 2,851 | 269 | — | — | — | ~5–18% | 199 |
| 2026-07-30 | — | — | **11.5%** | ~30% | ~16% | — | — |
| 2026-08-12 | 3,210 | 163 | — | — | — | 9.4–16.0% | — |
| 2026-08-13 | 3,318 | — | — | — | — | 9.4–16.0% | 569 |

Signups were 8.6/day over the 7 days to 08-12, down from ~21/day on 08-02. AI WAU 163 on 08-12,
down from 209 the prior week (−22% WoW) and 246 on 08-02. **Growth is decaying and AI WAU is falling
faster than installs.**
