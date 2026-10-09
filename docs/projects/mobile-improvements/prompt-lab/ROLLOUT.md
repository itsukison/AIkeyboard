# Prompt and model rollout: active

2026-10-05. Supabase `keyboard-rewrite` v61 is active. The fixed public launch boundary is **2026-10-05T22:44:48Z** (6:44:48 p.m. New York). Existing accounts are deterministically split 50/50; accounts created at or after that boundary receive treatment assignment. Internal overrides are cleared.

Treatment uses **GPT-6.1 Sol / low**, with `general-v2` or `email-v2` (the reviewed lab v4 strings). Control, customized/unrecognized buttons and excluded modes retain the original provider configuration and v53 prompts. This experiment compares a prompt-and-model package, not a prompt-only change. The provider timeout is 18 seconds only for treatment OpenAI requests, within the existing buffered 18-second total rewrite budget. Global model and timeout secrets were not changed.

Nine automated suites passed. Twelve additional fresh inputs produced 38 reviewed alternatives with no clear material failures and five documented cautions. Live checks verified streaming/buffered responses, 1/3/5 candidate counts, five complete emails, a detailed email, model/event attribution, custom/stale/renamed/reordered protections, and rollback to the old model. Public routing was verified on an existing treatment account and a newly created account without overrides. Read-back matched all seven deployed files. See [release evidence](validation/sol-release/REPORT.md).

The requested policy is implemented: deterministic 50% treatment for accounts created before activation, 100% treatment assignment for accounts created afterward. Customized/unrecognized buttons and excluded modes retain the deployed v53 system and original command. No button migration, reset, reorder, or app release is required.

## What ships

- `prompt-rollout.ts` reads the authenticated account's creation time from Auth and current saved instructions from `user_prompts`, with a 1.5-second lookup deadline. Lookup failure uses v53. Disabled rollout skips these lookups entirely.
- Assignment is SHA-256 of `natural-alternatives-2026-10-v1:<account ID>`; first byte below 128 is existing treatment. Identity, experiment ID and launch timestamp must remain fixed after activation.
- 97 exact shipped instruction signatures cover built-ins, legacy built-ins, fixed casual presets, deterministic keigo/casual/email onboarding combinations and natural-writing complements. Unsupported/partial/free-text combinations stay on v53. This deliberate exclusion is not an assertion that those prompts are poor.
- Ownership, exact saved contents and command key are checked. Button ID disambiguates when available. Legacy clients must match exactly one owned button. Titles/order/slot/enabled state do not determine eligibility. Explicitly user-authored rows are excluded even when their text matches a standard template.
- Reviewed general/email systems are frozen in `approved-prompts.json`; the requested candidate count is supplied in the user message. The command mapping changes only request-time wording. Existing body-only and no-signature constraints remain effective. Email allows 1,200 output tokens per candidate; general retains the provider's existing limit.
- Translation, summarization, proofreading, replies, selected fragments and non-Japanese locale requests retain v53. Normal eligible refinements retain the existing refinement instruction.
- Optional `buttonId`, `buttonPurpose`, `promptOrigin` are accepted; no required API fields or response shape changed. The server ignores any client-supplied rollout decision. Purpose is never sufficient for eligibility.
- Rewrite metadata records experiment, assigned cohort, actual version, eligibility/reason, resolved purpose, matched template version, enabled state and internal-test flag. Effective commands are not added to analytics. Consent and raw-text retention remain unchanged.

## Isolation and verification

The working tree already contained unrelated backend edits. `integrate_rollout.py` builds `/private/tmp/key-prompt-rollout-release` from the captured live v53 in `rollout-v53.json`, overlaying only this feature. `--local` also applies integration hooks to the working source without replacing its existing edits. Never deploy the dirty working index as though it were the verified isolated release.

```sh
python3 docs/projects/mobile-improvements/prompt-lab/build_rollout_assets.py
python3 docs/projects/mobile-improvements/prompt-lab/integrate_rollout.py
deno check supabase/functions/keyboard-rewrite/index.ts /private/tmp/key-prompt-rollout-release/index.ts
deno test --allow-env --allow-read supabase/functions/keyboard-rewrite/prompt-rollout_test.ts supabase/functions/keyboard-rewrite/prompt-rollout-integration_test.ts
```

Seven suites passed, including 1,000 deterministic assignments, all 97 registry entries, customized/stale/ambiguous requests, legacy system equality, all provider builders, streaming/buffered request parity, refinements and 1/3/5 candidate counts. Read-only lookup tests assert GET-only access. The rollout code contains no writes to saved buttons.

Live disposable-account tests passed for buffered and streaming generation, event attribution, renamed/reordered buttons, edited built-ins, stale requests, and feedback/action joins. Only the disposable account's buttons were edited for protection tests, then restored. Evidence is under `validation/rollout/live-*.json` and `disabled-smoke.json`; credentials are never saved in this repository.

## Initial failed gate (historical, superseded)

The first API run used ten fresh cases and three regressions. It exposed old command wording retained during integration. The mapping was corrected to the approved wording and the same cases were rerun; unchanged requests were reused. These reused cases are now regression cases, not a fresh holdout.

The final 39 candidates were reviewed individually: **20 pass, 11 caution, 8 fail**. These are assistant assessment labels, not acceptance rates or user votes. See `validation/rollout/assessment.json` with request hashes and candidate-level notes; exact requests/responses are retained in `runs/`.

Material remaining failures:

- `来週の休み日曜ならないとわからん` becomes uncertainty about whether Sunday itself is a day off. All three candidates fail this case.
- Shipping capability becomes a promise; one discount candidate changes difficulty into a definite refusal.
- One body-only email uses `お急ぎではございません`, shifting the sender's lack of urgency to the recipient.
- A two-hour booking inquiry becomes approximately two hours; another email drops the original quantity from a comparison.

That initial launch gate failed and public treatment stayed off. Subsequent model comparison, collaborative review, prompt iteration and fresh release testing resolved the clear failures; the user selected Sol and requested additional release testing. The validated package was activated at the timestamp above. This does not establish a population acceptance rate or justify expansion beyond 50%.

## Activation and rollback

Retain `EXPERIMENT`, the assignment algorithm and **2026-10-05T22:44:48Z** permanently for this experiment, including rollback/resume. The `2026-10-05T00:00:00Z` value used during isolated internal verification was provisional; it was never a public launch boundary.

Controls are server secrets:

- `PROMPT_ROLLOUT_ENABLED=true` activates the rollout; any other/missing value disables it.
- `PROMPT_ROLLOUT_LAUNCH_AT=<fixed UTC ISO timestamp>` defines account age. Missing/invalid time cannot enable a public treatment request. Never change it after activation.
- `PROMPT_ROLLOUT_INTERNAL_IDS=<comma-separated test account IDs>` allows controlled prelaunch testing while public rollout is disabled. Keep this empty in normal operation.

Rollback sets `PROMPT_ROLLOUT_ENABLED=false` and clears `PROMPT_ROLLOUT_INTERNAL_IDS`. This restores v53 behavior without changing saved prompts or assignment rules. Keep the original activation timestamp during an actual rollback/resume. Full function rollback can redeploy the captured v53 files with JWT verification enabled and its included deno configuration.

## Measurement

`rollout_metrics.sql` was validated read-only against production. It separates existing treatment/control, new users, purposes and excluded requests; excludes internal events; and uses a 24-hour feedback maturation window. Acceptance is `selected_index IS NOT NULL` joined by rewrite event ID. It reports event-weighted and mean user acceptance, accounts with at most five generations, refinement-generation share, explicit dismissals, latency and token usage. Refinement share is not a linked retry-conversion rate.

Inspect structured `keyboard_rewrite` error logs by experiment/cohort/version alongside the successful-event SQL. Stream transport/start failure logs also carry attribution; do not double-count a transport log and its terminal error. Successful generations are not an attempts denominator. Missing acceptance alone is not a quality rejection.

Review no earlier than October 19, 2026 at 6:44:48 p.m. New York, and only after 200 mature eligible generations from 50 accounts per existing-user arm. Evaluate purposes and user-level distributions as well as aggregate rates. Keep 50/50 when inconclusive; require a separate decision before expansion. No recurring automation is installed. Public-route smoke events use `app_version=rollout-internal-test` and are excluded by the metrics SQL even when `internal_test=false`.
