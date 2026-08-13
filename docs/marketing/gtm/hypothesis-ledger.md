# Hypothesis ledger — 敬語ボタン

**Every retention hypothesis we have held, what we did about it, and how it performed.**
Append a row when a hypothesis is formed; update the verdict when evidence lands. Never delete a
row — a retired hypothesis is the most useful kind.

Evidence lives in `retention-and-users.md`. Phase gates live in `roadmap.md`.
Last updated: **2026-08-13**.

**Verdict key:** ✅ supported · ❌ falsified · ⚠️ partly supported / confounded · 🔬 untested ·
🚫 retired (question turned out to be wrong)

---

## 1. Shipped interventions — what we actually built and what it did

| # | Hypothesis | Shipped | Approach taken | Measured result | Verdict |
|---|---|---|---|---|---|
| 1 | Interactive onboarding (practice pages + prompt editing) will raise the share of finishers who really use the AI | 1.0.15/16, 2026-07-27/28 | Before/after on `onboarding_completed` → ≥1 / ≥2 real rewrites in 48 h, controlled for the zh/ja locale mix shift | **Recovery to the early-July level, not a lift.** ja 45.5% (n=66) vs 47.2% early July — indistinguishable. Pooled new-vs-previous inside noise (z=1.38, p≈0.17). Reproduced server-side | ❌ |
| 2 | Forcing custom-button creation in onboarding will raise activation | 1.0.18 (`interactive_v3`), 2026-08-04/05, **straight to 100%** | Before/after anchored on `onboarding_started`, v2 (n=201) vs v3 (n=100), 48 h maturity + server-side cross-check on equal 3-day windows | Button creation **0% → 70%** (p<0.001), but ≥1 rewrite in 48 h **23.9% → 25.0%** (p≈0.83); ≥2 rewrites **fell** 17.9% → 15.0%. A large causal effect is **rejected at ~95% power** | ❌ |
| 2b | — *unintended side effect of #2* | same | `OnboardingButtonBuilderService.commit` drops the seeded 自然に / メール / 英訳 | Avg buttons per user **4.01 → 2.12**; triers using 2+ commands **22.4% → 14.3%**. Traded a strong predictor for a weak one | ❌ harmful |
| 3 | Upgrading the rewrite model to "GPT-Soul" will fix AI accuracy | claimed in 1.0.14, 2026-07-23 | Checked the model actually running in production | **Never deployed, or reverted.** 100% of the last 14 days is `gpt-5.6-terra`. The claim propagated into two docs unverified | 🚫 |
| 4 | Keyboard input-latency work will lift retention (churn reason #1) | 1.0.14, 2026-07-23 | Cohort comparison, 07-20/07-27 vs 07-06/07-13 | **No measurable response** — the cohorts do not separate. But with no typing-volume or crash instrumentation, absence of evidence here is weak evidence of absence | ⚠️ |
| 5 | A randomized builder-vs-control test will settle #2 causally | `OnboardingExperiment.swift` — built, 50/50 device-hash split, exposure event | Fired for **2 control + 2 builder users** on 2026-08-02, then moved to `archive/` in the same commit that shipped the builder to 100% | The single costliest decision in the dataset: converted an answerable causal question into an unanswerable one, on the exact intervention that then shipped | 🚫 |

**Pattern across #1–#4: four ships aimed at retention, zero measurable movement, and the retention
curve is flat across all seven weekly cohorts.** See `retention-and-users.md` §2.

---

## 2. Diagnostic hypotheses — what we believed about the funnel

| # | Hypothesis | Approach taken | Result | Verdict |
|---|---|---|---|---|
| 6 | "82% try the AI, so activation is fine — churn is the problem" | Re-anchored the funnel on value realization instead of installs | **Wrong diagnosis, not just a wrong number.** "Tried a rewrite" was a setup-completion rate: 85% of first real rewrites happen within 5 min of onboarding and 66% of those never return. Real activation is 11.5% | 🚫 |
| 7 | Onboarding practice taps contaminate the rewrite metrics | Code audit of `RewritePracticePage` / `firePractice()` | **False.** Practice mode answers locally with canned candidates and makes no network call, so it can never enter any denominator. The real contamination was #6 | ❌ |
| 8 | Retention should be measured against installs | Redefined onto activated users (kept ≥1 rewrite **and** returned for a 2nd rewrite day) | Retention reads **~30% W1 / ~16–18% W2** on the new denominator vs 5–18% install-anchored. **A definition change, not progress** — the old "W1 ≥25%" gate would have flipped green on no real improvement | ⚠️ definition fixed, gates restated |
| 9 | Container opens inflate the retention headline | Split return signal into rewrite / typing-day / open-only | **Essentially wrong.** Container-only returns are **0.1–3.5 pt** | ❌ |
| 10 | `replace_failed` is a hidden bug inflating the try→keep gap | Split `ai_rewrite_action` by action | **False.** 58 events, 1.3% of rewrites | ❌ |
| 11 | "Acceptance doubled to 47%" | Checked outcome coverage | **Coverage artifact.** Coverage is 75.5%; resolved-basis acceptance ~52% and roughly flat. Always publish coverage alongside acceptance | 🚫 |
| 12 | The install→signup collapse (79% → 50–59%) was caused by the new onboarding | Checked ship dates against install weeks | **Retracted.** The drop landed in the 07-20 install week, *before* 1.0.15's first `onboarding_completed` (07-26), in a week with a 3.3× install spike. Acquisition mix is better-supported; attribution is too weak to decompose | 🚫 |
| 13 | We have a good product receiving low-quality installs | Retention by self-reported source × locale | **Not supported.** No source separates by >6 pt on W1. `google` — the best available "actively searched for this" proxy — retains at **10.9%, below average.** Even high-intent users fail to retain | ❌ |
| 14 | Chinese/RED speakers are a second primary ICP | Retention by `$locale` on two different denominators | **Acquisition channel, not ICP.** zh is the largest volume segment and worst on `keyboard_usage_day` (W1 15% vs ja 29%), **but the gap does not replicate on rewrite retention** (10.2% vs 11.4%). Intent confound unresolved | ⚠️ |
| 15 | Full Access is a hard capability gate upstream of everything | Instrumented `keyboard_enabled` + `full_access_granted`, cohorted by gate state | **Supported and severe.** 51% of onboarding starters never confirm Full Access; that group tries a rewrite **10.8%** vs 50.4%, and reaches 2+ days at 3.6% vs 16.8%. Caveat: detection needs a container reopen, so the gap is inflated by detection bias | ✅ |

---

## 3. Product-quality hypotheses

| # | Hypothesis | Approach taken | Result | Verdict |
|---|---|---|---|---|
| 16 | Custom prompts cause retention (custom-prompt users showed ~4.9× volume) | Separated `user_prompts.origin`, then tested the reverse arrow via intervention #2 | **Selection bias.** 92 users created a button and only 10 ever ran a rewrite. Two users account for **82%** of all custom-prompt usage. The advantage is entirely in *volume*, not frequency — the "created 1, used it" group has a *lower* 2+ active-days rate (30.3%) than users who never created one (39.2%) | ❌ |
| 17 | Retained users escape 敬語 and expand to other commands | Unweighted per-user command mix across the 16 power users | **Does not survive unweighting.** The 18.9%-on-`polite` figure was dominated by one user. Per user, **5 of 16 are 100% `polite`** and 3 more are majority-`polite`. Half the retained cohort sustains a habit on the built-in 敬語 button alone | ❌ |
| 18 | Command breadth (2+ commands, 2+ sittings on day 1) is the aha moment | Day-0 behaviour → W1 return, full history; then replicated on recent signups | **Supported on full history** (9.8% → 21.1% W1, 4.7× to 5+ days), **weak on recent cohorts** (32.2% → 41.7%, n=12 in the top cell). Downgrade to directional | ⚠️ |
| 19 | Reply generation is a real job worth surfacing | Power-user cluster analysis | **No reply cluster exists.** 0.8% of power-segment volume; only 1 of 16 uses it meaningfully. Reply-pill exposure is *still* uninstrumented, so demand vs discoverability remains unseparated | ❌ (demand) / 🔬 (exposure) |
| 20 | High latency drives immediate abandonment | Latency by stickiness segment, twice on fresh data | **Not a discriminator.** Power users tolerate *more* latency (1,996 ms vs 1,745 ms). Input length is likewise flat | ❌ |
| 21 | The AI toolbar costs suggestion-bar width and quietly pushes users back to the native keyboard | Geometry measurement of `AIKeyboardToolbarView`; churn-email reading | **Structurally confirmed, retention effect untested.** AI chrome consumes ~30% of the strip by default, ~49% with the reply pill, ~68% with the update pill — paid on every keystroke by 100% of users. The reply pill is context-appearing, so the bar changes width unpredictably, matching the 「手感が変わる」 churn complaint | ⚠️ → 🔬 |
| 22 | The product's boundary is a **context** boundary, not a model-quality boundary | Accept-of-resolved by command × input length, user segment controlled | **Supported.** `polite` on 1–15 chars is the largest cell in the dataset (492 resolved outcomes for 1–2 day users) and accepts at **42.9%**; on 16+ chars it accepts at 57.1%. Only 48.8% of churners' accepted short outputs are candidate 1 — the register guess is a coin flip | ✅ |
| 23 | **The dominant failure is invocation targeting, not model quality** *(new 2026-08-13)* | Read the raw input/candidate text for 1,490 rewrites and built an input taxonomy | **~49% of invocations are on text that needs no rewrite or isn't a message**: 24.2% short-and-already-polite, 16.3% short fragments, 8.7% ≤3 chars (including mid-romaji mistaps like 「いまなんk」). **10.5% of rewrites return candidate 1 byte-identical to the input**; 3.5% return all three identical. 16+ char inputs no-op at only 3.7% and accept at 34.9% | ✅ |
| 24 | A visible failure predicts churn *(new 2026-08-13)* | No-op exposure on day 0 → 2nd-day return, stratified by day-0 volume | **Consistent −13 to −21 pt in all three volume strata** (35.1→22.2, 34.2→13.6, 50.0→32.0). **Not causal:** already-polite text produces both a no-op and, plausibly, less underlying need | ⚠️ |
| 25 | **Satisfaction is sufficient for retention** *(new 2026-08-13)* | Day-0 accept count and last-day-0-outcome → return | **Falsified.** Accepting twice on day 0 → only 41.0% return and 17.9% still active at d7. Ending day 0 on a success adds ~+10–14 pt at low volume, but **~59% of demonstrably-satisfied users still leave** | ❌ |
| 26 | Churners keep the keyboard and abandon only the AI | `keyboard_usage_day` after each user's last rewrite | **Untestable today.** 9.2% of churners typed after their last rewrite vs 10.4% who opened the app at all — the typing signal is ~90% gated on a container reopen. Among the observable ~10%, most *were* still typing, but that sample is unrepresentative by construction | 🔬 |

---

## 4. The free-text instruction question — tested in full

**Hypothesis:** users lack per-request control over the AI, so give them an optional free-text
instruction (before a rewrite, and/or after a bad result).

**Approach:** decomposed the four rich self-authored prompts by instruction component; burst-level
analysis of churner refinement behaviour; architecture read of `RewriteRequest` / `userPrompt()`;
raw-text scan for users already attempting instructions.

| Evidence **for** | Evidence **against** |
|---|---|
| Churners grind and fail — 2.73 attempts/burst, 34.6% refinement, 44.7% success vs 84.4% for power users | The two most successful users solved it **persistently**: one button, 565 uses, **0% refinement**. Refinement *falls* to near zero as users succeed |
| The existing escape hatch demonstrably fails — refining leaves a burst **less** likely to end accepted in 4 of 5 segments | Giving ordinary users prompt control **backfired**: churners on CUSTOM short inputs accept at **20.0%** vs 42.9% for `polite` |
| Register intent is unstated and message-specific — only 48.8% of churners' accepted short outputs are candidate 1 | Users don't iterate: regeneration is **3.6%** on mobile and **3.8%** on desktop; dismissals outnumber regenerations ~9:1 |
| The successful prompts are made of exactly the missing information — audience, relationship, channel, register ceiling | 63% of self-authored buttons were **never used once**; only ~11% were ever edited |
| Some users already reach for it — one pasted 「次の文章を…整えてください」 as the *input text* and had their instruction politely rewritten | Typing an instruction competes with just fixing the text yourself, at 11–47 chars of input |
| Backend cost is near-zero — one optional string on `RewriteRequest`, one line in `userPrompt()` | It re-imports the ChatGPT interaction the product's positioning is built against |

**Verdict ⚠️ — the diagnosis is right, the proposed remedy is aimed at the wrong tier.** The context
deficit is well evidenced. But the dominant failures found in §3 #23 are "the model correctly did
nothing" and "I invoked it on the wrong text", and free text fixes neither. The architecture does
conflate the two tiers by omission: a rich unbounded channel for **persistent** intent (the button's
`prompt`, up to `MAX_PROMPT_CHARS`) and a closed 3-case enum for **per-request** intent
(`morePolite` / `moreDetailed` / `moreConcise`). "Keep this part unchanged" has no expression at all.

**Ranked interaction models, current best evidence:**

| Rank | Approach | Per-message cost | Keyboard width | Verdict |
|---|---|---|---|---|
| 1 | **Capture persistent context once** (who you write to, how far to go, your voice) and inject it every rewrite | Zero | Zero | Best supported — existence proof in the two heaviest users at 81–87% acceptance |
| 2 | **Optional free text offered *after* the first output**, replacing the 3 canned refinements | Zero on the happy path | Zero (reuses the refinement row) | Worth shipping — small, touches only the failing tail, and *generates the data* to decide the rest |
| 3 | Instruction field always visible pre-rewrite | Low but constant | Small | Hold — costs width on every keystroke for a minority failure mode |
| 4 | Every AI tap opens an instruction input | High | Medium | Reject — taxes an 84%-success happy path |
| 5 | Natural language as the primary interaction | Highest | High | Reject — this is ChatGPT |

---

## 5. Open and untested — ranked by consequence

| # | Question | Why it's still open | Cheapest test |
|---|---|---|---|
| 1 | Does the toolbar's width cost actually drive churn? (#21) | Never tested; the most consequential untested hypothesis in the product | A/B default-collapse the AI chrome to one narrow affordance; measure `keyboard_usage_day` frequency + rewrite retention |
| 2 | Is the AI pill being tapped accidentally? (#23) | The ≤3-char evidence is suggestive, not decisive | Ship `ai_rewrite_invoked` + `dismissed_within_2s`. One event, ~1 week |
| 3 | Does suppressing the no-op change behaviour? (#24) | Association only | Server-side: when all candidates equal the input, return 「この文章はすでに自然です」 instead of three identical cards. Randomize on user hash, ~2 weeks, zero client work |
| 4 | Does supplying missing register context improve first-attempt fit? (#22) | Mechanism supported, remedy untested | Server-side: bias candidate 1 toward the user's modal accepted `selected_index`. Eligibility `polite` + ≤15 chars + ≥3 prior resolved outcomes. **Primary metric: candidate-1 rate among accepted (now 48.8%). Ship if +10 pt with acceptance not falling** |
| 5 | Does an optional free-text note rescue failed bursts? (§4 rank 2) | Only after #3/#4 report | Replace the 3 refinement chips with a free-text field. **Reject if free-text usage <10% — that kills ranks 3–5 outright.** Needs ~270 refined bursts/arm ≈ 4–6 weeks |
| 6 | Do churners keep typing? (#26) | Structurally unmeasurable | Typing volume as a count + extension crash reporting |
| 7 | Would keeping the seeded buttons restore command breadth? (#2b) | Two-line change, never tested | Stop dropping the presets in `OnboardingButtonBuilderService.commit`; measure 2+ command breadth |

**Standing rule learned the hard way (#5, #2):** do not ship a retention intervention to 100%
without an exposure event and a control arm. Four of the five shipped interventions in §1 are now
permanently unattributable.

---

## 6. Positioning — what the behaviour supports

| Candidate positioning | Verdict |
|---|---|
| **Personalized one-tap rewriter** | **Best supported.** The winning pattern is one button, tapped hundreds of times, fitted to this user's voice and audience |
| Preset rewriting keyboard | What it is today, and the shape the best user's behaviour takes |
| 敬語 utility | **Partly right, under-credited.** 8 of 16 power users sustain on `polite`. Also the worst-performing command on short inputs. **Not a trap — mis-served** |
| Customizable AI keyboard | **Not supported.** 13/16 power users never made a button; 63% of made buttons go unused; forcing creation moved nothing |
| Contextual AI writing assistant | **Not supported.** Regeneration 3.6%, refinement falls with expertise, edit rate 11%. Nobody in this dataset behaves like an agent user |

**Counter-signal to keep in view:** usage is spread across all hours with only a mild weekday tilt
(Sun = 35% of Tue peak), and the two heaviest users built buttons literally titled 「友達」 for casual
chat. The business-email framing may be narrower than the real job, which is **register control** in
both directions.
