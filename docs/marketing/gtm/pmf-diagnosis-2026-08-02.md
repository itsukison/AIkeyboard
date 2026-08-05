# PMF diagnosis — 敬語ボタン, 2026-08-02

Point-in-time analysis. All numbers pulled live from Supabase MCP and PostHog MCP
(project 465060) on **2026-08-02**. Owner: Itsuki. Author: Claude Code session.

**Read this alongside** `metrics-baseline.md` (which owns the running metric history and
was last updated 2026-07-18 — its topline is stale by this date) and `churn-signals.md`
(which owns churn evidence and personas).

---

## Bottom line

**8 users** used the AI rewrite on 10+ days in the last 30 days. **45** used it on 5+ days.
DAU/MAU is **4.7%**. That is not a habit — it is a novelty. The founder's instinct that the
sticky base is "20–30 people" is correct (≥7 days/month = 22 users) and, if anything,
generous.

But "therefore there is no PMF" does not survive the data. There is a signal, and it points
somewhere specific:

> **The users who stick are the ones who escaped the default prompt.**
> The onboarding funnels ~71% of all rewrite volume into `polite` (敬語) — the single
> **worst-accepted** command in the product (25.8%). Users who write their own prompt accept
> at **61.5%** (75.7% among the sticky core) and use the app **4.9× more**.

The framing hypothesis — that the product is mispositioned rather than unwanted — is
supported by three independent measurements (§5). It is a hypothesis, not a conclusion, and
§7 lists the experiment that falsifies it.

---

## 1. Scale — confirmed

| Metric | Value | Source |
|---|---|---|
| Installs (all time, tracked) | **4,397** | PostHog `Application Installed` |
| Registered users | **3,210** | Supabase `profiles` |
| Install → signup | **~73%** | derived |
| New users last 7d / 30d | 151 / 731 (~21/day) | Supabase |
| AI-rewrite MAU (30d) | **974** (30% of registered, 22% of installs) | Supabase `ai_rewrite_events` |
| AI-rewrite WAU | **246** (prev week 260, −5.4%) | Supabase |
| AI-rewrite DAU (7d avg) | **46** | Supabase |
| Consent opt-ins | 481 | Supabase `user_ai_consent` |
| Raw-text consents | **0** | Supabase |

Weekly installs are now running **232–407/week** (7/20 and 7/27 weeks), down from the
1,600–1,800/week launch spike. Install → signup at 73% is genuinely good and is *not* the
problem.

---

## 2. The stickiness problem, quantified

### Distinct AI-rewrite days per user, last 30 days (n = 974 active users)

| Days used | Users | % of active | % of registered |
|---|---|---|---|
| 1 day | **622** | 63.9% | 19.4% |
| 2 days | 183 | 18.8% | 5.7% |
| 3–4 days | 124 | 12.7% | 3.9% |
| 5–9 days | 37 | 3.8% | 1.2% |
| **10+ days** | **8** | **0.8%** | **0.25%** |
| 20+ days | 3 | 0.3% | 0.09% |

- **DAU/MAU = 4.7%.** A daily-habit product runs 20%+. A weekly utility runs ~10%.
- **WAU/MAU = 25%** — three quarters of monthly actives do not return within the week.
- **≥7 days/month = 22 users.** This is the number the founder estimated at "20–30".

### Cross-check on plain typing, not just AI

The keyboard is an IME first, so a user could type daily and never run a rewrite. Checked
independently in PostHog on `keyboard_usage_day` (30d): **349 users** emitted any typing day,
**275 of them on exactly 1 day**, 12 on 10+ days. Same shape.

⚠️ `keyboard_usage_day` only flushes when the container app is reopened, so it undercounts
badly — treat it as a **floor**. It does not rescue the story, but it is not proof of the
ceiling either.

### Month-over-month core (PostHog, full history)

| Month | AI-active | 3+ days | 5+ days | 10+ days | 15+ days |
|---|---|---|---|---|---|
| July (full month) | 1,190 | 201 | **55** | 10 | 4 |
| Aug (2 days, partial) | 44 | — | — | — | — |

June is **not comparable** — launch was 2026-06-22, so only ~9 days of possible usage exist
in that month (June reads 1,818 active / 3 at 5+ days purely because of the truncated
window). **July is the honest baseline.**

### What this means for the exit thesis

Against the ~3億円 strategic-acquisition north star in `GTM.md`, a buyer pays for one of
three things: revenue, an engaged user base, or a defensible data asset. As of today the app
has none of them. A subscription launched now would be meaningless — correct call.

---

## 3. Quality was a real constraint, and it is lifting

Acceptance rate = rewrites with `selected_index` recorded ÷ total rewrites.

### By week

| Week | Rewrites | Users | Accept % | Avg latency |
|---|---|---|---|---|
| 6/29 | 1,309 | 316 | 24.0% | 1,157 ms |
| 7/06 | 1,548 | 360 | 28.9% | 1,208 ms |
| 7/13 | 1,033 | 260 | 36.2% | 1,358 ms |
| 7/20 | 1,292 | 253 | 32.7% | 1,705 ms |
| 7/27 | 1,100 | 233 | **39.5%** | 2,299 ms |

### By app version (last 30d)

| Version | Users | Rewrites | Accept % | Avg latency |
|---|---|---|---|---|
| 1.0.10 | 110 | 468 | 24.8% | 1,212 ms |
| 1.0.11 | 65 | 272 | 19.5% | 1,267 ms |
| 1.0.12 | 403 | 1,948 | 34.9% | 1,285 ms |
| 1.0.13 | 155 | 718 | 31.9% | 1,573 ms |
| 1.0.14 (GPT-Soul) | 63 | 389 | 35.5% | 2,292 ms |
| 1.0.15 | 102 | 454 | 32.6% | 2,431 ms |
| **1.0.16** | 94 | 407 | **47.4%** | 2,211 ms |
| 1.0.17 | 16 | 49 | 49.0% | 1,956 ms |

Acceptance appears to have roughly **doubled** (24% → 47–49%).

> 🔴 **CORRECTED — see Appendix Q5.** This is substantially a *measurement coverage*
> artifact. Outcome-instrumentation coverage rose from 31% to 65% over the same weeks. On a
> like-for-like basis the real improvement is **≈ +10pt at 1.0.16**, not a doubling. Do not
> quote "acceptance doubled" externally.

### ⚠️ The latency trade

**Latency went 1.2s → 2.2s and has not come back down.** Churn cause #1 in the email data is
keyboard *feel/latency*; #2 is AI accuracy.

> 🟡 **QUALIFIED — see Appendix Q4.** Tested directly: latency shows no clean relationship
> with abandonment at this range, and first-session latency is identical between sticky
> (1,165 ms) and one-and-done (1,217 ms) users. The trade is a real risk to *perceived feel*
> but is **not currently visible in behaviour**. Downgraded from "unaccounted risk" to
> "watch item".

---

## 4. Prompt customization — the strongest signal in the dataset

### Behaviour split (of the 974 AI-active users, last 30d)

| Segment | Users | Avg rewrite days | Avg rewrites | % at 5+ days |
|---|---|---|---|---|
| **Used a custom prompt** | 35 | **3.51** | **26.5** | **17.1%** |
| Built-in prompts only | 939 | 1.74 | 5.4 | 4.2% |

→ **4.9× the volume, 2× the frequency, 4.1× the odds of becoming a weekly-habit user.**

> 🔴 **CORRECTED — see Appendix Q2.** "Custom prompt" here is `builtin_key IS NULL`, which
> also catches the **onboarding use-case presets** (カジュアル / 添削 / 要約 / わかりやすく /
> 中国語訳) written by `OnboardingUseCase.swift`. Split properly, the preset group is *worse*
> than built-in-only (0% reach 5+ days) and the entire effect sits in **self-authored**
> prompts (21 users, 5.10 days, 28.6% at 5+ days). The corrected split is stronger, but it
> is a different claim.

### Acceptance by command (last 30d)

| Command | Rewrites | Users | Accept % |
|---|---|---|---|
| `polite` (敬語 — the default) | **4,444** (71% of all volume) | 922 | **25.8%** ← worst |
| **custom prompt** (`command_key` null) | 701 | 35 | **61.5%** ← best |
| `natural` | 472 | 134 | 43.4% |
| `translateToEnglish` | 120 | 32 | 39.2% |
| `email` | 233 | 67 | 33.5% |
| `reply` | 68 | 30 | 26.5% |

### Same split inside the sticky core (5+ rewrite days, n = 45)

| Command | Rewrites | Core users | Accept % |
|---|---|---|---|
| custom prompt | 538 | 6 | **75.7%** |
| `natural` | 237 | 20 | 55.3% |
| `translateToEnglish` | 79 | 7 | 54.4% |
| `email` | 91 | 9 | 52.7% |
| `reply` | 21 | 4 | 42.9% |
| `polite` | 640 | 43 | 33.9% |

The gap **widens** among the best users. The default command is the worst performer in every
cut.

### Customization is rare and buried

- **87 of 3,210 users (2.7%)** have ever created a custom prompt. It lives in the Prompts
  screen; almost nobody finds it.
- Among users who signed up in the last 30 days, *any* prompt editing rises monotonically
  with usage: **8.8%** (1 rewrite day) → 18.4% (2) → 23.4% (3–4) → **33.3%** (5+).

### Causality caveat — read before acting

Of the 87 custom-prompt creators, only **6** had any rewrite recorded *before* creating the
custom prompt, which suggests customization **precedes** heavy use rather than following it.

But `ai_rewrite_events` is now on a **rolling 30-day retention window** (oldest row:
2026-07-02), so earlier history is deleted and precedence **cannot be cleanly proven**. The
active-segment n is 35. **This is a hypothesis worth a two-week experiment, not a
conclusion.** Selection effect (motivated users customize *and* would have stuck anyway) is
not ruled out by this data.

---

## 5. Is the product "truly useful"? — testing the framing hypothesis

Three independent measurements support "mispositioned" over "unwanted":

### a) The usage is micro, not workflow

Average input length is **18–31 characters** — one short sentence. Users are not writing
emails in it; they are patching a single phrase. That is a punctual, low-stakes moment.
Grammarly's habit comes from living inside a *continuous* writing surface; this product lives
in a *punctual* one.

### b) It is not anchored to a work ritual

Weekday distribution for the sticky core is essentially flat (Fri 284 / Tue 243 / Thu 240 /
Sun 232 / Wed 231 / Sat 202 / Mon 174; weekend = 27% of volume vs 28.6% expected). A
敬語-for-business-email tool would show a hard Mon–Fri shape. It does not. **The best users
are using it for something other than business email** — plausibly everyday chat.

### c) Reply mode is dead on arrival despite explicit demand

Reply usage is **0.6–1.1%** of all rewrites (68 events, 30 users), while `churn-signals.md`
records users asking for exactly this feature and not finding it. Pure discoverability loss,
now confirmed quantitatively.

### One bright spot

**16–26% of rewrites are refinements** (もっと丁寧に etc.). Users who reach that step are
working the tool, not testing it.

> 🔴 **CORRECTED — see Appendix Q6.** Refinement is **friction, not engagement**. On their
> first day, one-and-done users refine at **30.1%** and sticky users at **21.5%** — the
> relationship runs the wrong way for the "engagement" reading. Refining means the first
> output was not good enough.

### The PM read

> **This is not "no PMF." This is PMF for a product the onboarding refuses to sell.**
>
> The app is positioned, named, and defaulted as a 敬語 converter. 敬語 conversion is its
> highest-volume and lowest-accepted command. The users who become habitual are the ones who
> broke out of that default and turned it into a general-purpose *"rewrite my Japanese the
> way I want it"* tool — and they accept output at 61–76%.
>
> The funnel is a funnel **into the worst version of the product**. That is fixable, and far
> more actionable than "users don't need keigo."

**Falsifiable prediction:** force an explicit first-command choice at onboarding, and
acceptance + D7 should split visibly by first command chosen, with `polite` at the bottom.
**If it does not split, this hypothesis is wrong** and the problem is genuine
frequency-of-need — in which case the answer is a different wedge, not better framing.

---

## 6. Off-radar risk: the data asset is being deleted

`ai_rewrite_events` currently holds **only the last 30 days** (6,282 rows; oldest
2026-07-02). The retention job listed as an open item in `AGENTS.md` §8 appears to be live.

Meanwhile consent opt-ins are up to **481** (from 199 on 2026-07-18), but **raw-text consent
is still exactly 0**.

`GTM.md` sells the exit as "① empty positioning × ② consented in-situ preference-data
pipeline × ③ revenue trajectory." **② is currently being deleted on a rolling basis and has
never recorded a single raw-text consent.** If the data asset is genuinely part of the story,
this is a decision to make now, not at diligence.

---

## 7. Recommended actions

Ordered by information-per-yen. The `GTM.md` **one rule still holds — do not spend on
acquisition.** Both gates (activation ≥25%, activated W2 ≥25%) remain red.

| # | Action | Why | Owner / timing |
|---|---|---|---|
| 1 | **Interview the 45 users at 5+ rewrite days.** Ask one question: *what were you doing right before you opened it?* | Highest-information action available; no data substitute exists | Itsuki, this week |
| 2 | **Break the default-prompt monoculture.** Force an explicit first-command choice at onboarding tied to a stated use case; measure acceptance + D7 **by first command** | Directly tests §5; falsifiable in ~2 weeks | Product |
| 3 | **Move custom-prompt creation into onboarding** as a required step, not a settings screen 2.7% of users find | Tests whether customization *causes* stickiness (§4 caveat) | Product |
| 4 | **Instrument the latency/feel trade.** Split acceptance vs latency bucket before shipping anything slower than 2.2s | 1.2s → 2.2s is unaccounted risk against the #1 named churn cause | Eng |
| 5 | **Surface reply mode** | 0.6% usage against documented demand is free upside | Product |
| 6 | **Decide on the data asset** — 30-day deletion window vs. the acquisition thesis | Strategy call, not an engineering one | Itsuki |

---

## 8. How to re-pull

Supabase (`mcp__supabase__execute_sql`):

```sql
-- frequency distribution (the headline table in §2)
with days as (
  select user_id, count(distinct created_at::date) as d30
  from ai_rewrite_events
  where created_at > now() - interval '30 days'
  group by 1
)
select d30 as rewrite_days_in_30d, count(*) as users
from days group by 1 order by 1;

-- acceptance + latency by command (§4)
select coalesce(payload->>'command_key','(custom prompt)') as command_key,
       count(*) as n,
       count(distinct user_id) as users,
       round(100.0*count(*) filter (where selected_index is not null)/count(*),1) as accept_pct
from ai_rewrite_events
where created_at > now() - interval '30 days'
group by 1 order by 2 desc;

-- custom-prompt vs builtin behaviour split (§4)
with days as (
  select user_id, count(distinct created_at::date) as d30, count(*) as n
  from ai_rewrite_events where created_at > now() - interval '30 days' group by 1
),
custom_users as (
  select distinct user_id from ai_rewrite_events
  where created_at > now() - interval '30 days' and payload->>'command_key' is null
)
select case when c.user_id is null then 'builtin only' else 'used custom prompt' end as segment,
       count(*) as users,
       round(avg(d.d30),2) as avg_days,
       round(avg(d.n),1) as avg_rewrites,
       round(100.0*count(*) filter (where d.d30 >= 5)/count(*),1) as pct_5plus_days
from days d left join custom_users c on c.user_id = d.user_id
group by 1;
```

PostHog (`mcp__posthog__exec` → `call execute-sql`):

```sql
-- monthly frequency core (§2)
SELECT month,
       countIf(days >= 1)  AS active_users,
       countIf(days >= 3)  AS d3plus,
       countIf(days >= 5)  AS d5plus,
       countIf(days >= 10) AS d10plus
FROM (
  SELECT person_id, toStartOfMonth(timestamp) AS month,
         count(DISTINCT toDate(timestamp)) AS days
  FROM events
  WHERE event = 'ai_rewrite' AND timestamp > now() - INTERVAL 100 DAY
  GROUP BY person_id, month
)
GROUP BY month ORDER BY month

-- weekly acquisition funnel (§1)
SELECT toStartOfWeek(timestamp, 1) AS wk,
       uniqIf(person_id, event = 'Application Installed')  AS installs,
       uniqIf(person_id, event = 'signed_up')              AS signups,
       uniqIf(person_id, event = 'onboarding_completed')   AS onboarded,
       uniqIf(person_id, event = 'keyboard_enabled')       AS kbd_enabled,
       uniqIf(person_id, event = 'ai_rewrite')             AS tried_rewrite,
       uniqIf(person_id, event = 'ai_rewrite_accepted')    AS kept_rewrite
FROM events
WHERE timestamp > now() - INTERVAL 70 DAY
GROUP BY wk ORDER BY wk
```

---

## 9. Known limitations of this analysis

- **30-day event retention** on `ai_rewrite_events` means no Supabase-side history before
  2026-07-02. All longer-range claims come from PostHog.
- **`keyboard_usage_day` undercounts** (flushes on container open only) — §2's typing-day
  figures are a floor, not a point estimate.
- **Small n in the sticky segments**: 45 users at 5+ days, 35 custom-prompt users in the
  active window, 8 at 10+ days. Percentages in those cells move a lot with single users.
- **Acceptance coverage is version-gated** — `selected_index` requires the client to POST
  feedback, so acceptance % is a floor and part of the week-over-week rise in §3 may be
  coverage rather than quality. Not separable with current instrumentation.
- **No host-app context** is captured, so "where users use it" (LINE vs mail vs Slack) is
  unmeasurable today. That is the single most valuable missing field for the §5 hypothesis.
- These pulls do not apply PostHog's `filterTestAccounts`; the internal-user count is too
  small to move percentages.

---

# Appendix — follow-up questions (2026-08-02)

Six questions asked after the first draft. All answered from live Supabase + PostHog pulls
plus code verification. **Three of them correct claims in the main body**; those sections now
carry pointer notes.

**Headline of this appendix:** two of the main doc's supporting arguments were partly
measurement artifacts, and one core claim got *stronger* under a cleaner definition. The
central thesis — that the funnel forces everyone into one command and that self-authored
prompts mark the sticky users — survives. The causal version of it does not.

---

## Q1 — Among custom-prompt users, what happens before vs after prompt creation?

Within-user, 14 days before vs 14 days after each user's **first `prompt_created` event**.
`prompt_created` fires only at `PromptsScreen.swift:268` (verified in code), so this signal is
onboarding-clean. Users whose t0 is less than 14 days old are excluded. PostHog full history.

**Unstratified (n = 39):** 5.15 → 12.13 rewrites, 0.90 → 2.31 active days. Looks like a 2.4×
lift.

**That number is an illusion.** 30 of 41 `prompt_created` events fire **within 1 hour of
signup** — users open the Prompts screen right after onboarding, so their "before" window is
empty by construction. Stratified:

| Stratum | Users | Rewrites before → after | Active days before → after | Went up | Went down |
|---|---|---|---|---|---|
| A. No rewrite before t0 | 14 | 0.0 → 4.21 | 0.00 → 0.86 | 8 | 0 |
| B. Active, t0 within 1h of signup | 16 | 8.50 → 20.00 | 1.19 → 3.31 | 8 | 7 |
| **C. Active, t0 >1h after signup** | **9** | **7.22 → 10.44** | **1.78 → 2.78** | **3** | **6** |

**Stratum C is the only clean within-user test** — users who were already rewriting and then
chose to author a prompt. **Six of nine went *down* in rewrite volume.** Mean rose only
because one user's tail dominates.

**Acceptance before vs after cannot be compared at all** — "before" windows sit earlier in
calendar time, when outcome instrumentation coverage was roughly half what it is now (Q5).
The apparent 12/201 → 164/473 jump is mostly coverage drift.

### Answer

**No causal evidence.** Customization looks like a **marker** of an already-different user,
not a cause of stickiness. n=9 in the clean stratum is too small to conclude the opposite
either. The main doc's §4 caveat was right to hedge, and should be read as the stronger
statement: **this is a segmentation signal, not a lever — until an experiment says otherwise.**

The experiment that would settle it is Action #3 in §7 (force prompt authoring in onboarding
for a random half, compare D7).

---

## Q2 — What custom prompts are people actually creating?

### First, a definition bug that affects §4

The onboarding use-case picker (`iOS/Container/OnboardingUseCase.swift:112–136`) writes its
presets with `builtinKey: nil`. They therefore land in `user_prompts` as
`builtin_key IS NULL` — **identical to a user-authored prompt.** The five presets are:
**カジュアル / 添削 / 要約 / わかりやすく / 中国語訳**.

Of the 136 `builtin_key IS NULL` rows, **79 (58%) are exact preset titles**; 57 are free-form.

### Corrected segmentation (30-day active users)

| Segment | Users | Avg rewrite days | Avg rewrites | % at 5+ days | Accept % |
|---|---|---|---|---|---|
| 1. Built-in prompts only | 935 | 1.74 | 5.5 | 4.2% | 27.3% |
| 2. **Onboarding preset only** | 18 | 1.22 | 4.8 | **0.0%** | **7.0%** |
| 3. **Free-form self-authored** | 21 | **5.10** | **40.5** | **28.6%** | **62.2%** |

**The preset does nothing.** Users who only ever got an app-suggested prompt are *worse* than
users who stayed on the built-ins — zero of them reached 5+ days, and they accept at 7%. The
entire effect in §4 belongs to prompts people **wrote themselves**.

This is a sharper and more useful finding than the original: it says handing users a
better-worded prompt is not the mechanism. Something about the act of articulating your own
job is.

### What the free-form prompts are (manual categorisation, 57 rows)

Titles only — prompt bodies were not read or reproduced.

| Job | Rows | Example titles |
|---|---|---|
| **Translation** | **~22** | 中国語訳変種, 翻译, 中英互译, 日译, 英訳, 和訳, 直译, 中译日, フランス語訳, 片假名转换 |
| Casual / register-shift | ~9 | 友達, チャット, 口語, 可愛く, 親しみ, 轻松, 普通体, 感情込めて |
| Keigo (the app's own job) | ~5 | 敬語, 敬語化, 超级尊敬, 网络礼貌用语, 丁寧返答 |
| Compress / clarify | ~5 | 簡潔化, 短く返す, 長文 |
| Proofread | ~4 | 校正, 誤字, 日本語 |
| Reply-specific | 2 | LINE, LINE返信 |
| Other / joke | ~5 | 魔王, チケット, 指示, 同学 |

### Answer

**The single largest self-authored job is translation — roughly 4× more common than keigo.**
Chinese ⇄ Japanese dominates it (中国語訳, 中译日, 中文翻译成日文, 日译, 直译, 中英互译),
consistent with the Chinese-speakers-in-Japan persona in `churn-signals.md`.

The people who stick are not doing 敬語変換. They are doing **cross-language and
register-shift work**, and they had to build the button themselves because the product does
not ship one for their job. Only 5 of 57 self-authored prompts are about keigo — inside the
segment that actually retains, **the app's headline feature is a rounding error**.

---

## Q3 — Does the first command used predict D7 retention?

First `ai_rewrite` per person, PostHog full history, 90d, matured ≥8 days. "Returned" = a
rewrite on a later calendar day.

| First command | Users | D7 return | D30 return | Avg rewrites |
|---|---|---|---|---|
| `polite` | **2,303** | 25.5% | 35.2% | 6.8 |
| `natural` | 95 | 22.1% | 30.5% | 7.7 |
| `email` | 17 | 35.3% | 41.2% | 7.3 |
| `translateToEnglish` | 16 | **43.8%** | 56.2% | 11.9 |
| `reply` | 8 | 37.5% | 50.0% | 8.0 |
| (custom / none) | 3 | 0.0% | 0.0% | 6.3 |

### Answer — this partially undercuts §5, and it matters

**At usable sample size, the first command does not predict D7.** `polite` (25.5%) actually
edges out `natural` (22.1%), despite `natural` accepting at 43.4% vs `polite`'s 25.8%.

**Acceptance and retention are decoupled.** Getting a better answer on the first try does not,
by itself, bring the user back. The §5 prediction — "force a first-command choice and D7 will
split" — is **already weakly falsified for the two commands with adequate n**. The high-D7
commands (`translateToEnglish` 43.8%, `email` 35.3%, `reply` 37.5%) have n = 8–17 and almost
certainly reflect *selection*: users who arrive with a specific pre-existing job.

### But exposure explains the volume completely

From `user_prompts` slot assignment across all 3,210 users:

| Command | Slot | Position | Users provisioned |
|---|---|---|---|
| `polite` | **main** | 0 | 3,112 |
| `natural` | sub | 0 | 3,198 |
| `email` | sub | 1 | 3,117 |
| `translateToEnglish` | sub | 2 | 3,165 |
| **`reply`** | — | — | **0 (not provisioned)** |
| self-authored | main | 0 | 42 |
| self-authored | sub | ~2 | 75 |

`polite` is the **only** one-tap pill; everything else sits behind the `…` overflow. Its 71%
volume share is an artifact of placement, not preference.

### Revised reading of §5

The framing hypothesis needs splitting into two claims:

- ❌ **"Change which command users start with and retention improves"** — not supported. Test
  it cheaply if you like, but the prior is now negative.
- ✅ **"The product only exposes one job, and the job that retains people isn't it"** —
  supported, and reinforced by Q2. The sticky users' actual job (translation, register-shift)
  has no button at all.

So Action #2 in §7 should be re-scoped: **not** "make users pick a first command", but
**"ship a translation / register-shift command as a first-class pill and see whether it
recruits the segment that already retains."**

---

## Q4 — Does high latency predict immediate abandonment?

Pooled across versions, 30d, n = 6,037 rewrites with latency recorded:

| Latency bucket | Rewrites | Avg ms | Accept % | Another rewrite ≤30 min | User returns on a later day |
|---|---|---|---|---|---|
| a. < 1.5s | 3,858 | 1,007 | 28.4% | 65.7% | 53.5% |
| b. 1.5–2.5s | 1,456 | 1,859 | 36.5% | 63.7% | 47.6% |
| c. > 2.5s | 723 | 3,687 | 41.1% | 62.5% | 49.4% |

Continuation barely moves (65.7% → 62.5%) and **acceptance goes the wrong way** — slower
rewrites are accepted *more*.

**The confound is input length.** Latency tracks how much text was sent. Holding app version
constant:

| Version | Bucket | n | Avg input chars | Accept % | Continue ≤30 min |
|---|---|---|---|---|---|
| 1.0.12 | < 1.5s | 1,509 | 27 | 34.3% | 63.9% |
| 1.0.12 | 1.5–2.5s | 361 | 31 | 38.0% | 59.8% |
| 1.0.12 | > 2.5s | 78 | 52 | 30.8% | 62.8% |
| 1.0.15 | < 1.5s | 72 | 14 | 16.7% | 68.1% |
| 1.0.15 | 1.5–2.5s | 214 | 26 | 28.5% | 69.2% |
| 1.0.15 | > 2.5s | 168 | 66 | 44.6% | 63.7% |
| 1.0.16 | < 1.5s | 74 | 10 | 27.0% | 77.0% |
| 1.0.16 | 1.5–2.5s | 214 | 22 | 55.1% | 65.9% |
| 1.0.16 | > 2.5s | 119 | 42 | 46.2% | 60.5% |

1.0.16 shows continuation falling 77.0% → 60.5% as latency rises — but average input length
also goes 10 → 42 characters across those same buckets, so longer/harder requests and slower
requests cannot be separated with the fields currently logged.

**Decisive control:** first-session average latency is **1,165 ms for users who became sticky
vs 1,217 ms for one-and-done users** (Q6). Essentially identical.

### Answer

**No clean evidence that latency drives abandonment in the 1–3.5s range.** The §3 warning is
downgraded to a watch item. This does *not* clear latency as a *perceived-feel* risk — the
churn emails are explicit about keyboard feel, and typing-path latency is a different thing
from rewrite latency, which is what this data covers. To separate the two you would need to
log latency bucketed **by input length**, or run a deliberate delay experiment.

---

## Q5 — Are acceptance rates comparable across versions?

**No. This is the most important correction in the appendix.**

Acceptance is recorded as `selected_index` on `ai_rewrite_events`. Negative outcomes go to a
separate table (`ai_rewrite_action_events`: dismissed / regenerated / replace_failed). If a
client version doesn't report, the rewrite silently counts as "not accepted."

**Outcome coverage** = (accepted + any action event) ÷ rewrites.

### By version (30d)

| Version | Rewrites | Accepted | Dismissed | Naive accept % | **Coverage** | **Accept % of resolved** |
|---|---|---|---|---|---|---|
| 1.0.5 | 247 | 0 | 0 | 0.0% | **0.0%** | n/a |
| 1.0.8 | 887 | 255 | 0 | 28.7% | 28.7% | 100% (meaningless) |
| 1.0.10 | 468 | 116 | 128 | 24.8% | 56.6% | 47.5% |
| 1.0.11 | 272 | 53 | 75 | 19.5% | 50.0% | 41.4% |
| 1.0.12 | 1,948 | 679 | 473 | 34.9% | 62.0% | 58.9% |
| 1.0.13 | 718 | 229 | 177 | 31.9% | 61.3% | 56.4% |
| 1.0.14 | 389 | 138 | 83 | 35.5% | 61.2% | 62.4% |
| 1.0.15 | 454 | 148 | 115 | 32.6% | 62.1% | 56.3% |
| **1.0.16** | 407 | 193 | 87 | 47.4% | **73.0%** | **68.9%** |

### By week

| Week | **Coverage** | Naive accept % | **Accept % of resolved** |
|---|---|---|---|
| 6/29 | 31.2% | 24.0% | 79.3% ⚠️ |
| 7/06 | 52.9% | 28.9% | 57.1% |
| 7/13 | 59.0% | 36.2% | 64.7% |
| 7/20 | 58.7% | 32.7% | 59.6% |
| 7/27 | **65.2%** | 39.5% | 64.2% |

### Answer

**Coverage more than doubled (31% → 65%) over exactly the window where acceptance appeared to
double.** The naive weekly series is largely a tracking artifact. On the resolved basis the
weekly series is **flat and noisy** (57–65% after the first unreliable week — 6/29's 79.3% is
itself an artifact of near-zero dismiss reporting).

**There is still a real gain, but it is smaller:** at version level, 1.0.16 accepts 68.9% of
resolved outcomes vs 1.0.12's 58.9% — **≈ +10pt**, n = 407. That is a genuine model
improvement, consistent with the GPT-Soul upgrade, and worth having. It is not a doubling.

**Consequences:**
- §3's "acceptance doubled" is corrected in place. Never quote it externally.
- `metrics-baseline.md`'s step-4 funnel figure ("kept a rewrite" = 24.5% of installs) is a
  **floor that is still rising for instrumentation reasons**, exactly as its caveat (a)
  warned. The 11.5% activation number inherits that bias.
- **Report acceptance on the resolved basis from now on**, and publish coverage alongside it.
  Any acceptance metric without a coverage denominator is unreadable.

---

## Q6 — What do the 8 users at 10+ days do differently in their first session?

### The 8 users individually (30d window)

| Rewrite days | 1st-day rewrites | First command | Distinct commands | Accept % | Avg latency | Custom prompt created | Signup |
|---|---|---|---|---|---|---|---|
| 25 | 15 | custom | 4 | 73.5% | 1,864 ms | 2026-06-30 (signup day) | 06-30 |
| 23 | 1 | custom | 4 | 85.2% | 2,031 ms | 2026-06-29 (signup day) | 06-29 |
| 21 | 1 | custom | 4 | 70.0% | 1,418 ms | — | 06-06 |
| 14 | 12 | `natural` | 2 | 37.5% | 1,173 ms | — | 06-26 |
| 13 | 3 | `natural` | 4 | 48.7% | 1,243 ms | — | 07-07 |
| 11 | 4 | `polite` | 1 | 46.2% | 1,472 ms | — | 07-02 |
| 10 | 1 | `polite` | 2 | 70.8% | 1,759 ms | 2026-07-01 | 06-30 |
| 10 | 2 | `polite` | 3 | 64.0% | 1,846 ms | — | 06-29 |

### Population comparison, first day only (PostHog 90d / Supabase 30d)

| Metric | Sticky (5+ days) | Middle (2–4) | One-and-done |
|---|---|---|---|
| Users | 116 | 774 | 1,644 |
| Day-0 rewrites | **6.2** | 5.2 | 3.7 |
| Distinct commands on day 0 | **1.44** | 1.28 | 1.22 |
| **% using 2+ commands on day 0** | **31.0%** | 19.6% | **15.8%** |
| Day-0 acceptance | **30.6%** | 24.2% | 19.4% |
| Day-0 refinement rate | 21.5% | 26.7% | **30.1%** |
| Day-0 avg latency | 1,165 ms | 1,097 ms | 1,217 ms |
| Day-0 avg input length | 12 chars | 12 chars | 11 chars |

### Answer — the activation signature

**Command breadth, not first-session intensity.**

- **7 of 8** of the 10+ day users employ **2–4 distinct commands** (median 3.5). Population:
  sticky users are **2× more likely** to use 2+ commands on day 0 (31.0% vs 15.8%).
- **First-day volume is not the signal.** Three of the eight ran a *single* rewrite on their
  first day. Day-0 rewrites differ only 6.2 vs 3.7 — much weaker than the command-breadth gap.
- **First-day acceptance does predict** (30.6% vs 19.4%, ~1.6×). Getting a usable answer
  early matters — it just isn't sufficient on its own (Q3).
- **Refinement runs backwards.** One-and-done users refine *more* (30.1% vs 21.5%).
  Refinement is a failure signal — the first output missed. This corrects §5.
- **Latency is flat** (1,165 vs 1,217 ms) — confirms Q4.
- **Custom prompts show up in the extreme tail:** the top two users by active days both
  authored a prompt **on their signup day**, and both accept at 73–85%.
- **No single winning first command** (custom ×3, `natural` ×2, `polite` ×3) — consistent
  with Q3.

**The most actionable line in this whole appendix:** the sticky users are the ones who
discovered *more than one job* for the keyboard on day one — and the UI puts every job except
`polite` behind an overflow menu (Q3). That is a directly testable, cheap product change.

---

## Q7 — How exposed is reply mode?

### The funnel cannot be measured today. Here is exactly why.

Code (verified):

- `Sources/KeyboardPreferences/UserPrompts.swift:125` — reply is explicitly **not part of
  `seedEntries()`**. Confirmed in data: **zero `reply` rows across all 3,210 users'
  `user_prompts`.** There is no reply button to find in the prompt list.
- `iOS/KeyboardExtension/AI/AIKeyboardToolbarView.swift:113` — `replyPill()` renders only when
  `aiController.replyAvailable` is true **and** the toolbar is not in overflow.
- `iOS/KeyboardExtension/AI/AIKeyboardController.swift:146` — `replyAvailable =
  pasteboard.hasStrings`, re-evaluated only when `UIPasteboard.changeCount` differs from the
  value last offered for.

**So reply is not "buried in a menu" — it is a context-appearing pill gated on the user having
freshly copied a message before opening the keyboard.**

### What is measurable

| Funnel step | Instrumented? | Value (30d) |
|---|---|---|
| Reply pill **rendered** | ❌ no event | unknown |
| Reply pill **tapped** | ❌ no event | unknown |
| Clipboard check outcome (no-clipboard / unchanged / available) | ❌ no event | unknown |
| Reply **rewrite completed** | ✅ `ai_rewrite`, `command_key = 'reply'` | 68 events / 30 users |
| Reply **result accepted** | ✅ `selected_index` | 26.5% |
| First command = `reply` → D7 | ✅ | 37.5% (n = 8) |

### Answer

**Low usage does not prove discoverability is the problem — correct.** With three of six steps
uninstrumented, at least three explanations are indistinguishable:

1. The pill rarely renders (users don't copy before typing) → **exposure/trigger-design
   problem**.
2. The pill renders often but is ignored → **affordance problem**.
3. It renders and is tapped but output is poor → **quality problem**. (Weak evidence against:
   26.5% acceptance is low, but n = 68.)

Hypothesis 1 is a priori the most likely — the clipboard gate is narrow, and it makes reply
invisible to any user who doesn't happen to copy first. But that is a guess, and the data
cannot currently distinguish it.

**Required instrumentation before any reply decision** (all three are cheap, extension-side,
and fire only on user-visible UI state — no keystrokes, consistent with `AGENTS.md` §2):

- `reply_pill_shown` — when `replyPill()` enters the view hierarchy
- `reply_pill_tapped`
- a reason code on `refreshReplyAvailability()`: `no_clipboard` / `unchanged` / `available`

The last one is the decisive measurement: it tells you how often the gate *could* have fired
and didn't. **Do not act on reply mode until it exists.** §7 Action #5 ("surface reply mode")
is therefore re-scoped to **"instrument reply mode, then decide"**.

---

## Appendix — net effect on the main argument

| Main-doc claim | Status after this appendix |
|---|---|
| ~8 daily / 45 weekly-habit users; DAU/MAU 4.7% | ✅ Unchanged |
| Acceptance doubled 24% → 47% | 🔴 **Mostly a coverage artifact.** Real gain ≈ +10pt at 1.0.16 |
| Latency 1.2s → 2.2s is an unaccounted churn risk | 🟡 **Downgraded.** No behavioural signal at this range |
| Custom prompts → 4.9× usage | 🟢 **Stronger, and re-scoped.** Effect is entirely in *self-authored* prompts; onboarding presets do nothing |
| Customization *causes* stickiness | 🔴 **Not supported.** 6 of 9 in the clean stratum went down |
| Refinement is an engagement bright spot | 🔴 **Reversed.** It is a failure signal |
| "Force a first-command choice → D7 splits" | 🔴 **Weakly falsified.** `polite` ≈ `natural` on D7 |
| "The funnel exposes only one job, and it isn't the job that retains" | 🟢 **Confirmed and sharpened.** `polite` is the only one-tap pill; translation is the #1 self-authored job and has no button |
| Reply mode is a discoverability failure | 🟡 **Unproven.** 3 of 6 funnel steps uninstrumented |

**The thesis that survives, restated:** the sticky users are people who found a *second job*
for the keyboard — most often translation or register-shifting — and had to build the button
themselves. The product exposes exactly one job by default, and it is the one with the lowest
acceptance. Fixing that is a **product-surface** change (what gets a one-tap pill), not an
onboarding-copy change, and not a model-quality change.

**The single highest-value next step is unchanged and now better aimed:** interview the 45
users at 5+ rewrite days — specifically the 21 who wrote their own prompt — and ask what job
they built it for.
