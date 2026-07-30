---
name: buffer-publish-content
description: Produce, upload, schedule, publish, and monitor 敬語ボタン social content through Buffer. Use for TikTok photo slideshows, Instagram carousels, Buffer Ideas, social captions and hashtags, publishing approved content-bank episodes, or checking post results.
---

# Buffer Publish Content

Read `/Users/itsuki/Desktop/key/Japanese/AGENTS.md`, then read
`docs/marketing/gtm/GTM.md` and follow its content route. Read
`docs/marketing/gtm/buffer-publishing.md` completely before any upload or Buffer
write.

Keep strategy in the routed GTM files and operational details in the publishing
runbook. Do not duplicate either here.

For normal slideshow publishing:

1. Produce no more than 10 ordered 1080 × 1350 PNG slides using the existing
   repository templates.
2. Render and visually inspect every slide, including text wrapping and bottom
   safe space.
3. Use `scripts/marketing/upload_buffer_slides.py`; reuse the existing
   `marketing-media` bucket. Do not rediscover projects, recreate the bucket,
   inspect Supabase schemas, or retrieve API keys.
4. Call Buffer `get_account` and `list_channels`, then create the post with the
   exact returned TikTok channel ID.
5. Put a funny episode-specific title in `metadata.tiktok.title`. Put only up to
   five high-reach relevant hashtags in `text`; add no prose, CTA, repeated
   title, or fiction disclosure.
6. Poll the Buffer post until `sent` or `error`. Do not report `sending` as a
   successful publication.
7. Record the live URL and update the content bank only after `sent`.

Never publish when the user requested only a draft, review, or preview. Automatic
TikTok publishing cannot add library music; use notification publishing only
when the user will complete the music step on a connected phone.
