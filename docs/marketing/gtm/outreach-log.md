# Outreach log — user emails sent from keigobutton@gmail.com

Purpose: never contact the same user twice. Records every outreach wave and the
dedupe method. Started 2026-07-18.

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
| 1 | 2026-07-11→16 | Power-user 感謝信 (JA/ZH) + churn survey to lapsed users (~200) | see churn-signals.md | ~200 | yes |
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
