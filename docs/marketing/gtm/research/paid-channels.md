# Paid channels — evidence, tools, gate

Researched 2026-07-27. Point-in-time. Named question: **should we run paid ads (Meta or otherwise), and with what tooling?**

## Gate (the one rule, restated)

No paid acquisition while W1 retention < 25%. Currently 5–18%. 1.0.14 (GPT-Soul +
latency fix, shipped 2026-07-23) targets the two named churn causes; first W1 read
on post-update cohorts lands ~1 week out, and the gate is **two consecutive weekly
cohorts ≥25%** → earliest evidence-based paid decision is **early Aug 2026**.
Until then: ¥0 spend, free research only.

## What our own Apple Search Ads data says

Export: `docs/marketing/ad-keywords/apple-ads-keywords-2149384852.csv`
(campaign ran 2026-06-16 → 2026-07-15, ¥13,503 spend, 891 attributed installs).

| Keyword | Match | TTR | Tap→install CR | Tap-through CPA |
|---|---|---:|---:|---:|
| 敬語変換 | exact | 27.5% | 92.9% | ¥74 |
| 敬語 変換 | exact | 25.0% | 83.3% | ¥103 |
| 敬語 | broad | 11.4% | 497% total* | ¥42 |
| 日本語 キーボード | broad | 3.0% | 11.5% | **¥328** |
| ビジネスメール / 就活メール etc. | exact | — | — | ~0 volume |

\* Judge on **tap-through** CPA: the blended ¥6.17 on 敬語 broad is inflated by
720 view-through installs (saw ad, installed within 24h without tapping).

→ **Keigo-intent queries convert; generic keyboard queries are a money pit (8× worse
CPA).** When the gate opens, ASA exact/phrase keigo keywords at ~¥40–100/install is
channel #1 and the bar every other channel must beat. Negative: 日本語
キーボード-class generic terms. Note the roadmap's Phase 2 engines are organic
(ASO reviews, UGC, PR, referral) — paid sits on top of those, not instead of them.

## Channel ranking when the gate opens

1. **ASA** — restart the exact keigo set above; evidence-backed, cheapest, highest intent.
2. **TikTok Spark Ads** — boost only organic posts that already proved saves/profile
   visits. Our content is the ad; zero creative cost. (RED equivalent for the zh
   segment is a separate decision — zh retains ~half as well; only after retention holds.)
3. **Meta (FB/IG)** — distant third for JP iOS utility installs. If used: Advantage+
   app campaign, JP, iOS-only, optimize on the first-rewrite app event, reuse winning
   TikTok creatives. Meta's real value *today* is the free Ad Library, not spend.

## Free research tools (use NOW, no spend)

- **Meta Ad Library** (facebook.com/ads/library) — competitor creative research.
  Longest-running still-active ads are the only public performance proxy. Search:
  Simeji, LeapMe, 3秒敬語, ATOK, AI-keyboard apps; filter JP.
- **TikTok Creative Center** — keyword insights + top ads by vertical; hook research
  for the live organic program.
- **ASA keyword popularity** in the existing account; AppTweak / Sensor Tower free
  tiers for cross-checks. No good free API exists for App Store popularity outside ASA.
- **Google Keyword Planner** — web-side demand only.

## MCP / API inventory

| Tool | What it is | When to wire it |
|---|---|---|
| `pipeboard-co/meta-ads-mcp` (verified 2026-07-27, 1.1k★) | Remote hosted MCP, badged Meta Business Partner, free plan; 42 tools (campaigns, creatives, insights, interest/geo targeting search). Siblings: TikTok / Google / Snap / Reddit Ads MCPs, one auth | Only once a Meta ad account exists — it manages *our* spend, so premature now |
| Meta Ad Library API | Official, free programmatic competitor-ad search; needs dev account + ID verification | Fits the future autonomous-GTM competitor monitor (GTM.md §Future direction) |
| Apple Search Ads API | Official campaign/keyword reporting for the account we already have | Good first candidate: feed keyword-level CPA into the weekly metrics pull |
| Meta Marketing API | ads_read / ads_management, needs app review | Overkill before any spend |
| TikTok Marketing API | Needs an approved developer app; Creative Center has no official API | Later, with Spark Ads |

## Standing recommendation

1. Spend ¥0 until the gate (two consecutive W1 cohorts ≥25%).
2. Now: Ad Library + Creative Center competitor research to feed the organic program.
3. Gate passes: restart ASA exact keigo set → Spark-boost the top organic post →
   only then reassess Meta, with `meta-ads-mcp` wired up at that point.
