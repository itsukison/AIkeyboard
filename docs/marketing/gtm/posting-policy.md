# Posting policy — per account

Owner: Itsuki. Effective **2026-08-05**. Supersedes whatever ad-hoc mixing
existed on each account before this date. Read this alongside `GTM.md` and
`tiktok-autopilot.md`.

## Why this changed

The line slideshow alone was underperforming on the Buffer account, and
mixing line-unfold video into the app-intro TikTok account was diluting both
formats. On 2026-08-05 the four accounts were split by format instead, and
the daily autonomous decision loop was paused in favor of manual batch
production (3–7 days at a time, checked periodically) — see `tiktok-autopilot.md`
for what that loop used to do.

## Account → format assignment

| Account | Platform | Format(s) | Cadence |
|---|---|---|---|
| keigobutton (Natsumi) | Buffer / TikTok | line-unfold anthology (video) only | 3× / day |
| アプリ大好き (ruka_keigobutton) | Zernio / TikTok | app-intro (slideshow) only | 3× / day |
| Saya (mari040715) | Zernio / TikTok | line-unfold anthology (video) only | 3× / day |
| yuri_keigobutton | Zernio / TikTok | line-unfold anthology (video) only | 3× / day |
| yuna_keigobutton | Zernio / Instagram | **line-unfold Reels only** | **5× / day** |

### The three line-unfold accounts are split by conflict type

Decided 2026-08-11, replacing the 2026-08-09 relationship-stage split.
**Canonical version lives in `../content/line-unfold-video/README.md`
§The three accounts** — that file owns the detail and the evidence; this is the
one-line summary.

| Account | Lane | 争点 | 主なコマンド |
|---|---|---|---|
| Saya | 金銭・不公平 | 奢る／割り勘／誠意 | 自然に |
| yuri | 送ってしまった後 | 事故として許されるか | 敬語／自然に |
| natsumi | 職場の理不尽 | 新人が悪いか上司が悪いか | 敬語／英訳 |

Consequences:

- **Workplace material is back**, on natsumi only. The 8/09 rule that banned it
  was contradicted by the numbers — 2 of the 3 highest-reach posts we have ever
  published are workplace stories (42,150 and 30,364 views).
- **yuri's serial is closed at #18.** Every yuri episode from #19 is standalone.
  Serial captions carried 【#N】; anthology captions are hashtags-only, so the
  numbering disappears from new posts.
- **app-intro is cut from Instagram** (was 2× / day). Over 8/01–8/10 it returned
  a median of 67 views there against line-unfold's 5,642 — an 84× gap. Its slots
  went to line-unfold, taking Instagram to 5× / day.
- Instagram has **no separate writing stream**: it is a best-of cross-post
  surface fed from the three TikTok lanes, weighted toward workplace and
  high-drama, which is what has actually travelled there.

Notes:
- **natsumi converted to line-unfold 2026-08-09.** It previously ran office-talk +
  line-story; a week of results showed line-unfold (dating / spicy) carrying the
  traffic, so the format was cut over. Its bank is
  `../content/line-unfold-video/BANK-NATSUMI.md`, posts live in `posts/natsumi/`,
  media uploads to `marketing-media/tiktok/natsumi/`, grid **10:00 / 16:00 / 22:00
  JST** (offset an hour from Saya so the two never post together).
  - **Re-pointed to the 職場の理不尽 lane 2026-08-11** and brought onto the same
    3-page, product-late-on-page-2 shape as the other two. The product-at-the-end
    A/B it used to run is abandoned — 6 episodes reached a median of 502 views,
    which is not enough to read a placement effect from.
  - **office-talk and line-story are now dormant, not deleted.** `spicy-content-bank.md`,
    `line-story/episodes/` and `office-talk/posts/` are untouched and remain the only
    non-video formats if TikTok's video reach shifts.
  - **Buffer does publish TikTok video** — verified 2026-08-09 (`assets:[{video:{url}}]`
    with a public Supabase URL; Buffer generates its own thumbnail). The earlier
    doubt is resolved. Concurrent creates can spuriously return "Video could not be
    read from its URL"; retry that one post singly before suspecting the URL.
- **yuri_keigobutton added 2026-08-06**, ran the 先輩と敬語 serial #1–#18, and
  **converted to an anthology 2026-08-11** after the serial decayed from 19,346
  views on #1 to 94 on #12. Its bank is
  `../content/line-unfold-video/BANK-YURI.md`, its posts live in `posts/yuri/`,
  and its media still uploads to `marketing-media/tiktok/yuri-serial/` (the path
  is now just a folder name, not a claim about the format). #13–#18 stay
  scheduled through Aug 12; #19 onward are standalone.
- Captions on all three accounts are hashtags-only. The 【#N】 prefix belonged to
  the serial and retires with it.
- **アプリ大好き no longer carries line-unfold.** It was mixed in
  2026-08-04/05; Itsuki flagged the mix as hurting the account, so it moved
  entirely to Saya's TikTok account and to Instagram.
- **Instagram was app-intro-only before 2026-08-05.** It now also carries the
  line-unfold Reels that used to double up on アプリ大好き.
- Buffer's channel has a hard **10 scheduled-post cap** on the current plan —
  do not queue past that without checking `get_account` limits first.

## Cross-posting pattern

The same rendered post (app-intro) or video (line-unfold) is published to its
TikTok account **and** to Instagram as two separate Zernio post documents —
not one post with `crossposting_enabled: true`. This matches how the account
history already worked before this reorg; keep doing it this way.

## Content-reuse rules (unchanged, just made explicit)

- **app-intro**: a third-party app/screenshot may be reused up to 3× across
  posts (`apps.json`'s own note already says this). Before assuming a new
  post needs new screenshots, check actual usage counts — as of 2026-08-05
  all 33 library apps had been used at least once but **none had hit the
  3-use cap**, which is what let posts 017–022 get built entirely from the
  existing screenshot library with zero new asset sourcing.
- **office-talk**: standing approval for new variants of the fixed template
  (hook image from the cleared `app-intro/assets/thumbnails/` pool + 5
  original phrase pairs); no new visual assets needed either.
- **line-story**: new episodes still need real approval; rendering an
  already-approved-in-principle episode from the bank is mechanical.

## line-unfold-video: the BGM gap is closed (resolved 2026-08-05, later same day)

**Superseded.** This section previously said `build.py` could only emit a silent
MP4 and that BGM required an off-repo device pass a Claude Code session couldn't
reproduce. That is no longer true. `build.py` now mixes a track from
`line-unfold-video/bgm/` into the master automatically (loudnorm to −14 LUFS,
1.5 s fade-out), and `bgm/README.md` owns the licensing rule. Verified: posts
001–007 and 013–017 all carry an AAC track, and the copies in Supabase storage
are byte-identical to the local renders.

Pin `"bgm": "<filename>"` in `post.json` once an episode is approved so a later
pool edit can't silently change the audio of an already-reviewed video. All
current episodes are pinned.

Consequence for scheduling: **rendering line-unfold in-session is now the normal
path**, and the "accept fewer posts per cycle" workaround is retired.

### Posts 008–012 were deleted, not blocked

They were never a BGM problem in the end. They were written before
`CONTENT-BANK.md`'s Batch 2 bar and failed it — transactional wins with no personal
shame, nobody who could expose the teller, and twists about outcomes rather than
people. **Deleted 2026-08-05 at Itsuki's instruction**; bank numbers `008`–`012`
are retired and must not be reused. Batch 3 (`013`–`017`) replaced them and is
live on Saya + Instagram for Aug 7–8.

### Result copy needs no shipping-app verification

Itsuki's ruling, 2026-08-05: the draft/result pair shown in the product image is
**story content**, like any other bubble — it does not need to be reproduced in
the shipping app before publishing, and there is no verification gate. Write it
plausible and in-character for the command. This replaces the old
`resultVerified` gate, which no episode had ever actually passed.

## Automation status

The three Codex scheduled tasks under `~/.codex/automations/` —
`tiktok-daily-controller`, `tiktok-publish-monitor`, `tiktok-weekly-review` —
were all set to `status = "PAUSED"` on 2026-08-05. Itsuki's stated reason: the
daily agent-driven loop was burning tokens on decisions he'd rather make
manually in batches. To resume any of them, edit `status` back to `"ACTIVE"`
in that automation's `automation.toml`.

## 2026-08-11 batch — what is scheduled

41 posts created, nothing existing touched. Episode-level detail (争点, twist,
BGM, post IDs) lives in each bank; this is the coverage summary.

| Account | Platform | Episodes | Covers |
|---|---|---|---|
| Saya | Zernio | 026–034 (9) | 8/11 15:00 → 8/14 09:00 |
| yuri | Zernio | 019–027 (9) | 8/13 12:00 → 8/15 22:00 (resumes after the scheduled #13–#18) |
| natsumi | Buffer | 007–014 (8) | 8/11 16:00 → 8/13 22:00 |
| Instagram | Zernio | 15 cross-posts | 8/11 → 8/13, 5×/day at 08/12/17/20/23 JST |

Instagram selection is 6 natsumi + 5 yuri + 4 Saya — deliberately workplace-heavy,
because workplace is what has travelled there. Captions there carry the episode
title plus hashtags; TikTok captions stay hashtags-only.

**natsumi 015 is rendered and uploaded but not scheduled** — Buffer's 10-post cap
left only one free slot and it was kept as headroom. Schedule it once a slot frees.
