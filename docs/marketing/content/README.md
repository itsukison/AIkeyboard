# Content production namespaces

One directory per **content format**. A format owns its templates, its input
specs, and its rendered slides. Do not put a post for one format inside
another's tree, and do not share templates across formats — a format is the unit
we test, keep, or kill.

| Namespace | Format | Status | Owning GTM doc |
|---|---|---|---|
| `line-story/` | Fictional LINE-style workplace chat slideshow | In production, automated | `../gtm/spicy-content-bank.md` |
| `app-intro/` | App-curation slideshow (hook image → 5 app cards → CTA) | Hook test, unpublished | `../gtm/viral-format-research.md` |

## line-story/

```
line-story/
├── CONTENT-BRIEF.md          production brief for the format
├── templates/                line-chat.html, product-ui.html, shared scenes.js
└── episodes/NNN-slug/        episode.json, README.md, build.py, render/
```

Episode slugs must match `^\d{3}-[a-z0-9-]+$`. The automation reads this tree:

- `integrations/poke-mcp/src/core.ts` — `contentRoot` points at
  `line-story/episodes`; `listEpisodes()` only sees dirs matching `^\d{3}-`.
- `scripts/marketing/render_tiktok_episode.py` — `TEMPLATES` points at
  `line-story/templates`.
- `scripts/marketing/upload_buffer_slides.py` — takes an episode directory and
  reads `render/instagram/cap/*.png`.
- Per-episode `build.py` resolves templates as `HERE.parents[1] / "templates"`.

Moving or renaming anything in `line-story/` means updating those four call
sites. `docs/marketing/automation/state.json` stores episode slugs that are
resolved through `episodePath()`, so in-flight scheduled posts break if a slug
changes.

## app-intro/

```
app-intro/
├── README.md                 format spec, hook variants, open items
├── apps.json                 library of app cards (copy, screenshot, crop)
├── template/app-intro.html   hook / app / cta slide renderer
├── build.py                  renders one post's slides
├── assets/{apps,thumbnails}/ app screenshots and hook images
└── posts/NNN-slug/           post.json, render/
```

`post.json` picks which app ids from `apps.json` a post shows and in what order.
Each post introduces different apps; only `keigobutton` repeats across posts.
Instagram sizing only (1080 × 1350).

This format is **not** wired into the automation. `validatePublishRequest()` in
poke-mcp requires the LINE fiction disclosure in every caption, so app-intro
posts cannot be published through that path without a change. Rendered slides
land in `render/instagram/cap/` on purpose: that is the layout
`upload_buffer_slides.py` already expects, so the upload helper works unmodified
once a post is approved.

## Adding a third format

Create a sibling directory with its own `template/`, its own input spec, and its
own `README.md`, then add a row to the table above. Keep the render output at
`render/instagram/cap/NN.png` (1080 × 1350) if the format should reuse the
existing upload helper.
