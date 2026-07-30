# Roadmap — 3億円イグジットへの道 (2026-07 → 2027-04)

Written 2026-07-18. Grounded in `metrics-baseline.md` + `research/`. Review monthly, adjust freely — phases overlap on purpose.

## The strategy in one paragraph

The exit is a **strategic acquisition (Simeji-type, 数億円レンジ)** sold as a set: (1) the only keyboard-native 敬語変換 product in an empty positioning, (2) a growing **consented in-situ preference-data pipeline** no buyer can replicate in a lab, (3) real revenue proving willingness-to-pay. None of these alone reaches 3億 (see `research/exit-comps.md`); together they justify it. Downloads are an input, not the story — 1M downloads is **not** required. The binding constraint today is **activation** — only 11.5% of installs ever reach the value moment, while the users who do reach it retain at ~30% W1 (revised 2026-07-30; see `metrics-baseline.md` → Retention definition v2) — so everything starts there.

## Honest timeline assessment

3億 by Dec 2026 is the aggressive upper bound: the app launched ~June 22, and buyers pay for *trajectory shown over quarters*. The realistic best-case is **starting conversations Oct–Nov 2026, closing Q1–Q2 2027**, with the April 2027 新社会人 season as the demand spike that maximizes negotiating leverage. Treat Dec 2026 as "exit-ready + first offers", not "cash in bank". 【推測】

---

## Phase 0 — Stop the bleed (NOW → Aug 15) 🔴 blocking everything

**Goal: get more users to the value moment. Do not spend on acquisition until the two-part gate
below is green.**

**Gate rewritten 2026-07-30 after the retention-definition fix (`metrics-baseline.md` →
Retention definition v2).** Retention of *activated* users is ~30% W1 / ~16% W2 — not a crisis, though
there is no comparable external benchmark for this denominator, so don't call it top-quartile
(`metrics-baseline.md` carries the caveat). The constraint moved one step earlier: only **11.5% of installs ever
activate**, and 61% of users who try a rewrite never keep one. Note the old wording ("W1 ≥25% of
activated users") would now read **green at 30%** and unlock acquisition spend — that would be an
artifact of changing the denominator, not progress. The gate is therefore restated on the metric
that still shows the leak:

- **Gate A — activation: installs → activated ≥25%** (now 11.5%). This is the binding constraint.
- **Gate B — activated W2 ≥25%** (now 13–18%). W1 is too easy under the new definition; a cohort
  defined by "came back once" is nearly guaranteed to be present in W1, so W2/W4 is where real
  habit shows.

Both must hold on two consecutive weekly cohorts before any acquisition spend.

- [ ] **Fix measurement first**: resolve the PostHog identity case-mismatch (uppercase vs lowercase UUID → split persons, deflates retention); decide the canonical keyboard-DAU metric given `keyboard_usage_day` undercounts (extension can't send analytics — consider flushing usage days from App Group whenever container opens, and accept ai_rewrite DAU as the reliable floor).
- [ ] **Interview the core**: ~67 users have 5+ active days. In-app prompt or email (they have accounts) — why do they stay? What do they rewrite? (Power-user 感謝信 wave already running since Jul 11 — see `churn-signals.md`.)
- [ ] **Churn diagnosis**: 1,597 one-day users. Email survey (~200 sent Jul 13–16) already confirms (a) keyboard feel/parity is the top named reason and (b) AI accuracy second — see `churn-signals.md` for the running tally and the standing email playbook (weekly churn survey, monthly power-user interviews, winback after fixes). Remaining hypotheses to instrument: keyboard_enabled (barely fires today), Full Access drop-off.
- [ ] **Second ICP (revisit — do not over-index yet)**: Chinese speakers are the largest *volume* segment (RED-driven) but retain ~half as well as Japanese/organic — zh-locale W1 15% vs ja 29%; 89% one-and-done vs 75% (`metrics-baseline.md` → Retention by segment). Real as an acquisition + early-revenue channel (RED works), but the higher-quality audience is Japanese/organic, and the exit story needs business-Japanese. So: acquire via RED/ZH (ASO ZH keywords, RED/WeChat, Chinese-mode), keep product + data positioning on business Japanese. NOT confirmed as the primary target.
- [ ] **Ship the feedback endpoint** (AGENTS.md §8): only 17% of rewrite events record `selected_index`. This is both a product signal and the data asset itself. Target ≥90% coverage.
- [ ] **Attack the try → keep leak** (the new #1 item, from the funnel above): 2,322 users tried a
      rewrite, only 908 kept one. Instrument *why* a generated candidate gets discarded — the
      `ai_rewrite_action` breakdown (dismissed / regenerated / replace_failed) already exists and
      is the cheapest available diagnosis. Suspects in order: output quality, `replace_failed`
      (the replacement engine bailing because proxy context moved), and wrong-moment triggering.
- [ ] Exit gate: **Gate A (activation ≥25%) and Gate B (activated W2 ≥25%)** on two consecutive
      weekly cohorts.

## Phase 1 — Build the two exit assets (Aug → Oct)

**Asset A: the data pipeline** (today: 199 opt-ins, 677 eligible events, 0 raw-text consents — effectively nothing)

- [ ] Redesign consent UX: opt-in 7% → **30%+** (incentive: extra AI quota for opting in; fail-closed stays).
- [ ] Introduce a raw-text consent scope users actually accept (0 today = the current ask is wrong or invisible).
- [ ] Ship remaining data-platform phases; target **100k+ consented preference pairs by Dec** (replacement cost ~¥450–1,000/pair makes this a ~¥70M-replacement-cost asset — the floor of the data story).
- [ ] Buyer-shaped packaging: pairs = (context, candidates, chosen, edited?) with consent version attached.

**Asset B: revenue**

- [ ] Confirm current monetization state, then launch/tune subscription at **¥480–980/月** (anchors: 3秒敬語 ¥550, ATOK ¥660, LeapMe ¥2,500). Free tier = limited AI rewrites/day.
- [ ] Target: **3–5% paid conversion** → 300–500 subscribers by Dec (~¥3.5–6M ARR). Full financial-value path to 3億 needs ~8–10k subscribers (ARR ~1億) — that's the 2027 continuation story, not the Dec number.

## Phase 2 — Growth engines (Sep → Nov, only after Phase 0 gate)

Channels ranked by evidence (see `research/jp-market.md`, `research/benchmarks.md`). **Correction (2026-07-18): the two actual growth spikes came from RED (小紅書) UGC, not App Store (founder-reported).** RED is the proven spike engine; ASO is the steady high-intent floor. Caveat: RED brings the lower-retaining Chinese segment, so it only pays off *after* the Phase 0 retention gate — otherwise it pours the best channel into a leaky bucket.

1. **ASO / reviews** — we rank #4 on 敬語 and #3 on 敬語変換 **with 8 reviews**. A review prompt (timed after a successful rewrite) to reach 300–500 reviews plausibly takes #1 on both. 65–70% of App Store downloads follow a search. Cheapest steady wins; the always-on floor, not the spike source.
2. **UGC short-video (RED-proven)** — RED (小紅書) is the only channel that has actually spiked us (2 videos, ~4–5k likes/saves each). Same proven JP keyboard format: before/after in one screen (「り。→承知いたしました」), 大喜利 formats (限界タメ口→上司に送れる敬語). Re-fire RED for the Chinese segment; run TikTok+X for the JP 就活/新社会人 segment. 2–3 posts/week, seed 5–10 micro-creators.
3. **PR survey engine** — run 「就活生・新社会人の敬語不安調査」(this exact survey is an empty niche) → PR TIMES → media pickup, timed to **内定式 (Oct 1)**. Copy Simeji's playbook.
4. **Referral** — friend is already the #2 visible channel (323 users) with zero product support. Add a share moment (share your best rewrite).
- [ ] Targets: **10k downloads by Nov 30** (needs ~35–40/day avg vs ~15/day now — one PR/UGC spike covers it), then 15–20% MoM.

## Phase 3 — Exit process (Oct → Dec → 2027)

- [ ] Metrics one-pager + data room (auto-refreshed from `metrics-baseline.md` history).
- [ ] Narrative deck: 敬語×ビジネス日本語 niche独占 / consented in-situ preference pipeline (structural: SB Intuitions runs内製 annotation teams — our data is what they can't make) / revenue trajectory / team.
- [ ] Outreach order (from `research/exit-comps.md`): ① PKSHA (most active small-cap AI acquirer), ② SB Intuitions・ELYZA/KDDI・rinna (data story), ③ ジャストシステム・Baidu Japan・LINEヤフー (product synergy), ④ kubell・SmartHR・リクルート (distribution buy). Consider M&Aクラウド / banker for process pressure.
- [ ] BATNA: keep compounding to April 2027 新社会人 season — subscribers and pairs both grow, and seasonal demand peaks exactly then.

---

## KPI targets (Dec 31, 2026)

| Metric | Now (07-18) | Dec target | Why this number |
|---|---|---|---|
| Downloads | ~3,500 | **10,000** | 15–20% MoM + one spike |
| Users (profiles) | 2,851 | **8,000** | |
| WAU | 269 (AI) / ~75 (KB) | **≥2,000** (25% of users) | utility top-quartile stickiness |
| DAU | ~55 (AI) | **≥800** (DAU/WAU ≥40%) | enabled-keyboard users behave like daily utilities |
| Activation (install → activated) | 11.5% | **≥30%** | the binding constraint; Gate A is the 25% waypoint |
| W1 retention (activated) | ~30% | **≥45%** | already past the old ≥35% target under the v2 definition |
| W2 retention (activated) | ~16% | **≥30%** | where habit actually shows; Gate B is the 25% waypoint |
| D30 blended | ~5% 【推測】 | **≥10%** | top-decile utility bar; scaling below this wastes money |
| Paid subscribers | 0? (confirm) | **300–500** | 3–5% of 10k |
| Consent opt-in rate | 7% | **≥30%** | data asset viability |
| Consented preference pairs | 677 | **≥100,000** | replacement-cost floor ~¥70M |
| App Store reviews | 8 | **≥300** | #1 on 敬語/敬語変換 |
