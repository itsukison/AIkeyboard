# GTM System — 敬語ボタン

**Entry point for all go-to-market work. Read this first in any GTM session.**
Owner: Itsuki. GTM officer: Claude (any Claude Code session — say 「GTMレビューやって」 and point it here).

## North star

**Strategic acquisition at ~3億円, conversations starting Q4 2026, realistic close by 2027年春.**
Sold as a set: ① keyboard-native 敬語変換 (empty positioning) × ② consented in-situ preference-data pipeline × ③ revenue trajectory. Not a downloads story — 1M DL is NOT required (see `research/exit-comps.md`).

## Current position (update from `metrics-baseline.md`)

As of 2026-07-18: 2,851 users / ~3,500 DL, launched ~June 22. Activation excellent (82% try AI), **retention is the crisis** (68% one-day users, W1 5–18%). Data asset barely exists (199 opt-ins, 677 eligible events, 0 raw-text). ~60 hardcore daily users. **Growth spikes to date came from RED (小紅書) UGC, not App Store** (founder-reported); the RED/Chinese segment is the largest volume but retains ~half as well as Japanese/organic (`metrics-baseline.md` → Retention by segment) — do not assume Chinese speakers are the primary target.

## The one rule

**Do not spend effort or money on acquisition while W1 retention < 25%.** (D30 <10% → scaling installs accelerates losses. `research/benchmarks.md`)

## Context router — do not read everything

Start with this file, identify the task, then read **only** the route below.
Stop after the listed files unless a missing fact makes another file necessary.
References inside a routed file are not instructions to preload them.

| Task | Read | Do not preload |
|---|---|---|
| Quick GTM status | `metrics-baseline.md` latest topline/history + latest entry in `weekly-review.md` | Research, content, outreach |
| Weekly GTM review | `metrics-baseline.md`, `roadmap.md`, `weekly-review.md` | Content and research unless a metric requires it |
| Retention or persona diagnosis | `metrics-baseline.md`, `churn-signals.md` | Exit and content files |
| User-email campaign | `outreach-log.md`, then the standing playbook in `churn-signals.md` | Research and content files |
| General organic-content strategy | `content-strategy.md` | Metrics detail and research; the important constraints are summarized there |
| Funny, spicy, or controversial workplace content | `spicy-content-bank.md` only | `content-strategy.md` unless changing the overall portfolio |
| Produce an approved chat mockup | The approved episode in `spicy-content-bank.md` + the relevant template README under `../content/templates/` | All other GTM files |
| Competitor, ASO, or JP-market question | `research/jp-market.md` | Other research files |
| Paid ads / channel-spend question | `research/paid-channels.md` | Other research files |
| KPI benchmark or channel evidence | `research/benchmarks.md` | Market and exit research |
| Exit thesis, valuation, or buyer work | `roadmap.md`, `research/exit-comps.md`; add `metrics-baseline.md` only for current numbers | Content and outreach |

### File ownership

Each fact should have one home. Link to that source instead of duplicating its
detail elsewhere.

| File | Owns |
|---|---|
| `metrics-baseline.md` | Live numbers, re-pull queries, metric history |
| `roadmap.md` | Phase gates, sequencing, KPI targets |
| `weekly-review.md` | Dated decisions and weekly actions |
| `churn-signals.md` | Churn evidence, personas, email learnings |
| `outreach-log.md` | Contact history and deduplication |
| `content-strategy.md` | Content positioning, audiences, portfolio, measurement |
| `spicy-content-bank.md` | Provocative concepts and production-ready scripts |
| `research/*.md` | Point-in-time external evidence; read only for its named question |

## Operating cadence

- **Weekly (Friday)**: run the weekly review — pull metrics (queries in `metrics-baseline.md`), append to the history table, fill a `weekly-review.md` entry, check the current phase gate in `roadmap.md`, pick ≤3 actions for next week.
- **Monthly**: re-read `roadmap.md`, adjust targets/phases against reality, refresh competitor intel if something moved (LeapMe, Simeji AI, 3秒敬語).
- Research files are point-in-time (2026-07-18); re-verify before quoting externally.

## Future direction (Itsuki, 2026-07-18)

Evolve this from md files + manual weekly reviews into an **autonomous GTM team**: scheduled agents that run the metrics pull, draft UGC/PR content, monitor competitors, and propose actions on their own cadence (harness cycle). Building blocks when ready: scheduled routines (`/schedule`) for the weekly review, multi-agent workflows for content production, PushNotification for alerts. Not built yet — revisit after Phase 0.

## Standing prompts for Claude Code sessions

- 「GTM週次レビュー」→ use the Weekly GTM review route above.
- 「GTMの状況は?」→ use the Quick GTM status route above.
- Content requests → choose either the general-content or provocative-content
  route; do not automatically read both.
- Keep this directory as the single source of truth; memory files only point here.
