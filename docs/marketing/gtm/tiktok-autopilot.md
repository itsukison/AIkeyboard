# TikTok autonomous growth loop

Last verified: **2026-07-29**. Owner: Itsuki.

This file owns the autonomous TikTok operating policy. `content-strategy.md`
owns positioning and measurement definitions, `spicy-content-bank.md` owns
approved provocative concepts, and `buffer-publishing.md` owns the publication
mechanics.

## Current state

The repository harness is installed and the first live manual production run
completed successfully on 2026-07-29; the Codex scheduled tasks still require
one-time creation in the desktop app's **Scheduled** screen. The first production mode is `approved_only`: approved content-bank
episodes may be scheduled after real-rewrite verification and visual QA. New
concepts may be generated and rendered automatically but require human approval
before publication.

Configuration and durable run state live under `../automation/`. Create an empty
`../automation/PAUSED` file to stop every external write at the beginning of the
next run; remove it to resume.

## Schedule

All times use `Asia/Tokyo`.

| Task | Cadence | Purpose |
|---|---|---|
| Daily controller | 05:00 daily | Reconcile Buffer, capture due analytics, analyze, and fill a six-post rolling queue |
| Publish monitor | 11:00, 14:00, 20:00 daily | Confirm the preceding post reached `sent`; surface `error` or an overdue state |
| Weekly review | 10:00 Friday | Review comparable 72-hour results and adjust bounded experiment allocation only when sample gates pass |

Suggested recurrence rules:

- Daily controller: `RRULE:FREQ=DAILY;BYHOUR=5;BYMINUTE=0`
- Publish monitor: `RRULE:FREQ=DAILY;BYHOUR=11,14,20;BYMINUTE=0`
- Weekly review: `RRULE:FREQ=WEEKLY;BYDAY=FR;BYHOUR=10;BYMINUTE=0`

Initial publishing slots are **09:30, 12:30, and 18:30 JST**. Keep these fixed
until every slot has at least ten comparable observations. Rotate exploit and
explore content across the slots during that baseline period.

## Daily controller

1. Use `$tiktok-growth-loop` in `daily-controller` mode.
2. Pull due Buffer metrics and record 24-hour, 72-hour, and 168-hour snapshots.
3. Reconcile the local ledger against Buffer before calculating open slots.
4. Keep six future posts scheduled without exceeding three per local day or the
   Buffer plan limit of ten scheduled posts.
5. Allocate two proven-format `exploit` posts and one controlled `explore` post
   per complete day.
6. Generate episodes as declarative `episode.json` files and render them with
   `scripts/marketing/render_tiktok_episode.py`.
7. Enforce approval, real-rewrite, and visual-QA gates before any upload.
8. Schedule through Buffer and record the accepted Buffer post immediately.

Use this scheduled-task prompt:

```text
Use $tiktok-growth-loop in daily-controller mode for the Japanese project. Reconcile Buffer and local state, capture due analytics snapshots, analyze comparable results, and safely fill the next six TikTok slots. Publish only episodes that pass every configured gate. Do not ask for approval during the unattended run; leave blocked concepts as drafts and report the blocker.
```

## Publish monitor

Use this scheduled-task prompt:

```text
Use $tiktok-growth-loop in publish-monitor mode for the Japanese project. Reconcile TikTok posts whose Buffer due time has passed, record sent links or errors, and report only failures or posts still not sent after a reasonable publishing window. Never create a replacement post automatically.
```

## Weekly review

Use this scheduled-task prompt:

```text
Use $tiktok-growth-loop in weekly-review mode for the Japanese project. Analyze comparable 72-hour TikTok snapshots, separate distribution wins from qualified-engagement wins, review exploit/explore balance and posting-slot sample counts, and recommend or make only config-bounded allocation changes. Do not change posting times until every slot meets the configured minimum sample size.
```

## Decision policy

- Treat a post with at least 3× the comparable-window median views as a
  distribution lead.
- Promote it to a repeatable winner only when its engagement rate is at least
  75% of the comparable-window median and no available product-quality signal
  contradicts the result.
- Replicate one creative element at a time: premise, opening hook, reveal slide,
  CTA, or title. Do not clone all variables and call that learning.
- Use Buffer metrics for automated reach feedback. Treat completion, saves,
  profile visits, store taps, accepted rewrites, and retention as unavailable
  until a trustworthy source is connected.
- Never let high views alone override the GTM retention constraint or the
  editorial rules.

## Episode contract

Use `../content/014-sick-day-pressure/episode.json` as the reference. Each spec
owns its scene, ordered slides, title, hashtags, hypothesis, experiment labels,
and approval gates. The generic renderer injects the scene into the existing
LINE-style and product-UI templates and produces up to ten 1080 × 1350 PNGs.

The content hash printed by the renderer is the deduplication key stored with the
Buffer post. A scheduled run must stop before upload if the same hash is already
scheduled or sent.

## Enabling the tasks

Create three standalone Codex scheduled tasks in the desktop app, select this
project directory, use local-project mode, and paste the prompts above. Keep the
Mac mini powered on, logged in, awake, and the desktop app running. Test each task
manually before enabling its recurrence.
