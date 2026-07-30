---
name: tiktok-growth-loop
description: Run the 敬語ボタン autonomous TikTok slideshow feedback loop. Use for scheduled or manual runs that reconcile Buffer post status, capture TikTok metrics, identify repeatable winners, choose exploit/explore concepts, generate and QA episode specs and slides, fill the rolling Buffer queue, monitor publication errors, or perform the weekly timing and format review.
---

# TikTok Growth Loop

Read `/Users/itsuki/Desktop/key/Japanese/AGENTS.md`, then read
`docs/marketing/gtm/GTM.md` and
`docs/marketing/gtm/tiktok-autopilot.md`. Follow its routed references and use
`$buffer-publish-content` for every Buffer upload, schedule, publish, or monitor
operation.

Treat each invocation as a restartable run. Keep continuity in
`docs/marketing/automation/state.json`, never in chat memory.

## Select the run

- For `daily-controller`, reconcile Buffer, capture due metrics, analyze results,
  and fill the next six slots.
- For `publish-monitor`, reconcile posts whose due time passed and report `error`
  or overdue `scheduled`/`sending` states.
- For `weekly-review`, analyze comparable 72-hour snapshots, review slot balance,
  and update only the bounded experiment allocation in the automation config.
- If no run is named, use `daily-controller`.

## Start safely

1. Stop without external writes if `docs/marketing/automation/PAUSED` exists.
2. Read `config.json` and `state.json`.
3. Call Buffer `get_account`, then `list_channels`; use the exact connected
   `keigobutton` TikTok channel ID returned for this run.
4. List recent scheduled, sending, sent, and error posts. Reconcile known Buffer
   IDs before planning new posts. Never duplicate a matching Buffer post merely
   because local state is stale.
5. Use sent posts absent from the ledger as directional historical context only.
   Do not mix their latest cumulative metrics into the controlled 24-hour,
   72-hour, or 168-hour snapshot comparisons.

## Refresh the feedback state

1. Run `python3 scripts/marketing/tiktok_agent_state.py due-snapshots`.
2. Fetch `includeMetrics: true` only for due posts.
3. Normalize Buffer metric names to `views`, `reach`, `reactions`, `comments`,
   `shares`, and `engagementRate` when present.
4. Record one snapshot with `record-metrics`; preserve Buffer's
   `metricsUpdatedAt` freshness timestamp.
5. Run `analyze --window-hours 72`. Treat high views with a failed qualified
   engagement floor as a distribution lead to replicate carefully, not a proven
   product winner.

Do not change timing weights until every slot reaches the configured minimum
sample count. Do not optimize on views alone.

## Fill the queue

1. Run `python3 scripts/marketing/tiktok_agent_state.py next-slots` and reconcile
   those results with Buffer's scheduled queue. Keep at most six future posts and
   never exceed Buffer's ten-post plan limit or three posts on a local calendar day.
2. Allocate each complete day as two `exploit` posts and one `explore` post.
   Rotate allocations and content families across 09:30, 12:30, and 18:30 JST so
   content strength is not permanently confounded with posting time.
3. Prefer approved remaining stock in `spicy-content-bank.md`. When stock is
   exhausted, generate a new episode spec from proven structures, but leave it
   unapproved unless the source concept is already explicitly approved.
4. Copy `docs/marketing/content/014-sick-day-pressure/episode.json` as the
   structural reference. Give each new episode its own content directory and
   `episode.json`.
5. Test every displayed rewrite with the shipping product. Set
   `approval.rewriteVerified` only after the displayed candidate matches the real
   output or the copy is explicitly labeled according to the content rules.
6. Render with `python3 scripts/marketing/render_tiktok_episode.py <episode.json>`.
   Visually inspect every output image. Set `approval.visualQA` only after checking
   wrapping, clipping, scene continuity, result legibility, and bottom safe space.
7. Run the renderer with `--check-publishable`. Do not upload or create a Buffer
   post when this gate fails.
8. Use `$buffer-publish-content` to upload and create a `customScheduled`
   automatic TikTok post. Use the spec title as `metadata.tiktok.title`, join only
   the spec's hashtags into `text`, and attach the ordered image URLs.
9. Record the Buffer ID, content hash, due time, slot, allocation, and hypothesis
   with `tiktok_agent_state.py record-post` immediately after Buffer accepts it.

## Reconcile publication

For posts whose due time passed, call Buffer `get_post`. Record `sentAt` and the
external link only after `sent`; record the error when `error`. Do not silently
replace a failed post or report `sending` as success. Update the episode README and
content-bank production queue only after `sent`.

## Report

Keep routine runs concise: metrics captured, queue slots filled, Buffer IDs, and
any gate or publication failure. Surface a recommendation only when comparable
evidence changed. Never hide a skipped post, stale metrics, or missing approval.
