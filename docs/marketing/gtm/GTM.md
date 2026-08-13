# GTM System — 敬語ボタン

**Entry point for all go-to-market work. Read this first in any GTM session.**
Owner: Itsuki. GTM officer: Claude (any Claude Code session — say 「GTMレビューやって」 and point it here).

## North star

**Strategic acquisition at ~3億円, conversations starting Q4 2026, realistic close by 2027年春.**
Sold as a set: ① keyboard-native 敬語変換 (empty positioning) × ② consented in-situ preference-data
pipeline × ③ revenue trajectory. Not a downloads story — 1M DL is NOT required
(see `research/exit-comps.md`).

## Current position

As of **2026-08-13**: 3,318 signed-up users. Signups **8.6/day** (was ~21/day on 08-02); AI WAU
**163** and falling faster than installs (−22% WoW). Full numbers in `retention-and-users.md`.

**The diagnosis in three lines:**

1. **Retention is flat across every version shipped** — seven weekly cohorts, four onboarding
   versions, W1 stuck at 9.4–16.0%. Onboarding is not where the lever is.
2. **51% of onboarding starters never confirm Full Access**, and the cloud rewrite is impossible
   without it. That group tries a rewrite 10.8% of the time vs 50.4%.
3. **~49% of AI invocations are fired at text that needs no rewrite or isn't a message** — already-polite
   短文, fragments, and ≤3-char mistaps. 10.5% of rewrites return candidate 1 byte-identical to the input.

And the fact that constrains every remedy: **satisfaction is not sufficient.** Users who accepted two
rewrites on day 0 return only 41% of the time and 82% are gone by day 7.

## The one rule

**Do not spend effort or money on acquisition until both gates are green: activation (install →
activated) ≥25% and activated W2 ≥25%.** Now 11.5% and 13–18% → ❌. Restated 2026-07-30; the older
wording ("W1 retention < 25%") reads green purely because the denominator changed, so do not use it.
Gate detail in `roadmap.md` Phase 0, evidence in `retention-and-users.md`.

**Standing rule on interventions (learned the hard way):** never ship a retention change to 100%
without an exposure event and a control arm. Four of the five shipped interventions in
`hypothesis-ledger.md` §1 are now permanently unattributable.

## Context router — do not read everything

Start with this file, identify the task, then read **only** the route below.
Stop after the listed files unless a missing fact makes another file necessary.
References inside a routed file are not instructions to preload them.

| Task | Read | Do not preload |
|---|---|---|
| Quick GTM status | `retention-and-users.md` §10 history + latest entry in `weekly-review.md` | Research, content, outreach |
| Weekly GTM review | `retention-and-users.md`, `roadmap.md`, `weekly-review.md` | Content and research unless a metric requires it |
| Retention, churn, or persona diagnosis | `retention-and-users.md` | Exit and content files |
| "Have we tried X already?" / proposing a retention fix | `hypothesis-ledger.md` **first**, then `retention-and-users.md` for the underlying numbers | Everything else |
| Designing an experiment | `hypothesis-ledger.md` §5 (open questions + kill gates), then `retention-and-users.md` §8 | Content and research |
| User-email campaign | `outreach-log.md` (waves, dedupe protocol, standing playbook, reply tally) | Research and content files |
| General organic-content strategy | `content-ops/content-strategy.md` | Metrics detail and research |
| Viral-format research, hook testing, new scalable format | `content-ops/viral-format-research.md` | The LINE-story bank and publishing files unless moving an approved experiment into production |
| New episode for the funny/spicy LINE-style slideshow series | `content-ops/spicy-content-bank.md` only | `content-ops/viral-format-research.md` and `content-ops/content-strategy.md` unless changing the format |
| Produce an approved chat mockup | The approved episode in `content-ops/spicy-content-bank.md` + the relevant template README under `../content/line-story/templates/` | All other GTM files |
| New post for the app-curation slideshow (app-intro) | `../content/app-intro/README.md` only — it owns the slide spec, `apps.json`/`post.json` model, hook queue, and caption | `content-ops/spicy-content-bank.md` and the LINE-story templates |
| Starting a brand-new content format | `../content/README.md` §Adding a third format, then `content-ops/viral-format-research.md` for the mass-production eligibility rule | The existing content banks |
| Publish or schedule approved content through Buffer | `content-ops/buffer-publishing.md`, then the owning content bank + episode/template README | Metrics and research |
| Run or configure the autonomous TikTok loop | `content-ops/tiktok-autopilot.md`, then only the files it routes to | Unrelated GTM research and outreach |
| Which account posts what, or changing per-account cadence | `content-ops/posting-policy.md` | Content banks unless changing copy too |
| Website SEO / GEO, keyword targeting, llms.txt | `seo-geo.md` | Content and metrics files |
| Writing a new page for the website | `seo-geo.md` §設計方針 first, then §キーワードマップ | Everything else |
| Competitor, ASO, or JP-market question | `research/jp-market.md` | Other research files |
| Paid ads / channel-spend question | `research/paid-channels.md` | Other research files |
| KPI benchmark or channel evidence | `research/benchmarks.md` | Market and exit research |
| Exit thesis, valuation, or buyer work | `roadmap.md`, `research/exit-comps.md`; add `retention-and-users.md` only for current numbers | Content and outreach |

### File ownership

Each fact should have one home. Link to that source instead of duplicating its detail elsewhere.

| File | Owns |
|---|---|
| `retention-and-users.md` | **All behavioural evidence**: funnel, retention, power users, churners, observed failure modes, measurement blind spots, re-pull queries, metric history |
| `hypothesis-ledger.md` | **Every hypothesis we've held**: what we shipped, how it performed, what's still open, and the kill gates on open experiments |
| `roadmap.md` | Phase gates, sequencing, KPI targets |
| `weekly-review.md` | Dated decisions and weekly actions |
| `outreach-log.md` | Contact history, dedupe protocol, standing email playbook, churn-reply tally, persona notes |
| `seo-geo.md` | Website design principles, keyword map, page inventory, GEO/llms.txt, search measurement |
| `content-ops/content-strategy.md` | Content positioning, audiences, portfolio, measurement |
| `content-ops/viral-format-research.md` | Viral references, format decomposition, hook-test strategy, new-formula exploration |
| `content-ops/spicy-content-bank.md` | Provocative concepts and production-ready scripts for the LINE-style slideshow system |
| `content-ops/buffer-publishing.md` | Rendering, media upload, Buffer publishing, monitoring, result recording |
| `content-ops/tiktok-autopilot.md` | Autonomous TikTok cadence, gates, feedback policy, scheduled-task prompts |
| `content-ops/posting-policy.md` | Per-account format assignment and cadence, cross-posting pattern, content-reuse rules, known publishing issues |
| `research/*.md` | Point-in-time external evidence (2026-07-18); read only for its named question |
| `../content/README.md` | Which content formats exist, directory layout, code paths bound to each |
| `../content/app-intro/README.md` | The app-curation slideshow format: slide spec, card-copy library, hook queue, caption, publish blockers |

## Operating cadence

- **Weekly (Friday)**: run the weekly review — pull metrics (queries in `retention-and-users.md` §9),
  append to the §10 history table, fill a `weekly-review.md` entry, check the current phase gate in
  `roadmap.md`, pick ≤3 actions for next week.
- **When a hypothesis resolves**: update its verdict row in `hypothesis-ledger.md`. Never delete a
  row — a retired hypothesis is the most useful kind.
- **Monthly**: re-read `roadmap.md`, adjust targets/phases against reality, refresh competitor intel
  if something moved (LeapMe, Simeji AI, 3秒敬語).
- Research files are point-in-time (2026-07-18); re-verify before quoting externally.

## Standing prompts for Claude Code sessions

- 「GTM週次レビュー」→ use the Weekly GTM review route above.
- 「GTMの状況は?」→ use the Quick GTM status route above.
- 「これもう試した?」→ `hypothesis-ledger.md` only.
- Content requests → choose one content route; do not automatically read both.
- Keep this directory as the single source of truth; memory files only point here.

## Doc history

**2026-08-13 consolidation.** Five overlapping metrics docs (`metrics-baseline.md`,
`pmf-diagnosis-2026-08-02.md`, `product-data-diagnosis-2026-08-12.md`,
`instruction-model-investigation-2026-08-13.md`, and the data half of `churn-signals.md`) were merged
into `retention-and-users.md` + `hypothesis-ledger.md`; the email playbook moved to `outreach-log.md`;
the six content/social docs moved to `content-ops/`; and the expired
`2026-08-05-reorg-handoff.md` was dropped after its live items were carried into
`content-ops/posting-policy.md`. The originals are recoverable from git history — the two untracked
investigations were committed in `f2d81af` immediately before deletion.
