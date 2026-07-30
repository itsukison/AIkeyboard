# app-intro — app-curation slideshow

A second format, separate from the LINE-story system. Structure comes from the
serial-curation and aesthetic-image-hook rows in `../../gtm/viral-format-research.md`.

**Status: one post rendered, not approved, not published.**

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
  hook and its image.

The rule for the series: **each post introduces different apps, except 敬語ボタン,
which appears in every post.** So an app id should be reused across posts only
for `keigobutton`. Adding a post means adding new apps to the library, not
recycling the last post's five.

Our app sits at position 4 of 5: deep enough that the list has already earned
credibility, early enough that viewers who drop before the last card still see
it. The unifying theme is apps a working adult keeps for self-improvement, which
is what makes 敬語ボタン belong rather than read as an ad.

## Card layout

Screenshot left at 400 px wide, copy column right. The side-by-side split is
what buys room for a detailed description — roughly 100–120 Japanese characters
per card at a readable 29 px, versus the two lines a stacked layout allowed.

Copy column order: index badge → app name → tagline in the app's accent colour →
hairline → detail paragraph.

## Current post

`001-identity-callout` — identity / aspiration mechanism.

```text
頭よく見える人の
iPhoneに入ってる
アプリ、5個
```

Apps: `Ahead → stoic. → Clubhouse → 敬語ボタン → Duolingo`. Image: `🐰.jpeg`.

Hook lines are hard-wrapped with `\n` and kept to ≤9 full-width characters per
line: at 82 px on a 1080 px frame the usable width is 952 px, so a longer line
overflows.

## Hook variants for later posts

Written and line-broken, waiting on new app screenshots. Each is a different
mechanism, and each stays compatible with any self-improvement app set.

| Mechanism | Hook | Suggested image |
|---|---|---|
| Loss aversion / FOMO | 入れてないだけで／損してるアプリ5個 | `_ (1).jpeg` device mockup |
| Contrarian replacement | 自己啓発本より、／このアプリ5個 | blank-icon mockup |
| Social threat at work | 「仕事できない人」／だと思われる理由、／スマホの中にある | `_ (4).jpeg` face-obscured selfie |
| Secret / exclusivity | 同僚に教えたくない／アプリ、5個 | `NO_ZE.jpeg` selfie |

The social-threat hook is the closest to the product's real positioning, so it
is the most informative one to run next — it reads whether the
workplace-judgment angle travels outside the LINE-story format. The
secret/exclusivity hook is a save-rate hypothesis, not a reach one; judge it on
saves.

## Caption

```text
①Ahead ②stoic ③Clubhouse ④敬語ボタン ⑤Duolingo

他に入れとくべきアプリある？コメントで教えて

#iphone神アプリ #アプリ紹介 #社会人 #仕事術 #敬語
```

Five hashtags, matching the publishing runbook's limit. The caption names
敬語ボタン as ④ plainly rather than hiding that it is ours.

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

`assets/apps/*.webp` are Mobbin-sourced and carry a `curated by Mobbin` bar
across the bottom 120 px (identical on all five, re-confirmed for
`duolingo.webp`). The template clips it by deriving an aspect ratio from
`naturalWidth / (naturalHeight - cropBottomPx)` and top-aligning the image
inside a container with `overflow: hidden`. The original files are never
modified.

An app entry may carry `"pending": true` while it is using a stand-in
screenshot; such cards render a loud 「スクショ差し替え前 / 投稿不可」 banner and
`build.py` warns on every run. No entry is pending right now.

## Before this can be published

1. **Confirm image rights.** The hook is a real, identifiable person. Itsuki
   confirmed rights on 2026-07-30; that confirmation is the only thing standing
   behind it.
2. **Do not publish through the poke-mcp path.** `validatePublishRequest()`
   requires the LINE fiction disclosure in every caption, which does not apply
   to this format and would have to change first.

## Unused assets

`assets/apps/brilliant2.webp` is a second Clubhouse screenshot, not Brilliant.
It is unused — kept only so nobody re-downloads it expecting Brilliant. A real
Brilliant screenshot would make a good card for post 002.
