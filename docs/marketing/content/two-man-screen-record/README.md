# Two-man hook + fixed screen proof

This directory owns production state for the two-person workplace-hook format.
Strategy and evidence stay in `../../gtm/viral-format-research.md`; the reusable
creative rules stay in the `produce-two-man-screen-hook` skill.

## Current production baseline

- Fixed proof body: `assets/finalcontent.MOV`
- Approved V2 character reference:
  `assets/junior-woman-boss-master-reference-v2.png`
- V2 `@Reference` character assets:
  `assets/female-junior-avatar-v2.png` and `assets/boss-avatar-v2.png`
- V1 character reference retained for history:
  `assets/junior-senior-master-reference-v1.png`
- Current opener: `assets/higgsfield-opener.mp4` (V1 baseline only)
- Final render: `output/two-man-hook-final.mp4`
- Publish treatment: no baked-in music; use Buffer notification publishing and
  finish the post in TikTok so a native library sound can be selected manually.
- Audio target: dialogue/narration near -16 to -18 LUFS before TikTok music is
  added.

Do not change the proof body while testing hooks. Do not bake music into the
master: the selected TikTok sound should sit quietly under the spoken audio.

## V3 hook awaiting generation

Variable under test: a contrarian replacement of the ChatGPT copy/paste
workflow inside the same two-person workplace wrapper. CTA and proof body
remain fixed.

Dialogue:

- Junior: 「上司にLINEするたび、ChatGPTにコピペしてて…」
- Senior: 「2026年に、まだコピペしてるの？」

Shot rhythm:

1. Start with the junior already speaking. No establishing shot or silent
   lead-in.
2. Cut to the senior for the reply within 0.2 seconds.
3. Cut directly from 「まだコピペしてるの？」 into the real keyboard proof;
   keep only a very short reaction if it improves the transition.

Generation constraints:

- Seedance 2.0, 9:16, 5 seconds, 720p, using the approved V2 reference as the
  start image. Trim the opener to approximately 4.4–4.7 seconds during assembly
  if the generated reaction tail drags.
- Native Japanese dialogue with restrained office ambience and no music.
- No generated captions, text, logos, signs, readable documents, or visible
  screens.
- Inspect the live model list and Seedance schema immediately before spending
  credits. Generate one clip, then stop for review.

Higgsfield setup:

1. Use **AI Video → Seedance 2.0**, not Marketing Studio / Product Ad Generator.
2. Use `junior-woman-boss-master-reference-v2.png` as the start image.
3. Create or upload the two solo assets as reference characters named exactly
   `FemaleJunior` and `Senior`. The existing boss portrait is playing the role
   of a senior coworker in this hook.
4. Insert both characters from Higgsfield's `@Reference` picker so they appear
   as real reference tokens in the prompt; typing plain `@` text is not enough.
5. Use the short prompt below. Long prompts make motion and speaker adherence
   worse.

Website-ready Seedance prompt:

```text
Vertical 9:16 photorealistic Japanese office comedy, five seconds. Use @FemaleJunior as the standing junior on the left and @Senior as the seated senior coworker on the right. They look only at each other, never at the camera.

0.0–2.7s — Only @FemaleJunior speaks. Slightly embarrassed, she says exactly: 「上司にLINEするたび、ChatGPTにコピペしてて…」

2.7–4.3s — Only @Senior speaks. He looks at her with dry disbelief and replies immediately: 「2026年に、まだコピペしてるの？」

4.3–5.0s — No dialogue. @FemaleJunior gives a brief caught-out reaction.

Fast hard cuts: tight two-shot, junior close-up, senior close-up. Natural Japanese lip movement and quiet office ambience. No other speech, narration, selfie framing, product mention, captions, text, logos, or visible screens.
```

Website settings: Seedance 2.0, image-to-video, 9:16, 5 seconds, 720p, V2
reference image as the start image, both `@Reference` characters attached, and
native audio enabled. Generate one result.

## Music handoff

Automatic TikTok publishing cannot add library music. The intended route is
Buffer notification publishing after confirming an active member device. The
phone handoff opens the post for completion in TikTok, where the user selects a
current sound and keeps it low enough that every spoken line remains clear.

## V2 review gates

1. Approve the dialogue and shot rhythm above.
2. Authenticate the Higgsfield CLI, inspect the live Seedance schema, and
   generate exactly one opener.
3. Review the raw opener before captioning or assembly.
4. Assemble with `finalcontent.MOV`, validate the full video, and only then
   prepare a Buffer notification draft.
