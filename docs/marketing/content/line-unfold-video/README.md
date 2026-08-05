# LINE unfold video

A deterministic 1080 × 1920 video template inspired by the progressive chat
reveal format. The whole message rhythm is visible as blank bubbles from the
opening frame; each bubble then receives its text in order.

Approved concepts and production scripts live in `CONTENT-BANK.md`.

This is a separate experiment from the fictional LINE-story slideshow. Do not
put its posts into `line-story/episodes/` or publish them through that format's
automation.

## Visual contract

- 1080 × 1920, 30 fps H.264 MP4.
- LINE-blue conversation field (`#8FAED2`).
- Incoming bubbles are white; outgoing bubbles use LINE green (`#84E26F`).
- No avatar, chat header, LINE wordmark, copyrighted sticker, or real identity.
- All future bubbles remain visible as empty silhouettes. Revealed copy appears
  in-place without changing the bubble geometry.
- TikTok supplies its own search, progress, and navigation chrome. None of it is
  baked into the exported video.
- Keep the top and bottom safe areas free of messages for TikTok's overlays.

## Input

Each `posts/NNN-slug/post.json` owns the duration and one to four conversation
pages. A text message specifies `side`, `text`, and `time`. The browser measures
the invisible future text so every blank silhouette already has its final
content-fitted size. An image message adds `type: image`, a local `src`, and its
display dimensions.

`productAssets` can render the audited `line-story` product-result UI into a
local image before the chat frames are captured. Use this for the single proof
image rather than building another app mockup.

`001-visual-prototype` contains placeholder copy from the supplied reference.
`001-foreign-girlfriend` is the first production draft; it is not approved for
publication until its AI result is verified in the shipping app.

## Render

```bash
python3 docs/marketing/content/line-unfold-video/build.py 001-foreign-girlfriend
```

Outputs:

```text
posts/001-foreign-girlfriend/render/preview.png
posts/001-foreign-girlfriend/render/preview-page-1.png ...
posts/001-foreign-girlfriend/render/states/p01-00.png ...
posts/001-foreign-girlfriend/render/line-unfold.mp4
```

The build requires Chrome and ffmpeg. It snapshots one deterministic frame per
reveal state, then holds each state for the configured interval. No asset is
uploaded or published.
