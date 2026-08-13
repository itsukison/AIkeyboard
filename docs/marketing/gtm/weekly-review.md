# Weekly GTM Review Log

Newest first. Template at bottom.
Note: entries before 2026-08-13 reference `metrics-baseline.md` and `churn-signals.md`, which were
consolidated into `retention-and-users.md` + `hypothesis-ledger.md` on that date. The references are
left as written because these are dated records of what happened at the time.

---

## 2026-08-13 (independent retention diagnosis + doc consolidation)

**Numbers**: users 3,318 | signups 8.6/day (was ~21/day on 08-02) | AI WAU 163 (−22% WoW) | W1 (first-rewrite) 9.4–16.0% | opt-ins 569
**Phase**: 0. Gate A activation ≥25% (11.5% ❌) + Gate B activated W2 ≥25% (13–18% ❌)
**What happened**: Independent pass over PostHog full history + Supabase, including the ~1,500 consented raw-text rewrites no prior investigation had opened. Then consolidated five overlapping metrics docs into `retention-and-users.md` + `hypothesis-ledger.md`, moved six content docs to `content-ops/`, and dropped the expired 08-05 reorg handoff.
**Learned**:
1. **Retention is flat across all seven weekly cohorts and four onboarding versions.** Onboarding is not the lever; four shipped interventions produced no measurable movement.
2. **Full Access is the binding structural gate.** 51% of onboarding starters never confirm it; that group tries a rewrite 10.8% vs 50.4%. Detection bias inflates the gap but does not explain it away.
3. **~49% of AI invocations are fired at text that needs no rewrite or isn't a message** — already-polite 短文, fragments, ≤3-char mistaps (including mid-romaji slips, direct evidence for the toolbar mis-tap hypothesis). 10.5% of rewrites return candidate 1 byte-identical to the input.
4. **Satisfaction is not sufficient.** Two accepts on day 0 → only 41% return, 17.9% active at d7. ~59% of demonstrably-satisfied users still leave. This constrains every quality-only remedy.
5. **The desktop free-text precedent doesn't exist in telemetry** — `desktop.rewrite_events` has no per-request instruction field, and only 130 events from 6 users. But it *does* have the `status` enum (= the missing `ai_rewrite_failed`) and `host_app_bundle_id` that mobile lacks.
**Next (≤3)**:
1. Ship `ai_rewrite_invoked` + `dismissed_within_2s` and copy desktop's `status` enum — the two cheapest missing data points, both gating bigger decisions.
2. Server-side no-op suppression test (return 「この文章はすでに自然です」 instead of three identical cards), randomized on user hash, zero client work.
3. Decide the free-text question on the refinement row only, with the <10% usage kill gate — not as a new input-bar button.

---

## 2026-07-30 (retention-definition reset)

**Numbers**: activation (install → activated) 11.5% | W1 activated ~30% | W2 activated ~16–18% | W4 not yet mature | habit (5+ rewrite days) 2.8% | Supabase topline not re-pulled (07-18 figures are stale)
**Phase**: 0. Gate rewritten → Gate A activation ≥25% (11.5% ❌) + Gate B activated W2 ≥25% (13–18% ❌)
**What happened**: Retention re-defined off installs and onto value-realizing users, per senior-founder/investor feedback. Canonical definition = kept ≥1 rewrite (`ai_rewrite_accepted`) **and** returned for a 2nd rewrite day, clock starting on that 2nd day. Two dashboard tiles added (`bOO86jSD` retention, `bhsljVns` funnel); the existing AI-rewrite tile was configured `retention_recurring` against a description claiming "at least once" — corrected to `retention_first_time`. `GTM.md`, `roadmap.md`, `metrics-baseline.md` updated.
**Learned**:
1. **The diagnosis was wrong, not just the number.** Activated users retain ~30% W1 / ~16% W2 — near utility top-quartile. The crisis is activation: 11.5% of installs.
2. **Onboarding contamination was real but not where expected.** Practice mode is local/canned and emits no `ai_rewrite` at all, so onboarding taps were never in the denominator. The contamination is that **85% of first *real* rewrites happen within 5 min of `onboarding_completed`** and 66% of those never return — so "tried the AI" ≈ "finished setup". Requiring a 2nd rewrite day is what removes it.
3. **The biggest leak is try → keep**: 2,322 tried a rewrite, 908 kept one (39%). Output quality / `replace_failed` / wrong moment — diagnosable today from the `ai_rewrite_action` breakdown.
4. Changing a denominator silently moves gates. The old "W1 ≥25%" gate would have flipped green at 30% and unlocked acquisition spend on no real progress.
**Next (≤3)**:
1. Diagnose try → keep via `ai_rewrite_action` (dismissed / regenerated / replace_failed split), and check whether `replace_failed` is a real bug.
2. Ship the selected_index feedback endpoint to full coverage — step 4 of the funnel is currently a floor at ~30–38% event coverage, so activation is understated by an unknown amount.
3. Re-pull the full Supabase topline at the next Friday review and fill the 07-30 history row.

---

## 2026-07-18 (baseline week)

**Numbers**: users 2,851 | AI WAU 269 (prev 425, −37%) | AI DAU ~55 | new users ~15/day | opt-ins 199 | eligible pairs 677 | reviews 8
**Phase**: 0 (retention). Gate: W1 ≥25% — currently 5–18%. ❌
**What happened**: GTM system created; baseline + research completed (benchmarks, JP market, exit comps).
**Learned**: launch spike (~2,600 users, source invisible/App Store-ish) is decaying; core of ~60 daily users exists; ASO rank #3–4 on 敬語/敬語変換 with only 8 reviews.
**Next (≤3)**:
1. Fix PostHog identity mismatch + define canonical keyboard DAU.
2. Churn diagnosis: instrument keyboard_enabled properly, survey one-day users vs 5+day core.
3. Ship selected_index feedback endpoint (17% → 90% coverage).

---

## Template

```
## YYYY-MM-DD

**Numbers**: users X | AI WAU X (prev X, ±X%) | AI DAU X | new/day X | opt-ins X | eligible pairs X | reviews X | paid subs X
**Phase**: N. Gate: <gate> — <status> ✅/❌
**What happened**: <shipped / launched / spiked>
**Learned**: <insights>
**Next (≤3)**: 1. … 2. … 3. …
```
