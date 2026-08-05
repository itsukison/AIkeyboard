# Buffer publishing runbook

Last verified: **2026-07-28**. Owner: Itsuki.

Use this for the operational path from an approved content-bank episode to a
live Buffer post. Strategy, episode selection, and editorial rules remain in
`content-strategy.md` and `spicy-content-bank.md`.

## Established infrastructure

- Supabase project: `AIkeyboard` (`eercsucvxnszqletxued`), already linked by the
  local Supabase CLI.
- Storage bucket: `marketing-media`, public-read, authenticated-write, limited
  to PNG/JPEG/WebP and 5 MB per object.
- TikTok asset prefix:
  `https://eercsucvxnszqletxued.supabase.co/storage/v1/object/public/marketing-media/tiktok/`
- Buffer organization: `My Organization`.
- Expected TikTok channel: `keigobutton`.

The bucket already exists. During normal publishing, do **not** call Supabase MCP,
list projects, create buckets, retrieve API keys, or inspect schemas. Never print
or store a `service_role` or secret key. The linked CLI performs authenticated
uploads.

## Produce and validate

1. Read `GTM.md` and only the routed content bank plus the relevant template
   README.
2. Confirm the episode is not already marked published.
3. Use `format=instagram` for TikTok Photo Mode: 1080 × 1350. This keeps the
   story and product UI above TikTok's bottom description overlay.
4. Keep the carousel to at most 10 slides. Condense longer episode flows before
   rendering.
5. Render the `cap` variant and visually inspect every slide. Fix awkward line
   breaks, clipped candidate text, inconsistent chat state, and bottom crowding.

## Upload

From the repository root, run:

```bash
python3 scripts/marketing/upload_buffer_slides.py \
  docs/marketing/content/line-story/episodes/<episode-folder>
```

The helper validates the file count and 1080 × 1350 dimensions, uploads
`render/instagram/cap/*.png` in filename order, then prints the stable public
URLs to use as ordered Buffer image assets.

For an approved `office-talk` post, keep its native 1080 × 1920 TikTok render
and pass the format explicitly:

```bash
python3 scripts/marketing/upload_buffer_slides.py \
  docs/marketing/content/office-talk/posts/<post-folder> \
  --render-subdir render/tiktok/cap \
  --expected-height 1920 \
  --remote-slug office-talk-<post-folder>
```

The default command and 1080 × 1350 validation remain unchanged for LINE
episodes.

If upload fails, inspect the CLI error. Do not fall back to API-key discovery.
Check that the project is still linked and that the bucket exists with:

```bash
supabase storage ls ss:///marketing-media --linked --experimental
```

## Publish through Buffer

1. Call Buffer `get_account` first.
2. Call `list_channels` for the returned organization and select the exact
   connected `keigobutton` TikTok channel ID. Do not rely only on a stored ID.
3. Write a funny, episode-specific title for `metadata.tiktok.title`.
4. Put only up to five high-reach, topic-relevant hashtags in Buffer's `text`
   field. Do not add prose, a CTA, the title again, or any fiction disclosure.
   Use recent TikTok results to prefer tag combinations associated with stronger
   reach; do not blindly reuse the same set for every topic.
5. Call `create_post` with:
   - ordered `{ image: { url } }` assets;
   - `metadata.tiktok.title` for the photo-post title;
   - `schedulingType: automatic`;
   - `mode: shareNow`, `customScheduled`, or `addToQueue` as requested.
6. Poll `get_post` until `status` is `sent` or `error`. TikTok photo posts may
   remain `sending` for roughly two minutes. A successful result includes
   `sentAt` and `externalLink`.

Automatic publishing does not support TikTok library music. For a music post,
use notification publishing only after Buffer reports an active member device;
the user must select the sound and finish in TikTok.

## Record the result

After `sent`:

- add the TikTok URL, publish time, and Buffer post ID to the episode README;
- move the episode from remaining stock to produced in the owning content bank;
- pull Buffer metrics after enough time has elapsed, using the content-result log
  fields in `content-strategy.md`;
- judge repetition on qualified engagement and product outcomes, not views alone.

Episode 014 is the reference implementation:
`docs/marketing/content/line-story/episodes/014-sick-day-pressure/`.
