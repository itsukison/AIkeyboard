# Sol release verification — October 5, 2026

**Released:** function v61, public rollout enabled at `2026-10-05T22:44:48Z`. Treatment is GPT-6.1 Sol / low with general-v2 or email-v2. Existing account split remains 50%; new accounts are assigned treatment. Exact button eligibility, custom protection and excluded modes still apply. No app update, global model switch or saved-button migration.

## Additional quality checks

Twelve new inputs exercised the exact isolated server request builder: casual and soft casual, senior chat, formal refusal, business notice, body-only email with URL, full email without identities, concise refinement, already natural text, five alternatives, and a detailed email with quantities, dates, a corrected budget and tentative commitments.

All requests returned the requested counts (1, 3 or 5). All 38 alternatives were reviewed: 33 pass, 5 caution, no clear material failure. Cautions are a polite softening of an unavailable morning, an awkward sender-side honorific in a long email, and thanks placed after the request in three concise email alternatives. See `assessment.json`; these are assistant judgments, not user acceptance measurements.

The previous study already reviewed 114 final-configuration alternatives across 33 distinct inputs. The release set is separate and was not used to modify the approved system strings.

## Timeout finding and fix

Direct API generation took 11.35 seconds for five complete emails and 16.79 seconds for a detailed three-email set. The old 11-second provider ceiling was inadequate. Only eligible treatment OpenAI requests now get an 18-second ceiling; buffered requests remain bounded by the existing 18-second total provider budget. Control/custom requests retain their configured limits. This leaves less time for fallback after a slow OpenAI timeout, while fast provider failures still have fallback time.

Live SSE stress tests completed all candidates. Server-recorded total latency was 7.23 seconds for five emails and 11.54 seconds for the detailed three-email set. These samples do not establish p95 or guarantee all long messages fit. Tail latency and partial/error rates remain launch-monitoring metrics.

## Verification

- Nine Deno suites passed: stable assignment and launch boundary; all 97 exact signatures; custom/stale/ambiguous inputs; v53 baseline and kill switch; candidate count and token limits; read-only Auth/button resolution; treatment-only model/timeout override; simulated streaming-start/OpenAI failure with Cerebras fallback; all provider request builders and streaming parity.
- Failure injection exercised the real isolated release provider functions with stubbed network responses. It confirms routing and requested-model attribution, not the live backup model's writing quality. No real provider outage was induced.
- Live buffered/streaming generation verified Sol and general-v2/email-v2 attribution for 1/3/5 outputs. Saved rows were unchanged by rewrite calls.
- Own disposable test-account buttons were renamed, reordered and edited to verify eligibility and exclusions, then restored. Edited/stale requests used v53 and the old model. Feedback/action joins still worked.
- Kill switch was verified live before activation: v53 and the old model, no internal override.
- After activation, a prelaunch account in existing_treatment and a post-launch new_treatment account both used Sol without any override. Control routing is covered by deterministic decision/builder tests and old-model live kill-switch/custom tests; no real user account was impersonated.
- Read-back of all seven deployed files matched the isolated release. JWT verification remains enabled.
- Initial post-launch edge snapshot contained two HTTP 200 smoke requests. No real-user experiment events had arrived in the first aggregate check; this is not evidence about user acceptance or sustained reliability.

A first standard smoke run overlapped a test-only button mutation from the stress run and correctly hit `stale_button`. The stress run restored its changes; the standard smoke was rerun sequentially and passed. No real user's button was involved.

## Operations

Public launch timestamp and experiment ID must remain fixed. Rollback: set `PROMPT_ROLLOUT_ENABLED=false` and `PROMPT_ROLLOUT_INTERNAL_IDS=`; retain the launch timestamp. `rollout_smoke.py disable` now preserves that boundary, and prelaunch `configure` refuses to replace a launched experiment.

Both disposable accounts and the temporary credential file were removed after verification. Smoke events are excluded from measurement by app version as well as internal-override flag. Source snapshots, response IDs and candidate records are saved here; credentials are not.

First formal review: at least 14 days after launch and 200 mature eligible generations from 50 accounts per existing-user arm. Earliest date: October 19, 2026, 6:44:48 p.m. New York. No automatic expansion or recurring automation was created.
