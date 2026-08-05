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
| keigobutton (Natsumi) | Buffer / TikTok | office-talk (keigo-rephrase) + line-story (line-template) | 2 office-talk + 1 line-story per day |
| アプリ大好き (ruka_keigobutton) | Zernio / TikTok | app-intro (slideshow) only | 3× / day |
| Saya (mari040715) | Zernio / TikTok | line-unfold (video) only | 3× / day |
| yuna_keigobutton | Zernio / Instagram | line-unfold (Reels) + app-intro (slideshow) | 3× line-unfold + 2× app-intro per day |

Notes:
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

## line-unfold-video: known quality gap — read before scheduling more

`build.py` in `line-unfold-video/` renders a **silent MP4** — no BGM, no
audio pass of any kind. The videos already live on these accounts (001–007)
went through an **additional device-side pass** (BGM + likely other polish)
that does not happen in this repo and that a Claude Code session cannot
reproduce.

Five new scripts (008–012) were written and rendered on 2026-08-05 but were
**not** put through that pass. Their `post.json` files are marked
`"approval": {"status": "needs-rework", "qualityIssue": "..."}` for exactly
this reason. **Do not schedule them as-is.** Either:
1. run them through whatever device/tool adds BGM before scheduling, or
2. treat them as scripts only and re-render/re-shoot once that tooling is
   available in-session, or
3. accept fewer line-unfold posts per cycle (7 existing videos instead of 12)
   until this is resolved.

## Automation status

The three Codex scheduled tasks under `~/.codex/automations/` —
`tiktok-daily-controller`, `tiktok-publish-monitor`, `tiktok-weekly-review` —
were all set to `status = "PAUSED"` on 2026-08-05. Itsuki's stated reason: the
daily agent-driven loop was burning tokens on decisions he'd rather make
manually in batches. To resume any of them, edit `status` back to `"ACTIVE"`
in that automation's `automation.toml`.
