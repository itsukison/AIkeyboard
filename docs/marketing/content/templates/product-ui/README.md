# Lightmode product-UI template

Reusable HTML that recreates the **real** 敬語ボタン keyboard surface in light mode,
for the product-proof slides/frames of a chat-story post. It replaces the earlier
Bikey-styled marketing mockups (which used invented chrome like `謝意を伝える`) with
the actual shipped UI, so the proof is honest.

Geometry is measured pixel-for-pixel from the dark-mode reference shots
(`../../marketing_reference/toolbar.jpg` and `result.jpg`, both 1169 px wide) and
scaled by `1080/1169` onto the 1080-wide frame — same key sizes, gaps, and row
rhythm as the shipped keyboard, recolored to the light iOS palette. Flat colors
only: no gradients, no blur (keys use a 1 px hard shadow like real iOS keys).

The area above the keyboard uses the `line-chat.html` blue plus a boss bubble and
composer, so a product frame reads as the keyboard raised inside the same LINE
chat and composites directly with the story frames.

## Keyboard sizing + state consistency (audited 2026-07-23, post 002)

The reference shots come from a 19.5:9 iPhone, but the canvases are 16:9
(TikTok 1080×1920) and 4:5 (Instagram 1080×1350). Rendering the keyboard 1:1
made it read far taller than it feels on device — ~46% of the TikTok frame and
~65% of the Instagram frame, leaving a ~150 px strip of chat on Instagram.
Rules now baked into the template; do not regress them:

- **The tray is always zoomed down.** `.tray` has a per-format `zoom` (`--tz`:
  0.8 on TikTok, 0.62 on Instagram). Never render the tray unscaled, and shrink
  the tray — never the chat — when a frame feels cramped.
- **The result card is exempt from the shrink.** Its dims are written as
  `reference px / --tz`, so the card renders at true reference size (890 px wide,
  40 px text) even though the keys around it are scaled down — the rewrite is the
  payoff of the slide and must stay the most readable element. Card height is
  capped per format (`--card-h`): 400 px rendered on TikTok, 322 px on Instagram.
  **Keep result copy ≤ ~75 chars** (4 lines); Instagram's card clips anything
  longer.
- **The tray height is identical in both states.** `.tray` is a fixed-height
  flex column (856 px intrinsic on TikTok, 876 px on Instagram) with the
  globe/mic row pinned to the bottom; the intrinsic budgets of both states sum
  to the same height (see the comment above `.tray`). In the shipped app the
  result overlay covers the keyboard area without changing its height; a
  draft→result slide pair must not shift any layout.
- **The composer stays visible in `state=result`.** The real overlay leaves the
  host field (with the draft) in place. Pass `draft` to result slides too, so
  the composer shows the pre-rewrite text under the overlay.
- **Instagram compresses like line-chat.** `body.instagram` shrinks the status
  bar, nav, bubbles (31 px), and composer — mirroring `line-chat.html` so story
  frames and product frames stay consistent within a carousel.
- **Chat text is 40 px on TikTok** (bubbles, both templates — they show the
  same conversation) and 41 px in the composer field. Bump both templates
  together or the text visibly jumps between adjacent slides.

Two load-bearing layout rules (don't regress):

- `.phone` sets `grid-template-columns: minmax(0, 1fr)`. Without it the grid column
  is `auto` and the keyboard's intrinsic width pushes the whole frame past 1080 px,
  clipping the right-hand keys (o/p, 改行) off the edge.
- `.key.space` is `flex: 1 1 0` (fills the row), not a fixed width. Fixed widths for
  every key in row 4 summed past the frame and forced the overflow above.
- `.status-bar` has a white background to match `line-chat.html`; otherwise the phone
  blue shows through and a blue strip appears above the nav.

Two states, rendered on the same 1080-wide phone frame so they drop straight into
the carousel next to `line-chat.html` exports:

- **`state=toolbar`** — the collapsed keyboard: host field with the blunt draft, the
  `敬語` pill (highlighted) + `…` above a native-looking light keyboard. This is the
  "tap 敬語" slide. Mirrors `marketing_reference/toolbar.jpg`, recolored to light.
- **`state=result`** — the AI result overlay: the `敬語` pill + close, the selected
  candidate card in a carousel, and the real refinement bar
  (`再作成 / より丁寧に / より詳しく`). The composer stays visible with the draft,
  exactly like the shipped flow. This is the "sendable result" slide. Mirrors
  `marketing_reference/result.jpg` (which was dark), recolored to light.

## URLs

Open `product-ui.html` with query parameters:

```text
product-ui.html?state=toolbar&scene=creepy-boss&step=2&draft=...&format=tiktok
product-ui.html?state=result&scene=creepy-boss&step=2&result=...&format=tiktok
product-ui.html?state=toolbar&incoming=...&draft=...&format=instagram   (legacy single-bubble)
```

- `state`: `toolbar` (default) or `result`
- `format`: `tiktok` (1080 × 1920, default) or `instagram` (1080 × 1350)
- `scene` + `step`: render the real conversation above the raised keyboard, same as
  `line-chat.html` (`step` messages of the named scene, bottom-anchored, older ones
  scrolled off). This is how a product frame shows the full chat context, not just the
  last message. Scenes live in the shared `../scenes.js`.
- `draft`: the blunt pre-send draft shown in the composer. Shown in **both** states —
  always pass it to result slides as well, since the shipped overlay leaves the
  host field in place. Long drafts wrap to a second line instead of clipping.
- `result`: the rewritten message shown in the candidate card (result state). The card
  is centered with the next candidate peeking at the right edge.
- `incoming`: legacy fallback — a single boss bubble when no `scene` is given.
- `chat`: `off` to hide the context area (e.g. when layering over a line-chat frame)

`scene`/`step` load `../scenes.js`, so headless renders need
`--allow-file-access-from-files` (already in `build.py`). Defaults with no params match
the post 001 pilot draft (`本日中は無理です。明日やります。`).

## Export

Render static frames headless at the design size:

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=1080,1920 --screenshot=out.png \
  "file://$PWD/product-ui.html?state=result&format=tiktok"
```

Use `--window-size=1080,1350` for Instagram.

## Honesty rules (from content-strategy.md)

- Show only shipped chrome and the real flow: tap `敬語` → candidate(s) → refine/replace.
- Do not invent buttons or imply the keyboard silently reads other apps.
- The draft in the host field and the result in the card must be a rewrite that the
  shipped product actually produces — quality-check before publishing.
- Keep the host area generic; do not imitate a specific real app's UI.
