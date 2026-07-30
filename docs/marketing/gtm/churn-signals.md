# Churn signals — email campaign + data

Started 2026-07-18. Source: keigobutton@gmail.com outreach (July 11–16, ~200 churn-survey emails JA/ZH + power-user thank-you interviews) cross-read with Supabase/PostHog data. Update as replies arrive.

## Campaign facts

- **Wave 1 (Jul 11–13)**: 感謝信 to power users — "what scenes do you use it in / what should we fix". JA + ZH.
- **Wave 2 (Jul 13–16)**: churn survey to lapsed users, one-tap numbered answers. v1 had 5 options; v2 added kana-kanji accuracy: 1 usability/UI, 2 AI rewrite accuracy, 3 kana-kanji conversion accuracy, 4 no use case, 5 missing feature, 6 other.
- Reply rate so far: ~6 substantive replies / ~200 sent (~3%).

## What the replies say (as of 07-18)

**⚠️ n = 6 replies. Everything below is directional hypothesis material, NOT conclusions.** The channel/reason ranking only becomes trustworthy when (a) the weekly survey pushes n to 30+, and (b) the instrumented funnel (see below) shows the same story quantitatively. Do not reprioritize the roadmap on this table alone.

| Signal | Evidence | Implication |
|---|---|---|
| **Keyboard "feel" ≠ native → silent churn** | 932324963@qq.com: AI button pinned at far-left of candidate bar "破坏苹果原生态键盘的视觉感受"; missed native spelling suggestions; "手感有变化就一直没有继续使用"; "还得动脑子用" (needs thinking to use) | Confirms hypothesis (a): parity with native keyboard is the #1 churn lever — conversion quality + visual/feel parity + zero-thought UX |
| **AI rewrite accuracy** | ooliovo627: answered "2" (accuracy 微妙) | Confirms hypothesis (b); ties to Zenzai/prediction-quality roadmap |
| **Reply-suggestion demand** | 3085591573@qq.com: wants auto-reply for daily chat ("不知道怎么回复比较贴切") — feature exists via prompts but user didn't find it | Discoverability problem, not feature gap. Onboarding/UI must surface reply mode |
| **Precise-selection friction (fixed)** | PKU power user: long-text mis-selection when rewriting one sentence — precise-selection feature since shipped | Follow up with user; good beta-loop precedent |
| **Willingness to pay exists** | yuicrescent@qq.com: "后续如有收费项目也可以理解" unprompted | Supports the Sep paywall experiment (roadmap Phase 1) |
| **UI is loved** | "还留着是因为软件UI做的太漂亮了" | Retention lever: the container is an asset; the keyboard feel is the liability |

## Quantitative funnel (measurable since 2026-07-18 person merge)

Install → acceptance funnel, Jun 26–Jul 18 cohort (acceptance tracking exists only since Jun 26), 14-day window, n = 3,056 installers:

| Step | Persons | % of installs |
|---|---|---|
| Application Installed | 3,056 | 100% |
| onboarding_completed | 2,761 | 90.4% |
| ran ≥1 ai_rewrite | 1,855 | 60.7% |
| accepted ≥1 rewrite (置き換え) | 772 | 25.3% |

**The biggest measurable drop with product meaning: 58% of users who run an AI rewrite never accept a single candidate** (772/1,855 = 41.6% accept). This is hard evidence for the quality/UX hypothesis, independent of the small-n emails. Second gap: 30% of installers finish onboarding but never run a rewrite — currently can't split "never enabled the keyboard" from "enabled but no trigger"; the `keyboard_enabled` + `full_access_granted` events (in code, ship with next release) will split it.

**Confirmed and promoted 2026-07-30.** Re-run at 90d scale (n = 3,710 installers, ≥14d mature):
2,322 tried a rewrite → 908 kept one (**39.1%**), matching the 41.6% above. This is now the
**#1 Phase 0 item** and the binding gate, because the acceptance → retention correlation below
turned out to be strong: retention measured on users who *kept* a rewrite and returned for a 2nd
rewrite day is ~30% W1 / ~16% W2, vs 5–18% install-anchored. In other words the users who get past
this gap are fine; the gap itself is the churn. Full definition and funnel in
`metrics-baseline.md` → *Retention definition v2*.

Also settled: **the onboarding practice rewrite never contaminated any of these numbers** —
practice mode answers locally with canned candidates and emits no `ai_rewrite`. But 85% of first
*real* rewrites happen within 5 minutes of `onboarding_completed`, so "ran ≥1 ai_rewrite" is a
setup-completion signal, not evidence of value.

Still unmeasured: enable-rate step (next release); *why* a candidate gets discarded — split
`ai_rewrite_action` into dismissed / regenerated / replace_failed, and check whether
`replace_failed` (the replacement engine bailing when proxy context moved) is a real bug inflating
the gap.

## 🔑 Persona discovery

A large share of engaged users are **Chinese speakers living/working in Japan or learning Japanese** (qq/163/126 addresses throughout; power users writing business mail to 日方). This is a distinct second ICP next to JP 新社会人/就活生:
- They have the keigo pain *and* the JP-input pain simultaneously; ChatGPT is their current workaround (PKU user said so explicitly).
- GTM implications: ZH App Store metadata/keywords (aso), RED (小紅書)/WeChat channels for 在日中国人, and the planned Chinese input mode becomes a growth feature, not just i18n.

**⚠️ Retention reality (2026-07-18, added):** this segment is the largest by *volume* but retains **worst** — zh-locale W1 15% vs ja 29%; 89% one-and-done vs 75% (`metrics-baseline.md` → Retention by segment). The RED spikes brought Chinese volume, not stickiness. Do NOT promote this to primary ICP on engagement anecdotes alone — it's an acquisition/early-revenue channel. The churn cause the replies above name (native keyboard-feel parity) hits exactly these users hardest, which is consistent with their worse retention.

## Standing email playbook (now part of GTM)

Constraints (from memory: user-outreach-email-style): business-polite register, easy general questions, drafts only — Gmail connector can create drafts, Itsuki sends. Never email 717natsuki@gmail.com.

1. **High-intent churn survey (small, re-targeted — decided 2026-07-18)**: the scaled cold blast is retired — reply rate ~3% and it over-samples low-intent RED churners (intent confound, see `metrics-baseline.md` → Retention by segment caveat d). Instead, each Friday draft a *small* (~20–30) personal survey to **high-intent churners only**: `ja`-locale / organic (non-RED) signups from 7–14 days ago with 0 rewrites in 7 days (list from Supabase, then tighten to geo=JP + locale ja/en + Japanese names via PostHog). These had the problem and still left = real product churn. Personal Gmail, do not automate — the founder tone is the response-rate lever. **Always dedupe against `outreach-log.md` first** (query `in:sent (to:…)` on the candidate list; drop any already contacted).
2. **Power-user interview (monthly)**: top-20 by active days → 感謝信 format. Personal Gmail.
3. **Winback (after fixes ship) — via Loops, not Gmail**: "you said X, we fixed X" to every user who reported a now-fixed issue; doubles as reactivation. This is the one *scaled* email job. When a parity/accuracy fix ships, stand up Loops (Supabase `auth.users` → segment → template; verified sending domain + SPF/DKIM/DMARC + unsubscribe + 特定電子メール法 compliance). Not before — no bulk infra ahead of a shippable fix. Highest-value use of email effort is the fix itself, not more surveys.
4. **Consent/opt-in ask** to engaged users when the new consent UX ships (Phase 1 data-asset goal).

## Reply tally (running)

| Reason | Count |
|---|---|
| 1 usability/UI feel | 1 (932…) |
| 2 AI accuracy | 1 (ooliovo…) |
| 3 kana-kanji accuracy | 0 |
| 4 no use case | 0 |
| 5 missing feature | 1 (reply-suggestion, 3085…) |
| praise only | 2 |
