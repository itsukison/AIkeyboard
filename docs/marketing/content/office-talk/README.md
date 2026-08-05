# office-talk — 職場の本音と言い換え

Japanese workplace slideshow inspired by the supplied 20k-view reference. This
is a separate format from LINE fiction, app curation, and the two-person video.

**Status: in production; automated as one of three daily TikTok posts.**

Live post: [TikTok](https://tiktok.com/@keigobutton/video/7670025056667389191)
(`001-mou-muri`, Buffer post `6a716725e7bbda897d6b1f59`).

## Why the reference worked

The reference combines four mechanisms in one very cheap format:

1. A human face and a censored taboo phrase stop the scroll before the post
   looks educational.
2. The hook creates an open loop: the viewer immediately wants the socially
   acceptable version of a thought they have had at work.
3. Every swipe delivers a complete before/after payoff, so the post is useful
   even if the viewer does not reach the end.
4. The numbered list promises a finite reward and encourages completion and
   saves. The visual system stays almost identical, so reading is effortless.

The 20k result is one directional reference, not proof of a repeatable winner.
This format still needs comparable 72-hour tests under the winner policy in
`../../gtm/tiktok-autopilot.md`.

## Japanese adaptation

The Japanese equivalent is not a literal translation of English corporate
euphemisms. The sharper tension is **本音ではこう言いたい vs. 角を立てずにどう
返すか**. That is native to Japanese workplace communication and directly
matches 敬語ボタン's shipped benefit.

Use blunt but common inner thoughts on the dark card and a natural, sendable
rewrite on the lavender card. Avoid stiff textbook honorifics: the replacement
should sound like something a working adult would actually send in Slack,
LINE, or email.

The hook image should express the emotion in the hook rather than merely look
aesthetic. Real-person assets need confirmed usage rights. The first prototype
uses the cleared stressed mirror selfie at
`../app-intro/assets/thumbnails/_ (5).jpeg`; later variants can swap only this
image while preserving the five phrase cards and CTA.

## One post

Seven 1080 × 1920 TikTok Photo Mode slides:

| Slide | Content |
|---|---|
| 01 | Human/image hook + taboo or high-recognition workplace thought |
| 02–06 | Five numbered 「本音」→「角が立たない言い方」 typographic slides |
| 07 | One product CTA with the real 敬語ボタン app icon |

TikTok Photo Mode allows ten images; `build.py` fails if the post exceeds that.

The body is deliberately fixed-shape and data-driven. A post changes only the
hook image/copy, five phrase pairs, CTA copy, and caption. It therefore passes
the mass-production test in `../../gtm/viral-format-research.md`: at least 20
credible variants can be produced without bespoke acting or product capture.

## CTA

The final slide uses the real bundled app icon and one action only:

> App Storeで「敬語ボタン」

The product appears only after six useful slides, so the post earns attention
before revealing the promotion. Its App Store prompt is treated as a restrained
editorial footer, not a second glossy card. Do not also ask for comments, saves,
or follows in the caption during the initial controlled test. Once the hook/body
has shown promise, test a comment CTA separately without changing the hook at
the same time.

## Input model

Each `posts/<slug>/post.json` owns:

- `hook`: eyebrow, main line, supporting line, image, and image position
- `phrases`: exactly five `blunt` / `polished` pairs
- `cta`: headline, detail, fixed action label, and real app icon
- `publish`: TikTok title and one to five hashtags
- hypothesis and approval state

Episode slugs follow `^\d{3}-[a-z0-9-]+$`.

## Rendering

```bash
python3 build.py 001-mou-muri
python3 build.py --all
```

Output: `posts/<slug>/render/tiktok/cap/NN.png` at 1080 × 1920.

## Automated production

The daily controller reads `tiktok_agent_state.py next-plan`. When an
`office-talk` slot has no approved unpublished stock, it creates the next
numbered post automatically. This is a standing approval for variants of this
fixed format, not for a new format or a change to the CTA.

- Reuse only cleared local hook images under `../app-intro/assets/thumbnails/`;
  never use the reference screenshots as production assets.
- Write one recognizable workplace frustration and five original, natural
  Japanese before/after pairs. Do not copy a prior post's phrase set.
- Put deliberate newlines in every hook, phrase, and CTA field. No explicit line
  may exceed the limits enforced by `build.py`, and one-character orphan lines
  fail validation.
- Use the real app icon and the fixed `App Storeで「敬語ボタン」` action.
- Set `approval.status` to `approved` only inside this bounded format. Set
  `approval.visualQA` only after inspecting all seven rendered images.
- Run `build.py <slug> --validate-only --check-publishable` before upload, then
  upload with the office-talk flags in `../../gtm/buffer-publishing.md`.

## Reference screenshots

The three `スクリーンショット 2026-08-03 … .png` files are analysis references,
not production assets. Do not publish or reproduce their creator handle,
photograph, wording, or green visual identity.
