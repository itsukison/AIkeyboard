# Weekly GTM Review Log

Newest first. Template at bottom.

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
