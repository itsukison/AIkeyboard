# LINE-style fictional chat template

Reusable HTML for TikTok/Reels video and slideshow frames. It intentionally
recreates the familiar proportions and interaction chrome of a Japanese mobile
messenger without using LINE logos, copyrighted stickers, or a real conversation.

All chats must be disclosed as fiction in the post caption. The disclosure stays
out of the artwork so the chat screen remains visually clean.

## URLs

Open `line-chat.html` with query parameters:

```text
line-chat.html?scene=progress&step=4&format=tiktok
line-chat.html?scene=sick-day&step=6&format=tiktok
line-chat.html?scene=progress&animate=1&format=tiktok
```

- `scene`: any key in `../scenes.js` (shared with `product-ui.html`), e.g.
  `progress`, `creepy-boss`, `saturday-work`
- `step`: number of messages to reveal for a static slideshow frame. `step=0`
  renders the empty chat (composer only) — the opening frame of a progressive reveal.
- `innervoice`: text for a full-bleed 心の声 overlay (the furious inner monologue).
  Dims the chat behind it; combine with a `step` to keep the violation visible.
- `hook`: text for a full-bleed opening overlay (slide 1). Same look as
  `innervoice` — dark scrim + huge bold text — but the tag pill is driven by
  `hooktag` (e.g. `丁寧にキレる。`) and omitted when `hooktag` is empty. Use `\n`
  for manual line breaks; pair with `step=0`.
- `cta=1`: full-bleed closing overlay (final slide) — app icon, 「敬語ボタン」,
  and an App Store download pill over a dark scrim. `ctatag` sets the series
  pill (same rules as `hooktag`), `ctacopy` overrides the one-liner. Pair with
  the episode's final `step`; the scrim is deeper than the hook's so the white
  text stays readable over the full conversation.
- `animate=1`: reveal the entire chat as a timed animation for video capture
- `format`: `tiktok` or `instagram`

Render static exports at 1080 × 1920 for TikTok or 1080 × 1350 for Instagram.
The same HTML can be recorded for a vertical video; messages animate in sequence
when `animate=1`.

The interface is drawn on a fixed 1080 × 1920 design frame and the complete frame
is scaled uniformly to fit the browser. This keeps typography, icons, bubbles, and
spacing at true mobile proportions instead of reflowing them at narrow widths.

Bubble text is 40 px on TikTok and 31 px on Instagram — keep both in sync with
`product-ui.html`, which shows the same conversation above the raised keyboard.
Mismatched sizes jump visibly between adjacent carousel slides (audited
2026-07-23, post 002).

## Adding an episode

Add one object to `SCENES` in `../scenes.js` (loaded by both templates). Each
message uses:

```js
{ side: "boss", text: "今日中にいけそう？", time: "16:42" }
{ side: "me", text: "正直、厳しいです…", time: "16:43", read: "既読" }
```

Keep the copy fictional and use no real names, employers, profile images, or
private messages without permission.
