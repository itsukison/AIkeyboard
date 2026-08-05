# app-intro — app-curation slideshow

A second format, separate from the LINE-story system. Structure comes from the
serial-curation and aesthetic-image-hook rows in `../../gtm/viral-format-research.md`.

**Status: four posts rendered. Posts 002–003 are scheduled for 2026-08-01 on
Instagram and TikTok; post 004 remains an unapproved draft.**

Instagram sizing only — 1080 × 1350. TikTok's 1080 × 1920 is intentionally not
produced yet; the template carries a single frame size, so adding it later means
re-introducing a format switch rather than editing numbers.

## What one post is

Six slides:

| Slide | Content |
|---|---|
| 01 | Hook — full-bleed image, series pill, huge Japanese hook line, swipe cue |
| 02–06 | One card per app: screenshot left, copy right |

**There is no closing CTA slide.** 敬語ボタン is card ④, so a download slide
would announce that the list was an ad all along and undo the curation framing
the format depends on. The ask lives in the caption instead.

Ten slides is the TikTok Photo Mode ceiling; `build.py` fails the build if a post
exceeds it.

## apps.json vs post.json

- `apps.json` is a **library** of app cards: name, tagline, detail copy,
  screenshot, natural dimensions, crop, accent colour.
- `post.json` picks which app ids a post shows, **and in what order**, plus the
  hook, its image, caption, and any per-post screenshot override.

The rule for the series: **each post introduces different apps, except 敬語ボタン,
which appears in every post.** So an app id should be reused across posts only
for `keigobutton`. Adding a post means adding new apps to the library, not
recycling the last post's five.

`build.py` enforces this across every post before rendering. It rejects both a
reused third-party app id and the same screenshot assigned to two different app
ids.

Keep used and unused screenshots together in `assets/apps/`. Do not move used
files into another folder: `apps.json` is the source of truth, moving files
would break its paths, and a folder split would duplicate the state already
enforced by the post manifests.

Our app sits at position 4 of 5: deep enough that the list has already earned
credibility, early enough that viewers who drop before the last card still see
it. The unifying theme is apps a working adult keeps for self-improvement, which
is what makes 敬語ボタン belong rather than read as an ad.

Rotate the owned screenshot with `appImageOverrides`: dark → light → chat, then
repeat. The current sequence is 001 dark, 002 light, 003 chat, 004 dark.

## Card layout

Screenshot left at 400 px wide, copy column right. The side-by-side split is
what buys room for a detailed description — roughly 100–120 Japanese characters
per card at a readable 29 px, versus the two lines a stacked layout allowed.

Copy column order: index badge → app name → tagline in the app's accent colour →
hairline → detail paragraph.

## Post inventory

| Post | Mechanism | Apps | 敬語ボタン |
|---|---|---|---|
| `001-identity-callout` | Identity / aspiration | Ahead, stoic., Clubhouse, 敬語ボタン, Duolingo | dark |
| `002-workplace-signal` | Social threat at work | Comet, Notion, Wispr Flow, 敬語ボタン, Substack | light |
| `003-hidden-utilities` | Loss aversion / FOMO | Too Good To Go, Tide Guide, pushr, 敬語ボタン, Genies | chat |
| `004-better-than-books` | Contrarian replacement | Life Reset, Quizlet, Strava, 敬語ボタン, Wabi | dark |

The 12 newly supplied third-party screenshots produce exactly three additional
posts at four new third-party apps per post. All 12 are now allocated, so a
fifth post needs four new third-party screenshots.

Hook lines are hard-wrapped with `\n` and kept to ≤9 full-width characters per
line: at 82 px on a 1080 px frame the usable width is 952 px, so a longer line
overflows.

## Hook variants for later posts

The first three variants are now posts 002–004. One written variant remains:

| Mechanism | Hook | Suggested image |
|---|---|---|
| Secret / exclusivity | 同僚に教えたくない／アプリ、5個 | `NO_ZE.jpeg` selfie |

This is a save-rate hypothesis, not a reach one; judge it on saves. It still
needs four new third-party screenshots before it can become post 005.

## Caption

Each `post.json` owns its finished caption. Captions name the five apps, ask one
comment question, and carry five hashtags matching the publishing limit.
敬語ボタン is named plainly as ④ rather than hiding that it is ours.

With no CTA slide, the comment prompt is the post's single ask, which satisfies
the one-CTA-per-post rule in `viral-format-research.md`. It also sources app
candidates for the next post — something this format needs, since every post
requires new apps.

## Rendering

```bash
python3 build.py 001-identity-callout
python3 build.py --all
```

Output: `posts/<slug>/render/instagram/cap/NN.png` at 1080 × 1350. That path is
what `scripts/marketing/upload_buffer_slides.py` already expects, so the helper
works on these posts unmodified.

`build.py` prefers Playwright's `chrome-headless-shell` over the Google Chrome
app bundle. The app bundle hangs indefinitely when the user already has Chrome
open, regardless of `--user-data-dir`; the headless shell does not. The
per-episode `build.py` scripts under `../line-story/episodes/` still call the app
bundle directly and have the same latent problem.

## Screenshot cropping

Mobbin-sourced screenshots carry a `curated by Mobbin` bar across the bottom.
Each affected entry declares `cropBottomPx`; the template derives an aspect
ratio from `naturalWidth / (naturalHeight - cropBottomPx)` and top-aligns the
image inside a container with `overflow: hidden`. The original files are never
modified.

An app entry may carry `"pending": true` while it is using a stand-in
screenshot; such cards render a loud 「スクショ差し替え前 / 投稿不可」 banner and
`build.py` warns on every run. No entry is pending right now.

## Before this can be published

1. **Confirm image rights for real-person hooks.** Rights for post 001 were
   confirmed by Itsuki on 2026-07-30. Itsuki confirmed all selfie hook assets
   are cleared for use on 2026-07-31.
2. **Do not publish through the poke-mcp path.** `validatePublishRequest()`
   requires the LINE fiction disclosure in every caption, which does not apply
   to this format. Use the separately connected Zernio accounts after approval.

## Unused assets

`assets/apps/brilliant2.webp` is a second Clubhouse screenshot, not Brilliant.
It is unused — kept only so nobody re-downloads it expecting Brilliant. A real
Brilliant screenshot would make a good card for post 002.
