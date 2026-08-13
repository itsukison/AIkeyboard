# Viral format research and winning-formula loop

Last updated: **2026-07-30**. Owner: Itsuki.

This file is the handoff for sessions researching organic short-form formats,
hooks, and repeatable creative structures. It records observed references and
the current test direction. It does not own production scripts, publishing, or
performance results; those remain in the content bank, `buffer-publishing.md`,
and the autonomous ledger respectively.

## Scope boundary: this is not the LINE slideshow system

The fictional workplace-chat episodes in `spicy-content-bank.md` belong to the
existing LINE-style slideshow format and its automation pipeline. That is a
separate content system. Do not use those episode scripts as the default input
for this research, convert every spicy story into a custom video, or record a
new product conversation for every episode.

This file explores a **second winning formula** whose fixed body can be reused
at scale. The purpose is to discover a new delivery system, not to repackage the
already-templated LINE stories.

## Objective

Research viral content in and around the AI keyboard / writing-assistant niche,
identify the repeatable structure behind what works, and test candidate formats
quickly. Once a formula wins repeatedly, keep its core payoff stable, produce
many controlled hook variations, and automate production and distribution as
far as quality allows.

The operating sequence is:

1. **Research broadly:** collect relevant posts and separate their hook angle,
   delivery wrapper, body format, product reveal, and CTA.
2. **Explore:** test meaningfully different formats and hook mechanisms instead
   of prematurely committing to the current LINE-style slideshow.
3. **Validate:** repeat promising combinations across new situations and use
   comparable 72-hour evidence. Follow the winner policy in
   `tiktok-autopilot.md`; views alone do not prove a product winner.
4. **Scale:** when a combination repeats, preserve its core content and payoff,
   vary one creative element at a time, then produce and schedule variants in
   volume.
5. **Automate:** template the winning structure, hook inputs, captions, editing,
   QA, publishing, and measurement. Keep real product behavior and human
   approval gates where generation cannot be trusted.

In shorthand: **explore widely → validate repeatability → scale the winner**.

## Mass-production eligibility rule

A candidate format is eligible to test only if it could be mass-produced after
winning. For the current screen-recording hypothesis, that means:

- Record the product proof once, then reuse that same recording across many
  posts.
- Change modular hook inputs such as the opening line, image, generated human
  reaction, dialogue, voiceover, or CTA without changing the proof body.
- A hook must promise the same general payoff shown by the reusable recording.
  It cannot depend on a unique conversation whose details would require a new
  product capture.
- Japanese hook text, captions, logos, phone UI, and product output are added by
  the deterministic editing template or come from the real recording. A
  generative image or video model supplies only visual hook footage that does
  not require exact text or interface details.
- The assembly should be expressible as structured inputs to a template. If a
  concept needs bespoke acting, bespoke chat screens, or manual screen recording
  for every post, it is not a scalable candidate for this track.

Before approving an experiment, ask: **could this exact structure produce at
least 20 credible variants while keeping the same product recording?** If not,
reject it or move it to the separate LINE-slideshow/content-bank workflow.

## Creative vocabulary

Do not treat unlike variables as interchangeable "formats":

- **Hook mechanism:** why the viewer keeps watching, such as loss aversion,
  identity, conflict, curiosity, or a contrarian claim.
- **Delivery wrapper:** how the hook appears, such as text over an image,
  reaction, talking head, or two-person dialogue.
- **Body:** the proof or story after the hook, such as a real screen recording,
  slideshow, skit, or single screenshot.
- **Reveal timing:** when the app or transformation first appears.
- **CTA:** the one action requested at the end.

A winning formula is a repeatable combination of those variables, not merely a
single viral sentence or visual style.

## Research collected so far

This is a hand-collected directional sample, not a normalized dataset. View
counts were recorded at different ages, most engagement fields are missing, and
several examples performed poorly. Treat the examples as hypotheses about
structures to test, not proof that a structure works.

| Reference | Observed format and hook | Recorded result | Production / automation observation |
|---|---|---:|---|
| [Grammarly in 30 seconds](https://www.tiktok.com/@aiforstudents_/photo/7507026546700356869) | Intro slideshow: “how to use Grammarly in 30 seconds”; logo first, then download/setup tutorial | 800 views | About 20 minutes, low effort. Limited variation, but potentially useful as an occasional tutorial. |
| [Students make zero mistakes](https://www.tiktok.com/@itsangelicageorges/video/7039070305586793733) | Talking head: “This is how students make 0 mistakes when they write on their phone” | 8,000 views | About 15 minutes. Potentially repeatable with a consistent presenter voice and new hooks. |
| [Fonts Keyboard demo](https://www.tiktok.com/@fonts.keyboard.ai/video/7553220898145176862) | Simple product demo: typing with music and showing the killer function immediately | 380 views | Manual recording, roughly 120 minutes in the original notes. Little obvious variation by itself. |
| [Office advice](https://www.tiktok.com/@the.finance.engineer/video/7309983475380292910) | Two-person cold open: “Before you go home, can you teach me how to fix this?” followed by an AI-keyboard demonstration | Not recorded | Possible with generated actors, but higher production complexity. |
| [Texting a crush](https://www.tiktok.com/@piffpeterson/video/6835342064369126661) | Two-person problem setup: one person says he ruined a text; the other introduces the keyboard, followed by screen recording | 70,000 views; 180 likes recorded | Strongest recorded reach in this sample. Potentially reproducible with generated human hooks, although the relationship premise is not the core ICP. |
| [YouTuber talking-head](https://www.tiktok.com/@_milaholmes_/video/7311173046759394602) | Personal talking-head story that eventually introduces the app | Not recorded | Hard to reproduce authentically at scale; estimated effort 10 in the original notes. |
| [文法ミスとはさよなら](https://www.tiktok.com/@iwishiwereapenguin/video/7054132325826710785) | Aesthetic image hook: 「使わないなんて損、文法ミスとはさよなら」 followed by app download and correction screen recording | 20,000 views; 3,000 likes recorded | Very low effort. Same proof can support many different opening images and hooks. |
| [RewriteMate slideshow](https://www.tiktok.com/@rewritemate/photo/7594535754085256466) | Slideshow: “When you need to text your boss but sound too casual”; product screenshots, insert flow, App Store CTA | 6 views | Easy to repeat with different hooks, but this example does not establish effectiveness. |
| [Stop using ChatGPT](https://www.tiktok.com/@rewritemate/video/7590402492127513877) | Contrarian screen-record hook: “Stop using ChatGPT to rewrite text, do this instead” | 104 views; 6 likes recorded | Likely automatable. Variation can come from the text or task first given to ChatGPT. |
| [Favorite iPhone apps](https://www.tiktok.com/@aikeyboardapp/photo/7656495585515670797) | Serial app-curation slideshow: “Fav iPhone apps part 18”; aesthetic image, several apps, own app placed in the list | 10 views | Highly templateable, but the observed example is not a proven winner. App metadata/screenshots would need a reliable source. |
| [敬語LINE Bot](https://www.tiktok.com/@keigokun_line/video/7471256328300694792) | Single image: one chat screenshot showing a message rewritten into keigo | 42,000 views for the noted outlier; most posts reportedly stayed around 50 | Extremely cheap and compatible with the existing template. Funny rewrites provide possible variation, but the account-level distribution appears inconsistent. |
| [ao_iphone reference](https://www.tiktok.com/@ao_iphone/video/7481605932267572488) | Details not yet recorded | Not recorded | Revisit and classify before using it as evidence. |
| [AI keyboard reaction](https://www.tiktok.com/@luxyreviewsx/video/7619548027295911199) | Reaction/POV: “POV you found an AI keyboard that helps you write better”; surprised person, then product demonstration | 7 views | Human reaction hooks could be generated in volume, but this example itself did not validate the structure. |
| [まだこのキーボード使ってないよね](https://www.tiktok.com/@takeru_ap/video/7416307485054733576) | Direct callout/introduction: 「まさかまだこのキーボード使ってないよね」 followed by what the keyboard can do | Not recorded | A callout/FOMO hook worth testing; result data is missing. |

### Patterns represented in the sample

- Loss aversion / FOMO: 「使わないなんて損」 and
  「まさかまだこのキーボード使ってないよね」.
- Identity and hidden method: “This is how students…”
- Contrarian replacement: “Stop using ChatGPT…”
- Human conflict: two-person problem and advice setups.
- Discovery/reaction: “POV you found…”
- Time-bound tutorial: “how to use … in 30 seconds.”
- Serial curation: “favorite iPhone apps, part N.”
- Immediate proof: typing, screen recording, or a single before/after screenshot.

The current sample suggests directions, not a winner. The 70,000-view two-person
post, the 20,000-view aesthetic-hook screen recording, and the 42,000-view
single-image outlier deserve replication tests, but each needs comparable
follow-ups before promotion.

## Temporary test direction

The leading hypothesis is a **modular real screen-recording proof** with multiple
opening hooks. This is a test direction, not a final commitment.

Why it is attractive:

- It demonstrates the shipped product rather than merely claiming a benefit.
- A short proof body can be reused beneath different hook wrappers.
- Editing is simple enough to template.
- Hook generation can range from zero-cost text cards to generated human scenes.
- It remains understandable with editor-added captions and can also support a
  continuous voiceover.

### Stable screen-recording body

Create one canonical recording with the real shipping app and show the honest
sequence:

1. A recognizable blunt or awkward draft.
2. Tap the relevant AI command.
3. Briefly show real candidates.
4. Choose one and tap `置き換え`.
5. Hold on the sendable result.

The displayed output must come from the shipping product. Do not let an image or
video model invent Japanese text, keyboard UI, candidate output, or phone-screen
content. During hook and wrapper validation, keep this exact recording fixed.
Do not create a new draft, conversation, or result for each hook.

The canonical draft should demonstrate a broad, recognizable transformation
rather than a story-specific exchange. Hooks may frame the same proof through
different pains or beliefs, but must remain semantically compatible with what
the recording shows. For example, loss aversion, a ChatGPT-copy/paste critique,
a workplace-writing pain, and a discovery reaction can all introduce the same
generic `draft → 敬語 → replacement` proof. A cheating story or bizarre boss
conversation that requires its own matching messages cannot.

Only after a formula wins may the proof layer expand into a small, deliberately
limited recording library. That is a later scaling decision, not part of the
initial hook test.

### Hook directions to explore

- Loss aversion / FOMO
- Direct pain callout
- Identity or audience callout
- Contrarian replacement of the ChatGPT copy/paste workflow
- Transformation challenge or before/after curiosity
- High-stakes workplace situation
- Reaction or discovery
- Two-person conflict with a real punchline
- Time-bound tutorial
- App-curation/list format as a lower-confidence exploration

Test wrappers including text over a simple visual, direct screen-record cold
open, reaction, talking head, and two-person dialogue. Generated human footage
may be used for the hook, but it should contain no generated subtitles, logos,
Japanese interface text, or readable phone screen. Captions belong in the edit.
The human footage must also be modular: it introduces the fixed proof rather
than acting out a unique conversation that forces a new recording.

For spoken variants, the preferred architecture is audio-first: create the full
hook and explanation track with consistent voices, generate or film only the
human opener, then continue the same voice over the real screen recording. The
screen-record body should have editor-added captions as well as voiceover when
the test is specifically a spoken-human format. Text-only variants can retain a
caption-led body.

### CTA directions

Use one CTA per post and do not change hook and CTA in the same controlled test.
The temporary default is the comment/research CTA:

> 次はどの文章を敬語にする？コメントで教えて

It creates the next content inputs while exposing real user pain. Once a hook
and wrapper show promise, separately test:

- **Comment:** ask for the next difficult message.
- **Save:** position the example as something useful to keep.
- **Try/install:** ask the viewer to try the keyboard.
- **Follow:** promise the next transformation or recurring series.

Do not declare the strongest CTA from views alone; compare the downstream action
that the CTA actually requests.

## Running experiment: app-curation slideshow (app-intro)

Built 2026-07-30, **rendered but not published**. Lives in
`../content/app-intro/`; that directory's README owns the production detail.

This is the serial-curation row of the table above ("favorite iPhone apps, part
N") turned into a controlled hook test. It is a second track alongside the
screen-recording hypothesis, not a replacement for it, and it is deliberately
kept out of the LINE-slideshow pipeline.

How it satisfies the mass-production rule: card copy lives in a reusable
`apps.json` library, the slide template is fixed, and a post supplies only a hook
line, a hook image, and which app ids to show. No per-post product capture is
required — 敬語ボタン's card is authored once and reappears in every post.

The format carries **no CTA slide**. Our app is card ④ of five, so a closing
download slide would retroactively mark the list as an ad and cost the curation
framing that earns the swipe. The single ask lives in the caption as a comment
prompt, which also sources the apps for the next post.

Its cost driver is different from the screen-recording track: each post needs a
**new set of app screenshots**, because every post must introduce different apps
(only 敬語ボタン repeats). That is the constraint to watch when judging whether
this format can scale — not editing effort.

One post exists so far, `001-identity-callout`, testing the identity/aspiration
mechanism. Four more hooks are written and line-broken but unrendered, waiting on
new screenshots: loss aversion, contrarian replacement, social judgment at work,
and secret/exclusivity. Because the app set has to change between posts, hooks
cannot be compared over a byte-identical body — treat cross-post comparisons as
directional, not controlled.

Nothing here is validated: no 72-hour evidence, no comparison against the
LINE-story baseline. Judge it by the winner policy in `tiktok-autopilot.md`. Note
that the secret/exclusivity hook is a save-rate hypothesis rather than a reach
one, and that the social-judgment hook is the one closest to the product's real
positioning.

## Boundaries for the next session

The next idea-generation session may use this file to create a bounded test
matrix, exact scripts, generation prompts, and a production queue. It should not
assume that screen recording, Higgsfield UGC, two-person dialogue, or any hook
listed here has already won. Every proposed template must pass the
mass-production eligibility rule above. Do not pull story scripts from
`spicy-content-bank.md`, propose per-episode screen recordings, or merge this
exploration with the automated LINE slideshow pipeline. Keep production and
publishing changes out of the research step until the user approves the
specific experiments.
