# Metrics Baseline — 敬語ボタン GTM

Last updated: **2026-07-18** (all data pulled live from Supabase + PostHog on this date).
Update cadence: weekly, every Friday. Re-pull with the queries at the bottom.

## Topline (2026-07-18)

| Metric | Value | Source |
|---|---|---|
| Total signed-up users (profiles) | 2,851 | Supabase `profiles` |
| Downloads (user-reported) | ~3,500 | App Store Connect (manual) |
| New users last 7d | 105 (~15/day) | Supabase |
| New users last 30d | 2,842 (≒ everything — app effectively launched 2026-06-22) | Supabase |
| AI-rewrite DAU (trailing week avg) | ~55 | Supabase `ai_rewrite_events` (server-side, reliable) |
| AI-rewrite WAU | 269 (prev week 425, **−37% WoW**) | Supabase |
| Keyboard-usage DAU / WAU | ~12 / ~75 (**undercounted** — reported via container app opens) | PostHog `keyboard_usage_day` |
| Users who ever used AI rewrite | 2,348 / 2,851 (82%) | Supabase |
| AI rewrites last 30d | 14,600 | Supabase |

## Funnel (weekly cohorts, PostHog)

Install → onboarding_completed: **~92%** (e.g. 1,665 → 1,530 wk of 6/21). Onboarding *setup* is not the problem.
Install-week → tried ai_rewrite: **~67–75%**.

**⚠️ Corrected 2026-07-30:** this section used to conclude "activation is not the problem". That was
wrong — it measured *trying* a rewrite, and 85% of first rewrites happen within 5 minutes of
finishing onboarding, so the number is a setup-completion rate. Real activation (value realized) is
**11.5%**. See *Retention definition v2* below.

## Retention — old install-anchored view (superseded 2026-07-30)

**Read *Retention definition v2* below first.** Everything in this section measures retention
against *installs*, which understates it: it charges the product for users who never got the
keyboard working or never realized any value. Kept for history and because the decay shape is
still informative.

- Weekly retention (first `keyboard_usage_day` cohorts): W0→W1 **18%** (Jun 28 cohort: 137→25→10), Jul 5 cohort W1 **4.5%** (88→4).
- AI-rewrite usage-day distribution (all time, n=2,348 AI users): **68% used it exactly 1 day** (1,597), 12% 3+ days (285), **2.9% 5+ days (67)**.
- AI-rewrite DAU decayed from peak 435 (Jun 30) to ~55, roughly stable at 50–67 over the last week → a hard core of ~60–70 real daily users exists.

**Caveat:** `keyboard_usage_day` fires from the container app (extension sends no analytics), so pure-keyboard users who never reopen the container are invisible. True keyboard retention is somewhere between the PostHog curve and the AI-rewrite curve. Also PostHog identity has a known case-mismatch split (see memory: posthog-identity-case-mismatch) that deflates retention.

**Superseded in part on 2026-07-28** — the numbers above were computed while `keyboard_usage_day` was stamped at flush time, which mis-dated every typing day. See *Measurement changes* below; re-pull before quoting these.

## Measurement changes (2026-07-28)

Three fixes landed after an audit of why retention read low and why Firebase read lower still.

**1. `keyboard_usage_day` is now backdated to the day it happened.** The container relays the
extension's App Group tallies on next open — a median of **5 days later**, tail out to the 29-day
retention cap, with only 59 of 1,545 rows arriving same-day. Stamping at flush time collapsed a
month of typing onto whichever day the container was reopened. `App.swift` now passes
`timestamp:` (posthog-ios supports it) built from `properties.date` at **12:00 UTC**, so
`toDate(timestamp)` equals the real day in this UTC-timezone project. Firebase has no timestamp
argument on `logEvent`, so the Google mirror is still stamped at relay time — read keyboard days
in PostHog only.

**2. `keyboard_usage_day` added to the "Active user" action (283102).** Measured effect on W1
retention, recomputing the current definition vs one that credits real typing days:

| cohort week | n | W1 (ai_rewrite + $screen) | W1 incl. typing days |
|---|---|---|---|
| 2026-06-22 | 1,789 | 454 (25.4%) | 491 (**27.4%**) |
| 2026-06-29 | 1,631 | 373 (22.9%) | 413 (**25.3%**) |

**+2.0–2.4 pt, and that is a floor.** 72.3% of flushed typed-days (1,117 / 1,544) had no
`ai_rewrite` and no `$screen` that day — invisible before this change. And only 370 of 4,186
installers ever emitted a `keyboard_usage_day` at all, because the rest never reopened the
container. Users who neither reopen the container nor run a rewrite stay unobservable under any
definition; quote retention as a measured floor, not a point estimate.

**3. Firebase/GA4 is not miscofigured — it is measuring something else.** Checks run: the MP
endpoint, `firebase_app_id`, and `api_secret` are correct and deployed (fn version 39);
`IS_ANALYTICS_ENABLED => false` in `GoogleService-Info.plist` is a red herring (that string does
not appear in the `FirebaseAnalytics` or `GoogleAppMeasurement` binaries — the key the SDK reads
is `FIREBASE_ANALYTICS_COLLECTION_ENABLED`, which is unset, so collection is on). The real
reasons GA4 reads low:

- Firebase entered the project **2026-07-17** and reached users at scale with 1.0.13 on
  **2026-07-20** — there is no cohort older than that, and every existing user who updated fired a
  fresh `first_open`, so the 7/20–7/22 "new user" cohorts are mostly updaters whose D7 has not
  matured.
- **One real bug, now fixed:** the Measurement Protocol payload sent `engagement_time_msec` but no
  `session_id`. GA4 needs both to build an engaged session; without a session the user is absent
  from the retention report. `captureGoogleAnalyticsEvent` now sends a 30-minute-bucketed
  `session_id` (matching GA4's own session timeout).
- Server-side rewrites reach GA4 only when `app_instance_id` is present, which requires the user
  to be on 1.0.13+ *and* to have opened the container since updating. `ai_rewrite` carries no
  `$app_version`, so this coverage gap is not currently measurable.
- GA4's Firebase retention card is app-instance scoped; PostHog merges identities (incl. the
  `$merge_dangerously` backfill), so reinstalls and second devices read as churn in GA4 and as
  retained in PostHog.

**Comparison rule:** GA4 can only ever see container opens plus MP-delivered rewrites. The
apples-to-apples PostHog number is **container-opens-only**, which is W1 **9.6%** (172/1,789, wk of
6/22) and **10.8%** (176/1,631, wk of 6/29) — not the ~25% headline. Treat PostHog as the source of
truth for engagement and Firebase as an attribution tool. Do not read the GA4 retention report
before roughly **2026-08-20**, when 30 days of post-1.0.13 cohorts exist. Note also that
`project.yml` links `FirebaseAnalyticsCore` (no IDFA), which is fine for retention but means no ad
attribution — relevant if Apple Ads spend starts.

## Retention definition v2 — activated users (2026-07-30)

**This is the canonical retention metric. Quote this one.** Install-anchored retention answers
"how many downloaders stick", which for a keyboard is mostly a measure of setup friction, not of
the product. Investor/senior-founder feedback was right: the denominator has to be users who
actually realized the value.

### The definition

> **Activated** = the user **kept at least one AI rewrite** (`ai_rewrite_accepted`) **and came
> back for a 2nd distinct rewrite day**. The retention clock starts on that 2nd rewrite day.
> **Return** = any week with a rewrite, a container open, or a real typing day ("Active user"
> action 283102).

Why these two conditions, and not a softer gate:

- **`ai_rewrite_accepted`, not `ai_rewrite`** — generating a candidate is curiosity; putting it
  into your own text is the value moment. Only **39%** of users who ever ran a rewrite kept one.
- **A 2nd rewrite day** — this is what excludes onboarding. See below.
- Both conditions are satisfied **at or before the anchor day**, so the cohort never borrows
  information from the future. (The first draft of the AI-rewrite tile did: a "≥3 acceptances"
  cohort anchored at the first acceptance is retained by construction and read 45%.)

### Why this excludes onboarding usage

Two separate mechanisms, and only the first one was obvious:

1. **The onboarding practice pages emit no rewrite events at all.** Pages 5–6 of the interactive
   flow (`RewritePracticePage`, `ReplyPracticePage`) run in *practice mode*: the container arms
   `onboardingPracticeActive` in the App Group and `AIKeyboardController.firePractice()` answers
   with locally stored canned candidates — **no network call**. `ai_rewrite` is emitted *only* by
   the `keyboard-rewrite` Edge Function, so a practice tap can never enter any denominator.
   Practice completion is tracked separately as `onboarding_rewrite_practice_completed` /
   `onboarding_reply_practice_completed`. Same for prompts: the onboarding prompt page fires
   `onboarding_prompts_customized`, **not** `prompt_created`.
2. **But the first *real* rewrite is still a prompted trial.** Measured over 60 days: of 2,447
   users with both an `onboarding_completed` and a real rewrite, **2,082 (85%) ran their first
   real rewrite within 5 minutes of finishing onboarding**, and **66% of those never came back for
   a 2nd rewrite day**. So "used AI rewrite ≥1 time" is effectively "completed setup" — it is
   *not* evidence anyone understood the value. This is the real contamination, and requiring a 2nd
   self-initiated rewrite day is what removes it.

### The numbers (pulled 2026-07-30)

Activated-user retention by activation week:

| Activation week | Activated n | W1 | W2 | W4 |
|---|---|---|---|---|
| 2026-06-22 | 18 | 55.6% | 27.8% | 16.7% |
| 2026-06-29 | 226 | 30.5% | 15.9% | — |
| 2026-07-06 | 89 | 31.5% | 18.0% | — |
| 2026-07-13 | 56 | 30.4% | — | — |
| 2026-07-20 | 58 | — | — | — |
| 2026-07-27 | 14 | — | — | — |

`—` = the return window is still open (the tile emits NULL rather than a misleading 0; the current
partial week never counts).

→ **W1 ≈ 30%, W2 ≈ 16–18%.** Remarkably stable across the three cohorts that have a mature W1.
Compare the old install-anchored headline of 5–18%.

**W4 is not yet measurable.** Only the 2026-06-22 cohort has a complete W4 window and it is n=18
(16.7%). Do not quote a W4 number until the 06-29 and 07-06 cohorts mature (from ~2026-08-03).

Gradient across candidate denominators (90d, mature cohorts, activation-anchored) — this is the
evidence for picking the definition above:

| Denominator | n | W1 | W2 |
|---|---|---|---|
| First `ai_rewrite` (≈ "completed setup") | 2,287 | 20.4% | 12.9% |
| First `ai_rewrite_accepted` | 804 | 23.3% | 15.0% |
| 2nd distinct rewrite day | 677 | 31.9% | 18.6% |
| **Kept a rewrite + 2nd rewrite day (canonical)** | **333** | **32.1%** | **17.1%** |

Each step of the gradient both shrinks the denominator and raises retention, which is exactly what
you expect if the gate is really selecting for value realization rather than just for survivors.
(The canonical n reads 333 here but 427 in the funnel below: this table keeps only activation weeks
with a mature W1, while the funnel counts every activated user from an install cohort ≥14 days old.
Different bases, same definition.)

**The reframe this forces:** retention of value-realizing users is not catastrophic, and the crisis
moved one step earlier, to **activation**. Note what this claim does *not* rest on: the benchmarks in
`research/benchmarks.md` (D7 median 12%, top quartile ≥15%) are **install-anchored and therefore not
comparable** to a 30% activated-anchored W1 — there is no external benchmark for this denominator, so
do not claim "top quartile". The evidence is internal: 30% activated vs 5–18% install-anchored on the
same users, plus the funnel below showing where they are actually lost.

| Stage | Users | % of installs |
|---|---|---|
| 1. Installed | 3,710 | 100% |
| 2. Signed up | 2,813 | 75.8% |
| 3. Tried a real rewrite | 2,322 | 62.6% |
| 4. Kept a rewrite (value realized) | 908 | 24.5% |
| 5. **Activated** (kept + 2nd rewrite day) | 427 | **11.5%** |
| 6. Habit (5+ rewrite days) | 103 | 2.8% |

(Install cohorts with ≥14 days of maturity, 90d window.) The dominant leak is **step 3 → 4/5**:
of the users who try a rewrite, 61% never keep one and 65% never come back for a 2nd day. That is
an AI-output-quality and moment-of-need problem, not a setup problem — and it is where Phase 0
effort belongs. The old "82% try the AI, activation is not the problem" reading was measuring
step 3 and calling it activation.

**Caveats.** (a) `ai_rewrite_accepted` requires the app to POST selected-index feedback; coverage
is ~30–38% of rewrites per day and version-gated, so step 4 is a **floor** and will rise as the
feedback endpoint reaches full coverage (`roadmap.md` Phase 0) — re-baseline when it does.
(b) Including container opens in the return signal turns out to matter almost none: W1 is 40.9 /
28.0 / 29.9% with opens vs 39.2 / 27.7 / 29.2% on usage only, so the "$screen inflates retention"
worry is ≤1.7 pt. (c) Weekly activated n is now 55–60, fine for weekly reading; if installs fall
further, switch to trailing-4-week. (d) These SQL pulls do not apply PostHog's
`filterTestAccounts`, unlike the dashboard tiles; the internal-user count is small enough not to
move the percentages.

### Dashboard tiles

On **Product KPIs — code-aligned (v2)** (`1887280`):

- **Retention — activated users (value realized)** (`bOO86jSD`) — canonical, the table above.
- **Value-realization funnel (install → activated)** (`bhsljVns`) — the funnel above.
- **Retention — activated by AI rewrite** (`0rf36ky1`) — was configured `retention_recurring`
  while its description claimed "at least once"; corrected to `retention_first_time` on
  2026-07-30. Keep as the "completed setup" reference line, not the headline.
- **Retention — activated by prompt customization** (`LyeD16EC`) — onboarding-clean
  (`prompt_created` only fires in the Prompts screen) but **n < 10 per week**; power-user signal
  only, never a steerable KPI.

## Retention by segment — language/channel proxy (2026-07-18)

**Finding: the RED/Chinese segment retains ~half as well as Japanese/organic.** Confirms the "JP organic retains better than RedNote" hypothesis. RED has no survey tag, so it is proxied by `zh` device locale (`$locale`); "Japanese/organic" ≈ `ja` locale.

Weekly first-time retention on `keyboard_usage_day` (mature cohort, week of Jun 28 — the only cohort with a complete W1/W2 window):

| Segment ($locale) | W0 | W1 | W2 |
|---|---|---|---|
| ja (Japanese) | 34 | 29% (10) | 15% (5) |
| zh (Chinese / RED-proxy) | 59 | 15% (9) | 5% (3) |

Active-day distribution, 60d (corroborates with larger n):

| $locale | keyboard-active users | % used exactly 1 day |
|---|---|---|
| zh | 140 | 89.3% |
| ja | 68 | 75.0% |
| en | 69 | 73.9% |

→ `zh` is the largest keyboard-active segment (RED-driven volume) but the most one-and-done; `ja` and `en` retain alike and ~2× better than `zh`.

**Caveats (directional, not precise):** (a) locale ≠ channel — no RED/App-Store survey tag exists, so RED is proxied by `zh` locale; (b) `en` locale dominates raw signups (1,707 of the `other` bucket) — many phones are set to English regardless of nationality, so the base is NOT cleanly "majority Japanese"; (c) `keyboard_usage_day` undercounts (fires on container open) and per-cohort n is small; (d) **acquisition-intent confound** — zh≈RED came from a viral video (hype-driven, low intent), ja≈App Store came from search (high intent, active problem). So the gap is partly *intent*, not *segment*: it says "RED is a low-intent channel," NOT "Chinese users don't need keigo." A high-intent Chinese channel (ZH ASO, WeChat search) could retain far better — untested.

## Acquisition mix (self-reported, onboarding survey, June+July)

`other` 2,597, `friend` 323, `google` 132, `instagram` 99, `twitter` 78, `tiktok` 61, `reddit` 58, `newsletter` 41, `youtube` 25. Neither "App Store" nor "RED/小紅書" is a survey option, so both fall into `other`.

**The June spike was RED (小紅書), not App Store (founder-reported, 2026-07-18).** Two viral RED videos (~5,000 likes / ~4,000 saves each) drove the bulk of the launch spike — this reattributes most of the `other` bucket away from the earlier "≈ App Store search" guess. Corroborating: `zh`-locale is the single largest keyboard-active segment (see Retention by segment). App Store organic is the steady ~15/day floor, not the spike source. Friend referral is the #2 visible channel.

## Data asset (the acquisition thesis)

| Metric | Value |
|---|---|
| ai_rewrite_events total | 14,600 |
| …with `selected_index` recorded (preference signal) | 2,472 (17%) |
| …`dataset_eligible = true` | 677 |
| Users opted in to AI improvement | 199 / 2,851 (7%) |
| Users who allowed raw text | **0** |
| ai_rewrite_action_events | 676 |

→ Today the sellable dataset is effectively **~677 metadata-only events from 199 users with zero raw-text consent**. The "RL preference data" asset does not exist yet at meaningful scale; it must be manufactured deliberately (consent UX + selection feedback coverage + retention).

## Interpretation (one paragraph)

**Rewritten 2026-07-30.** The app had a launch spike (~2,600 users in 2 weeks, mostly RED) and gets
users through setup well (76% sign up, 63% try a rewrite). But **only 11.5% of installs ever realize
the value** — 61% of the users who try a rewrite never keep one. The users who do get past that gap
retain at **~30% W1 / ~16–18% W2**, which is respectable for a utility. So this is not primarily a
churn problem: it is a *try → keep* problem sitting one step earlier in the funnel, and it is where
Phase 0 effort belongs. Growth spend before closing that gap would be wasted. There is a real core
of ~60 daily users (103 with 5+ rewrite days) to learn from.

The earlier reading — "converts installs to activated AI users extremely well (82% try the AI), then
loses ~95% within 2 weeks" — was double-wrong: 82% was a setup-completion rate mislabelled as
activation, and the 95% loss was measured against installs rather than against users who had
realized value.

## How to re-pull (paste into Claude Code)

Supabase (`mcp__supabase__execute_sql`):

```sql
-- topline
select
  (select count(*) from profiles) total_users,
  (select count(*) from profiles where created_at > now() - interval '7 days') new_7d,
  (select count(distinct user_id) from ai_rewrite_events where created_at > now() - interval '7 days') ai_wau,
  (select count(distinct user_id) from ai_rewrite_events where created_at between now() - interval '14 days' and now() - interval '7 days') ai_wau_prev,
  (select count(*) from ai_rewrite_events where dataset_eligible) dataset_eligible,
  (select count(*) from user_ai_consent where ai_improvement_opt_in) opt_ins,
  (select count(*) from user_ai_consent where raw_text_allowed) raw_text;

-- daily AI engagement
select created_at::date d, count(distinct user_id) dau, count(*) rewrites
from ai_rewrite_events where created_at > now() - interval '21 days' group by 1 order by 1;
```

PostHog — **canonical retention + activation** (both are saved tiles; just re-run them):

- Activated-user retention → [Retention — activated users (value realized)](https://us.posthog.com/project/465060/insights/bOO86jSD)
- Activation funnel → [Value-realization funnel (install → activated)](https://us.posthog.com/project/465060/insights/bhsljVns)

Or ask Claude to run `insight-query` on `bOO86jSD` and `bhsljVns`. The full SQL lives in those
tiles — edit it there, not here, so the dashboard and the doc can't diverge.

PostHog — old install-anchored retention insight → [saved query link](https://us.posthog.com/project/465060/insights/new#q=%7B%22kind%22%3A%22InsightVizNode%22%2C%22source%22%3A%7B%22dateRange%22%3A%7B%22date_from%22%3A%22-90d%22%7D%2C%22kind%22%3A%22RetentionQuery%22%2C%22properties%22%3A%5B%5D%2C%22retentionFilter%22%3A%7B%22aggregationPropertyType%22%3A%22event%22%2C%22aggregationType%22%3A%22count%22%2C%22cumulative%22%3Afalse%2C%22period%22%3A%22Week%22%2C%22retentionType%22%3A%22retention_first_time%22%2C%22retentionReference%22%3A%22total%22%2C%22returningEntity%22%3A%7B%22id%22%3A%22keyboard_usage_day%22%2C%22name%22%3A%22keyboard_usage_day%22%2C%22type%22%3A%22events%22%7D%2C%22targetEntity%22%3A%7B%22id%22%3A%22keyboard_usage_day%22%2C%22name%22%3A%22keyboard_usage_day%22%2C%22type%22%3A%22events%22%7D%2C%22totalIntervals%22%3A9%7D%7D%7D) — or ask Claude to re-run `query-retention` on `keyboard_usage_day`.

## Release markers (read retention against these)

Ship dates that should visibly move retention/acceptance. When pulling data, segment cohorts **before vs on/after** these dates.

| Date | Version | Change | Hypothesis / what to watch |
|---|---|---|---|
| 2026-07-27 / 07-28 | 1.0.15 (partial) → 1.0.16 | **Interactive onboarding** (`InteractiveOnboardingFlow.swift`): practice pages + user-customized prompts replacing preset buttons. Hypothesis: teaching the rewrite in-flow raises the share of onboarding finishers who actually use it. | Watch **`onboarding_completed` → ≥2 real `ai_rewrite` within 48 h, split by `$locale` × `$app_version`** (locale mix moved zh 65% → 39% across the ship, so an uncontrolled read is meaningless). First honest verdict ~**2026-08-10** (n≈300 completers, ja n≈150). Interim read below. |
| 2026-07-23 | 1.0.14 | (a) backend rewrite model upgraded to **GPT-Soul** (from `gpt-5.6-terra` default per AGENTS.md §4); (b) keyboard **input latency** improved | Targets the two named churn causes directly — AI accuracy (#2) and keyboard feel/latency (#1, `churn-signals.md`). Watch: **W1 retention** on cohorts landing 2026-07-23+ vs prior, and the **58%-never-accept** acceptance rate (772/1,855) which reads faster than W1. First W1 signal ~1 week out, D30 ~4 weeks. |

### Interim read on the interactive onboarding (2026-08-03, 6 days of data — not a verdict)

Metric: persons with `onboarding_completed`, then ≥1 / ≥2 real `ai_rewrite` within 48 h (practice
mode emits no `ai_rewrite`, so it cannot contaminate this). 48 h maturity enforced.

By app version (PostHog):

| version | n | ≥1 | ≥2 |
|---|---|---|---|
| 1.0.12 | 247 | 50.6% | 39.3% |
| 1.0.13 | 220 | 24.1% | 20.9% |
| 1.0.14 | 55 | 38.2% | 32.7% |
| 1.0.15 (new flow, partial) | 101 | 35.6% | 26.7% |
| 1.0.16 (new flow) | 49 | 51.0% | 42.9% |
| 1.0.17 | 11 | 54.5% | 36.4% |

Locale-controlled (≥2 rewrites), which is what the mix shift forces:

| locale | 7/06–7/19 (old) | 7/20–7/27 (old) | 7/28+ (new) |
|---|---|---|---|
| ja | 47.2% (n=106) | 30.4% (n=102) | **45.5% (n=66)** |
| zh | 36.7% (n=166) | 19.6% (n=219) | **20.9% (n=43)** |

→ **Recovery to the early-July level, not a lift.** ja 7/20-week → new flow is significant
(p≈0.03); ja early-July → new flow is not distinguishable; zh barely moved. Pooled new-vs-previous
is inside noise (≥1: z=1.38, p≈0.17). Independently reproduced server-side from Supabase
`ai_rewrite_events` anchored on signup (7/10–7/19 50.7% → 7/20–7/27 35.8% → 7/28+ 41.2%), which
also avoids the PostHog identity case-mismatch.

**The 7/20–7/27 trough is real, not an updater artifact** — 97.3% of 1.0.13 onboarding completers
were fresh installs. Cause unresolved; onboarding completions spiked to 78–94/day (baseline ~15)
on 7/20–7/21, so 【推測】 low-intent traffic influx, but a 1.0.13 regression is not excluded (7/22–7/26
excluding the spike days still reads ~43% vs 66% in early July). **This must be settled — it is the
baseline every future before/after comparison is measured against.**

Also note: Supabase `ai_rewrite_events` only retains data back to **2026-07-03**, so no server-side
June baseline exists. That contradicts `AGENTS.md` §8, which still lists the retention job as
unscheduled — verify which is true before quoting either.

**Pre-ship reference (2026-07-24, day after ship — treat as "before"):** 3,025 users, AI WAU 237, AI DAU 7d-avg ~44. Users only start updating on/after 07-23, so 07-24 metrics are effectively pre-effect.

## History log

`Activation` = installs → activated (kept a rewrite + 2nd rewrite day). `W1 (activated)` and
`W2 (activated)` are the canonical retention numbers; the old install-anchored W1 is kept in its
own column so the series doesn't break at the definition change.

| Date | Users | AI WAU | AI DAU (7d avg) | Activation | W1 (activated) | W2 (activated) | W1 (old, install) | Opt-ins | Dataset-eligible events |
|---|---|---|---|---|---|---|---|---|---|
| 2026-07-18 | 2,851 | 269 | ~55 | — | — | — | ~5–18% | 199 | 677 |
| 2026-07-30 | (not re-pulled) | (not re-pulled) | (not re-pulled) | **11.5%** | **~30%** | **~16%** | — | (not re-pulled) | (not re-pulled) |

**2026-08-03 pull was interactive-onboarding effect only** — see *Interim read on the interactive
onboarding* above and the Full Access gate in `churn-signals.md`. No canonical retention/activation
or Supabase topline numbers were re-pulled, so the row above still stands as the latest.

**2026-07-30 pull was retention-definition work only** — the Supabase topline (users, WAU, DAU,
opt-ins, pairs) was not re-pulled and the 07-18 figures above are 12 days stale. Re-pull the full
row at the next Friday review.
