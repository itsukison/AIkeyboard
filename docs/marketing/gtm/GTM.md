# GTM System — 敬語ボタン

**Entry point for all go-to-market work. Read this first in any GTM session.**
Owner: Itsuki. GTM officer: Claude (any Claude Code session — say 「GTMレビューやって」 and point it here).

## North star

**Strategic acquisition at ~3億円, conversations starting Q4 2026, realistic close by 2027年春.**
Sold as a set: ① keyboard-native 敬語変換 (empty positioning) × ② consented in-situ preference-data pipeline × ③ revenue trajectory. Not a downloads story — 1M DL is NOT required (see `research/exit-comps.md`).

## Current position (update from `metrics-baseline.md`)

As of 2026-07-18: 2,851 users / ~3,500 DL, launched ~June 22. Data asset barely exists (199 opt-ins, 677 eligible events, 0 raw-text).

**Revised 2026-07-30 — the diagnosis changed.** Retention was being measured against installs,
which understates it. On the canonical definition (`metrics-baseline.md` → *Retention definition
v2*: kept ≥1 rewrite **and** returned for a 2nd rewrite day), **activated users retain at ~30% W1
/ ~16% W2** — not a crisis (no comparable external benchmark exists for this
denominator, so don't call it top-quartile). The crisis is one step earlier:
**only 11.5% of installs ever activate**, and 61% of users who try a rewrite never keep one. The
old "82% try the AI, activation is fine" reading was counting a *prompted trial* — 85% of first
real rewrites happen within 5 minutes of finishing onboarding. So: **the problem is try → keep, not
churn.** ~60 hardcore daily users. **Growth spikes to date came from RED (小紅書) UGC, not App Store** (founder-reported); the RED/Chinese segment is the largest volume but retains ~half as well as Japanese/organic (`metrics-baseline.md` → Retention by segment) — do not assume Chinese speakers are the primary target.

## The one rule

**Do not spend effort or money on acquisition until both gates are green: activation (install →
activated) ≥25% and activated W2 ≥25%.** Now 11.5% and 13–18% → ❌. Restated 2026-07-30; the old
wording ("W1 retention < 25%") reads green under the v2 definition purely because the denominator
changed, so do not use it. Gate detail in `roadmap.md` Phase 0, evidence in `metrics-baseline.md`.

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
| Viral-format research, hook testing, or winning-formula exploration — including provocative hooks for a new scalable format | `viral-format-research.md` | The existing LINE-story bank and production/publishing files unless moving an approved experiment into production |
| New episode for the existing funny/spicy LINE-style workplace slideshow series | `spicy-content-bank.md` only | `viral-format-research.md` and `content-strategy.md` unless changing the format or overall portfolio |
| Produce an approved chat mockup | The approved episode in `spicy-content-bank.md` + the relevant template README under `../content/line-story/templates/` | All other GTM files |
| New post for the app-curation slideshow (app-intro) | `../content/app-intro/README.md` only — it owns the slide spec, the `apps.json`/`post.json` model, the written-but-unrendered hook queue, and the caption | `spicy-content-bank.md` and the LINE-story templates; this is a different format |
| Starting a brand-new content format | `../content/README.md` §Adding a third format, then `viral-format-research.md` for the mass-production eligibility rule | The existing content banks |
| Publish or schedule approved social content through Buffer | `buffer-publishing.md`, then the owning content bank + relevant episode/template README | Metrics and research unless evaluating results |
| Run or configure the autonomous TikTok loop | `tiktok-autopilot.md`, then only the files it routes to | Unrelated GTM research and outreach |
| Website SEO / GEO, keyword targeting, llms.txt | `seo-geo.md` | Content and metrics files unless a number is needed |
| Writing a new page for the website | `seo-geo.md` §設計方針 first, then §キーワードマップ | Everything else |
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
| `viral-format-research.md` | Viral references, format decomposition, hook-test strategy, and exploration of a new scalable formula separate from the LINE slideshow system |
| `seo-geo.md` | Website design principles, keyword map, page inventory, GEO/llms.txt, search measurement |
| `spicy-content-bank.md` | Provocative concepts and production-ready scripts for the existing LINE-style slideshow system |
| `buffer-publishing.md` | Rendering, media upload, Buffer publishing, monitoring, result recording |
| `tiktok-autopilot.md` | Autonomous TikTok cadence, gates, feedback policy, and scheduled-task prompts |
| `research/*.md` | Point-in-time external evidence; read only for its named question |
| `../content/README.md` | Which content formats exist, their directory layout, and the code paths bound to each |
| `../content/app-intro/README.md` | The app-curation slideshow format: slide spec, card-copy library, hook queue, caption, publish blockers |

## Operating cadence

- **Weekly (Friday)**: run the weekly review — pull metrics (queries in `metrics-baseline.md`), append to the history table, fill a `weekly-review.md` entry, check the current phase gate in `roadmap.md`, pick ≤3 actions for next week.
- **Monthly**: re-read `roadmap.md`, adjust targets/phases against reality, refresh competitor intel if something moved (LeapMe, Simeji AI, 3秒敬語).
- Research files are point-in-time (2026-07-18); re-verify before quoting externally.

## Future direction (Itsuki, 2026-07-18)

The first autonomous GTM harness is the TikTok growth loop documented in
`tiktok-autopilot.md`. Its repository pieces are built; scheduled tasks remain
disabled until the manual dry run and approval gates are verified. Extend the
same pattern later to weekly metrics, PR content, competitor monitoring, and
alerts without mixing their state or permissions.

## Standing prompts for Claude Code sessions

- 「GTM週次レビュー」→ use the Weekly GTM review route above.
- 「GTMの状況は?」→ use the Quick GTM status route above.
- Content requests → choose either the general-content or provocative-content
  route; do not automatically read both.
- Keep this directory as the single source of truth; memory files only point here.
