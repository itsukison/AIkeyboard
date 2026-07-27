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

Install → onboarding_completed: **~92%** (e.g. 1,665 → 1,530 wk of 6/21). Onboarding is not the problem.
Install-week → tried ai_rewrite: **~67–75%**. Activation is not the problem.

## Retention — THE problem

- Weekly retention (first `keyboard_usage_day` cohorts): W0→W1 **18%** (Jun 28 cohort: 137→25→10), Jul 5 cohort W1 **4.5%** (88→4).
- AI-rewrite usage-day distribution (all time, n=2,348 AI users): **68% used it exactly 1 day** (1,597), 12% 3+ days (285), **2.9% 5+ days (67)**.
- AI-rewrite DAU decayed from peak 435 (Jun 30) to ~55, roughly stable at 50–67 over the last week → a hard core of ~60–70 real daily users exists.

**Caveat:** `keyboard_usage_day` fires from the container app (extension sends no analytics), so pure-keyboard users who never reopen the container are invisible. True keyboard retention is somewhere between the PostHog curve and the AI-rewrite curve. Also PostHog identity has a known case-mismatch split (see memory: posthog-identity-case-mismatch) that deflates retention.

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

The app had a launch spike (~2,600 users in 2 weeks, source invisible/likely App Store), converts installs to activated AI users extremely well (82% try the AI), and then loses ~95% of them within 2 weeks. Growth spend/effort before fixing week-1 retention would be wasted. There is a real core of ~60 daily users to learn from.

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

PostHog: weekly retention insight → [saved query link](https://us.posthog.com/project/465060/insights/new#q=%7B%22kind%22%3A%22InsightVizNode%22%2C%22source%22%3A%7B%22dateRange%22%3A%7B%22date_from%22%3A%22-90d%22%7D%2C%22kind%22%3A%22RetentionQuery%22%2C%22properties%22%3A%5B%5D%2C%22retentionFilter%22%3A%7B%22aggregationPropertyType%22%3A%22event%22%2C%22aggregationType%22%3A%22count%22%2C%22cumulative%22%3Afalse%2C%22period%22%3A%22Week%22%2C%22retentionType%22%3A%22retention_first_time%22%2C%22retentionReference%22%3A%22total%22%2C%22returningEntity%22%3A%7B%22id%22%3A%22keyboard_usage_day%22%2C%22name%22%3A%22keyboard_usage_day%22%2C%22type%22%3A%22events%22%7D%2C%22targetEntity%22%3A%7B%22id%22%3A%22keyboard_usage_day%22%2C%22name%22%3A%22keyboard_usage_day%22%2C%22type%22%3A%22events%22%7D%2C%22totalIntervals%22%3A9%7D%7D%7D) — or ask Claude to re-run `query-retention` on `keyboard_usage_day`.

## Release markers (read retention against these)

Ship dates that should visibly move retention/acceptance. When pulling data, segment cohorts **before vs on/after** these dates.

| Date | Version | Change | Hypothesis / what to watch |
|---|---|---|---|
| 2026-07-23 | 1.0.14 | (a) backend rewrite model upgraded to **GPT-Soul** (from `gpt-5.6-terra` default per AGENTS.md §4); (b) keyboard **input latency** improved | Targets the two named churn causes directly — AI accuracy (#2) and keyboard feel/latency (#1, `churn-signals.md`). Watch: **W1 retention** on cohorts landing 2026-07-23+ vs prior, and the **58%-never-accept** acceptance rate (772/1,855) which reads faster than W1. First W1 signal ~1 week out, D30 ~4 weeks. |

**Pre-ship reference (2026-07-24, day after ship — treat as "before"):** 3,025 users, AI WAU 237, AI DAU 7d-avg ~44. Users only start updating on/after 07-23, so 07-24 metrics are effectively pre-effect.

## History log

| Date | Users | AI WAU | AI DAU (7d avg) | W1 retention | Opt-ins | Dataset-eligible events |
|---|---|---|---|---|---|---|
| 2026-07-18 | 2,851 | 269 | ~55 | ~5–18% | 199 | 677 |
