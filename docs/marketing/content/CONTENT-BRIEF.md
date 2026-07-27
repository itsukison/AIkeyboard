# 敬語ボタン — Content Brief (paste-into-AI context pack)

Self-contained context for generating short-form content episodes. Copy this whole
file into any AI session, then use the generation prompt at the bottom. Point of
truth for strategy is `../gtm/GTM.md` and `../gtm/content-strategy.md`; this is the
working distillation for content production. Last updated 2026-07-21.

---

## 1. The product

**敬語ボタン** — a third-party Japanese iOS keyboard with an AI rewrite button. You
type a blunt/honest draft in any app, tap **敬語**, and it rewrites the message into
something you can actually send (polite, business-appropriate). Candidates appear in
a carousel; you can refine (再作成 / より丁寧に / より詳しく) and tap to replace.

Ownable positioning:
> **送りづらい仕事のメッセージを、その場で送れる文章にするキーボード。**

Not a "correct keigo" dictionary account. The recurring story is:
**awkward real message → tension/comedy → in-keyboard transformation → sendable result.**

## 2. Business goal & the one rule

- North star: strategic acquisition (~3億円), 2027. Not a downloads story.
- Current (2026-07): ~2,851 users, activation strong (82% try AI), **retention is
  the crisis** — W1 retention 5–18% (need ≥25%).
- **THE ONE RULE: do not spend on acquisition scale while W1 retention < 25%.**
  Content right now is a *small organic learning program*, not a growth push. Goal
  is to learn which situations attract users who actually run and accept a rewrite —
  not raw views.

Implication for content: **qualified reach beats reach.** A funny video that pulls
in people with zero intent to type keigo makes retention worse. Every post must
carry the product, honestly.

## 3. Who we're for (ICP)

1. **Primary:** Japanese job hunters, new grads, early-career office workers who
   freeze before messaging a boss / recruiter / senior / client.
2. **Adjacent:** anyone who knows what they mean but can't make it sound polite.
3. **Secondary (later):** Chinese speakers working in Japan (RED). Real pain but
   retains ~half as well — do NOT let this redefine the core promise.
4. **Reach-only experiment:** relationship/crush chats. Cap at 1-in-10, tone-only,
   never "win your crush" claims.

## 4. The format (decided)

- **Slideshow-first.** TikTok Photo Mode + Instagram carousel. Cheapest way to test
  which *scripts* earn comments/saves. Promote only proven scripts to video later.
- **6–8 slides.** Progressive reveal: each slide adds one message (the chat "fills
  up" as you swipe).
- **Product enters slides 6–7**, right after the viewer-question beat. Not earlier
  (kills tension), not only at the very end (feels bolted-on).

### Slide structure (chat-story carousel)

1. Hook — full-screen big-text card (the `hook` overlay: dark scrim, 96px bold
   line, series tag pill) stating the situation in one line
2–4. The funny/tense incoming message → escalation / the misunderstanding building
5. The punchline + viewer question 「このあと、何て返す？」
6. Product: the blunt honest draft typed in, 敬語 button visible
7. Product: the rewritten, sendable result
8. The message sent + boss accepts (resolution) + CTA

The **composer box** is the through-line: empty during the story → filled with the
blunt draft at slide 6 → transformed at slide 7 → sent at slide 8.

## 5. The comedy engine (what makes a good episode)

Best-performing + most qualified = **the new-grad taking the boss's ambiguous
message literally.** Funny *and* relatable to the exact ICP, and it makes people tag
their own boss (comments = free research). Keep the boss slightly passive-aggressive
for tension; the resolution must genuinely solve it with the product.

"Spicy" = workplace-relatable friction, NOT romance. Romance pulls unqualified reach
we can't afford right now.

### Episode bank (boss-chat comedy)
- 「今日中にいける？」を移動距離だと思った新卒 ← episode 001 (built)
- 37.3度で休んでいいか上司に確認し続ける新人
- 「なるはやで」を今日中だと思わなかった新人
- 上司の「一旦持ち帰ります」を荷物の話だと思った新人
- CCに部長を入れ忘れてからの謝罪
- 金曜17:58の「月曜朝イチで」
- 既読を付けたまま返信を忘れた翌朝
- 誤字を指摘されたのに試合結果だと思った新人

### Other pillars (see content-strategy.md)
- 仕事の地雷文レスキュー (deadline slip, sick leave, reschedule, second follow-up…)
- この返信、どうする？ (reply-mode feature demo)
- コメントを敬語にします (turn a real comment into the next episode)

## 6. Guardrails (non-negotiable)

- Label invented chats as fiction; generic chat UI, never real names/employers.
- Show only shipped capabilities: rewrite, candidates, replace, refine, custom
  prompts. Never claim dating expertise, invisible reading of other apps, or a
  shipped Chinese keyboard.
- **Quality-check every rewrite you show.** 58% of users who run the AI have never
  accepted a candidate — do not showcase weak or over-formal output. The rewrite in
  slide 7 must be something a real person would actually send.
- Say 「この場面なら送れる例」, not "the one correct answer."
- One CTA per post. Prefer 「返しづらかったメッセージをコメントで教えて」
  (drives engagement AND surfaces real use cases).

## 7. The production pipeline (already built)

Two HTML templates render realistic phone frames; `build.py` exports PNGs.

- `templates/line-chat/line-chat.html` — the LINE-style chat. `?scene=&step=N&hook=&caption=&cta=&format=`
- `templates/product-ui/product-ui.html` — the real keyboard/overlay. `?state=toolbar|pressed|result&draft=&result=&incoming=&caption=&format=`
- Both share the same header + blue so slides composite as one phone.
- `001-boss-progress/build.py` — one scene definition → 8 slides × {tiktok,instagram}
  × {cap,clean}. Copy per episode.

## 8. What an AI should output per episode (so it drops into the pipeline)

Produce this exact structure. Hand it back to the Claude Code session and it gets
wired into the templates + rendered.

```
episode_id:   e.g. 002-sick-day
title:        one line
situation:    the misunderstanding / friction in one sentence
scene:        ordered messages, each: {side: boss|me, text, time, read?}
              (this is the joke building up; 6–7 messages)
incoming:     the boss line the rewrite is replying to
draft:        the blunt/honest version the user would actually type (slide 6)
result:       the sendable rewrite the button produces (slide 7) — QUALITY-CHECKED
captions[8]:  one short caption per slide (the text overlay)
post_caption: the feed caption + 5–7 hashtags
```

Constraints: scene text is short, texty, realistic (no keigo yet — that's the point).
`draft` must sound like a real stressed person. `result` must be genuinely sendable,
not robotic. Captions are punchy, ≤ ~18 JA chars where possible.

---

## Generation prompt (use with any AI)

> You are the content lead for 敬語ボタン. Using the brief above, write 5 new
> boss-chat comedy episodes from the episode bank (or propose better ones that fit
> the ICP and the comedy engine). For each, output the exact per-episode structure
> in section 8. Keep the humor workplace-relatable (never romance), make the boss
> ambiguous/passive-aggressive, and make the `result` rewrite something a real
> new-grad would actually send. Then, for each episode, rate it 1–5 on: reach,
> qualified-impact (attracts the real business-message user), and retention-value.
