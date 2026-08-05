# 2026-08-05 marketing reorg — session handoff

Owner: Itsuki. This documents exactly what a same-day session did and did
**not** finish, so it can be picked back up without re-deriving state. The
resulting policy lives in `posting-policy.md`; read that first for the
"what should be true going forward" version. This file is the "what actually
happened" record.

## Ask

Reorganize posting across four accounts (Buffer/keigobutton, Zernio's
アプリ大好き, Saya, and Instagram), stop the Codex daily-decision loop, and
mass-produce ~3–4 days of content per account instead of relying on daily
agent runs. Full detail in the conversation; short version in
`posting-policy.md`.

## Status by account

### Buffer / keigobutton (Natsumi) — ✅ done, verified

10/10 posts scheduled (Buffer's hard cap on this plan), covering tonight
(2026-08-05) through 2026-08-08, 2 office-talk + 1 line-story per day.

- New content written and rendered: `office-talk/posts/003` through `008`
  (original hook + 5 phrase-pair copy each, visual QA passed on all 42
  slides).
- Rendered and uploaded from the existing approved bank, no new writing:
  `line-story/episodes/014`, `018`, `019` (018/019's `approval.status` was
  flipped from `pending` to `approved` — they already had `rewriteVerified`
  and `visualQA` both `true`, so this session treated Itsuki's live direction
  as the approval step).
- All 9 new Buffer post IDs + the pre-existing `002-dakikomanai` are recorded
  in `docs/marketing/automation/state.json`.

### Zernio アプリ大好き (ruka_keigobutton) — ✅ done, verified

Deleted the 7 line-unfold posts that had been mixed in. Now 12/12 app-intro
posts scheduled, 3×/day tonight through 2026-08-08 (slugs 011–022).

- New content: `app-intro/posts/017` through `022`, built entirely from the
  **existing** `apps.json` screenshot library (see `posting-policy.md` for
  why no new screenshots were needed) — 24 third-party app slots across 6
  posts, no app repeated within a post, none pushed past the 3-use cap.

### Zernio Saya (mari040715) — ⚠️ done, then partially rolled back

Originally scheduled 12 line-unfold posts (existing `001`–`007` + newly-built
`008`–`012`), 3×/day tonight through 2026-08-08.

**The 5 posts using the newly-built videos (008–012) were deleted** after
Itsuki flagged that this session cannot produce line-unfold video to the
usual bar — the renderer only outputs a silent MP4, and 001–007 went through
an off-repo BGM/device pass this session has no access to. Their `post.json`
files are marked `needs-rework` (see `posting-policy.md`).

**Current real state: only 7 posts are scheduled on Saya (001–007), not the
intended 12.** Nothing further was scheduled here after the rollback.

### Instagram (yuna_keigobutton) — ❌ incomplete, stopped mid-way

Target was 20 posts (3×/day line-unfold + 2×/day app-intro, tonight through
2026-08-08). Only 5 were created before this session stopped:

| Slot | Content | Result |
|---|---|---|
| Aug5 18:30 JST, app-intro #1 | `011-build-and-learn` | **FAILED** — 409 "exact content already scheduled/posted within 24h". Not retried; needs a different app-intro post substituted for this slot (e.g. one of 012–016 not already used on this account) or investigation into why 011 collided. |
| Aug5 19:30 JST, app-intro #2 | `017-language-habit` | scheduled |
| Aug5 20:00 JST, line-unfold #1 | `line-unfold-001-foreign-girlfriend` | scheduled |
| Aug5 21:30 JST, line-unfold #2 | `line-unfold-002-new-hire-apology` | scheduled |
| Aug5 23:00 JST, line-unfold #3 | `line-unfold-003-older-match` | scheduled |

**Nothing was created for Aug6, Aug7, or Aug8 on Instagram.**

## The Instagram plan that was in progress

This is the intended mapping if picking this back up — it mirrors the
アプリ大好き and Saya schedules already live, so no new decisions should be
needed, just execution:

| Day | App-intro (2×) | Line-unfold (3×) |
|---|---|---|
| Aug5 tonight | 011 (blocked, see above), 017 ✅ | 001 ✅, 002 ✅, 003 ✅ |
| Aug6 | 019, 013 | 004, 005, 006 |
| Aug7 | 014, 015 | 007, **[008 blocked — needs-rework]** |
| Aug8 | 016, 022 | **[009–012 blocked — needs-rework]** |

Times used elsewhere in this reorg: app-intro at 12:30/17:00 JST, line-unfold
at 09:00/15:00/21:00 JST for Aug6–8 (tonight used one-off later evening
slots since it started mid-evening).

Media URLs (all already uploaded to Supabase, ready to use):
- App-intro images: `https://eercsucvxnszqletxued.supabase.co/storage/v1/object/public/marketing-media/tiktok/<slug>/0N.png` (6 slides each for 017–022, N=01..06).
- Line-unfold video: `https://eercsucvxnszqletxued.supabase.co/storage/v1/object/public/marketing-media/tiktok/line-unfold-<slug>.mp4`.

Account ID for Instagram: `6a6b7765df17280d93f65ff5`.

## Remaining open items

1. **Instagram Aug6/Aug7 line-unfold (004–007) and all app-intro crossposts
   (019+013, 014+015, 016+022) were never created.** Straightforward to
   finish using the table above — no new content, just scheduling calls.
2. **Instagram's Aug7 slot 3 and all of Aug8's line-unfold slots are blocked**
   until 008–012 get a real BGM/device pass (or are replaced).
3. **Saya is short 5 posts** (7 scheduled instead of 12) for the same reason.
4. **The app-intro/011 → Instagram 409 collision is unexplained** — worth a
   quick look at whether 011 was already published to this account
   previously (via `posts_list_posts` with `source: "external"` or the
   analytics sync tool) before assuming it's safe to just pick a different
   slug for that slot.

## Files changed this session

- `docs/marketing/content/office-talk/posts/003..008/` (new)
- `docs/marketing/content/line-story/episodes/014,018,019/episode.json` (approval field only)
- `docs/marketing/content/app-intro/posts/017..022/` (new)
- `docs/marketing/content/line-unfold-video/posts/008..012/` (new, marked `needs-rework`)
- `docs/marketing/automation/state.json` (9 new Buffer post records appended)
- `docs/marketing/gtm/posting-policy.md` (new)
- `docs/marketing/gtm/2026-08-05-reorg-handoff.md` (this file)
- `~/.codex/automations/tiktok-{daily-controller,publish-monitor,weekly-review}/automation.toml` (status → PAUSED; outside this repo, not part of the git push)
