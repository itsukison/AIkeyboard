# Outreach log — user emails sent from keigobutton@gmail.com

Purpose: never contact the same user twice. Records every outreach wave, the
dedupe method, and the standing playbook. Started 2026-07-18.
Absorbed the email playbook and reply tally from `churn-signals.md` on 2026-08-13.

## Dedupe protocol (run before EVERY wave — this is the source of truth)

Sent-mail is the authoritative record; don't rely on the tables below being complete.
Before drafting, take the candidate email list and query Gmail:

```
search_threads: in:sent (to:<email1> OR to:<email2> OR ... )
```

Any address that returns a hit has already been contacted — drop it. (Verified working
2026-07-18: the wave-2 batch of 20 returned empty = none previously mailed.)
Constraints from memory `user-outreach-email-style`: business-polite JA/ZH, drafts only
(Itsuki sends), never email 717natsuki@gmail.com.

## Waves

| # | Date drafted | Segment / criteria | Template | Count | Sent? |
|---|---|---|---|---|---|
| 1 | 2026-07-11→16 | Power-user 感謝信 (JA/ZH) + churn survey to lapsed users (~200) | 感謝信 + numbered churn survey (see below) | ~200 | yes |
| 2 | 2026-07-18 | High-intent JP churners: signed up 7–14d prior, 0 rewrites in 7d, geo=JP, locale ja/en, Japanese names (zh-locale excluded) | 「孫です。敬語ボタン、正直どうでしたか？」numbered churn survey | 20 | drafts created, pending Itsuki send |

### Wave 2 recipients (2026-07-18) — 20, deduped clean vs wave 1

Personalized greeting (name+さん) where the display name is a real name; generic こんにちは for handles.

```
hiroaki.138219@docomo.ne.jp, fctomi3@yahoo.co.jp, chisq_nori0204@yahoo.co.jp,
info@dub-design.com, riyuuta11@icloud.com, tomato060621@icloud.com,
kiyora.0509@gmail.com, jnfmmg@gmail.com, tennedar0@protonmail.com,
syou5648@icloud.com, kazabana33@gmail.com, kzk11.acount@gmail.com,
akaned31@gmail.com, yukiquill@gmail.com, daianna.online@gmail.com,
426rrr.p@gmail.com, yaqif94@gmail.com, animefansys9@gmail.com,
meoriruru366@outlook.com, setmieresh0447@gmail.com
```

Note: even after excluding Chinese email domains AND zh-locale, only ~20 of 95 non-Chinese-domain
churners in this window were confidently Japanese — the post-RED signup cohort is Chinese-dominated.

---

## Standing playbook

Constraints (memory `user-outreach-email-style`): business-polite register JA/ZH, easy general
questions, **drafts only** — the Gmail connector creates drafts, Itsuki sends. Never email
717natsuki@gmail.com. **Always dedupe against the waves above first.**

1. **High-intent churn survey (small, re-targeted — decided 2026-07-18).** The scaled cold blast is
   retired: ~3% reply rate and it over-samples low-intent RED churners. Instead, each Friday draft a
   *small* (~20–30) personal survey to high-intent churners only — `ja`-locale / organic (non-RED)
   signups from 7–14 days ago with 0 rewrites in 7 days. Pull the list from Supabase, then tighten to
   geo=JP + locale ja/en + Japanese names via PostHog. These had the problem and still left = real
   product churn. Personal Gmail, never automated — the founder tone is the response-rate lever.
2. **Power-user interview (monthly).** Top-20 by active days → 感謝信 format. Personal Gmail.
   **All 16 current power users were active within the last 8 days** — n=16 is too small for
   statistics but ideal for interviews. Two questions worth more than the rest: to the two users who
   authored their own 「友達」 buttons, *what made you write it, and what would have made it
   unnecessary?* And to the outlier at 67% refinement / 7% acceptance, *what were you trying to get
   it to do?*
3. **Winback (after fixes ship) — via Loops, not Gmail.** "You said X, we fixed X" to every user who
   reported a now-fixed issue; doubles as reactivation. This is the one *scaled* email job. Requires
   Loops standing up (Supabase `auth.users` → segment → template, verified sending domain +
   SPF/DKIM/DMARC + unsubscribe + 特定電子メール法 compliance). **Not before a shippable fix exists** —
   no bulk infra ahead of one.
4. **Consent/opt-in ask** to engaged users when the new consent UX ships.

## Churn-survey replies (running tally)

Wave 2 v1 had 5 options; v2 added kana-kanji accuracy. Options: 1 usability/UI, 2 AI rewrite
accuracy, 3 kana-kanji conversion accuracy, 4 no use case, 5 missing feature, 6 other.

**⚠️ n = 6 substantive replies / ~200 sent (~3%). Hypothesis-generating only — never reprioritize the
roadmap on this table alone.**

| Reason | Count |
|---|---|
| 1 usability / UI feel | 1 |
| 2 AI accuracy | 1 |
| 3 kana-kanji accuracy | 0 |
| 4 no use case | 0 |
| 5 missing feature (reply-suggestion) | 1 |
| praise only | 2 |

Signals worth carrying forward:

- **Keyboard "feel" ≠ native → silent churn.** One reply: the AI button pinned at the far left of the
  candidate bar 「破坏苹果原生态键盘的视觉感受」, missed native spelling suggestions,
  「手感有变化就一直没有继续使用」, 「还得动脑子用」. This is the qualitative half of the toolbar-width
  hypothesis (`hypothesis-ledger.md` #21).
- **Reply-suggestion demand exists but wasn't found** — a user asked for auto-reply for daily chat;
  the feature already exists via prompts. Note this is a *discoverability* claim that the power-user
  data contradicts on *demand* (reply is 0.8% of power-segment volume), and reply-pill exposure is
  still uninstrumented, so the two cannot be separated yet.
- **Willingness to pay exists** — 「后续如有收费项目也可以理解」, unprompted.
- **The container UI is an asset, the keyboard feel is the liability** — 「还留着是因为软件UI做的太漂亮了」.

## Persona note — Chinese speakers in Japan

A large share of engaged users are Chinese speakers living/working in Japan or learning Japanese
(qq/163/126 addresses throughout; power users writing business mail to 日方). They have the keigo pain
*and* the JP-input pain simultaneously, and ChatGPT is their current workaround.

**Do not promote this to primary ICP on engagement anecdotes.** It is the largest segment by volume
and the worst on `keyboard_usage_day` retention, though the gap does **not** replicate on rewrite
retention — see `hypothesis-ledger.md` #14 and `retention-and-users.md` §7. Treat it as an
acquisition and early-revenue channel.
