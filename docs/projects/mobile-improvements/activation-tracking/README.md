# Keyboard enablement and retention diagnostics

Status, October 9, 2026: implemented locally; unreleased. No
production deployment or improvement in conversion is claimed. Physical-device
acceptance and the next cohort measurement remain open.

## Problem and first change

The September 5–October 4 baseline used mobile PostHog project 465060, Asia/Tokyo,
excluding internal/test cohort 355646. Of 193 first-observed installs with seven
days of follow-up, 110 had observed keyboard enablement (57.0%). This is the
largest early observed loss: 83 people. Installation means first observed app
installation/open; actual App Store download conversion is unavailable.

Previously, the floating video was only on the Full Access help screen, and its
footage already had the keyboard enabled. The onboarding keyboard-setup screen
now uses a separate enablement video in Japanese, English, and Simplified Chinese.
On October 8, both guides were replaced with actual iOS Settings recordings from
an iPhone 17 simulator running iOS 26.5, with Settings localized in each language.
The October 9 revision starts both guides at the app's Settings page, matching
the Settings button's destination. Onboarding then opens Keyboards, enables
「敬語ボタン」 and Allow Full Access, shows the complete system confirmation and
confirmed enabled state, and instructs a return to practice. The separate Full
Access recovery guide uses an already enabled keyboard and shows only its
permission steps. Both toggles are separate from in-app AI consent and sign-in.

The primary CTA starts Picture in Picture before opening Settings. Written steps
and the static fallback remain available. Unavailable, not-ready, failed, and
timed-out PiP all still open Settings. Duplicate in-flight taps are ignored;
return/disappearance stops PiP. A rejected Settings open shows manual instructions.
On return, both permissions are checked; confirmed keyboard enablement and Full
Access advance. Keyboard-only return explains the remaining Full Access step. Explicit Skip
and the manual continuation remain available when system detection is unreliable.
Manual continuation without both permissions detected is recorded as
`continued_unconfirmed`; `detected` continues to describe keyboard enablement.
The setup return/recheck events additionally include `setup_complete`.

Capture provenance and the reproducible edit recipe are in
[`docs/assets/keyboard-enablement/README.md`](../../../assets/keyboard-enablement/README.md).
Permission steps use a closer crop. Pauses are shortened, and localized instructions
and tap markers are added. Subtitles are white text on a roughly 75%-opaque black
background, sized to the text with padding. Verified native screenshots
hold the completed state; no Settings controls or permission states are drawn.
The MP4s retain the existing filenames, 666×990 dimensions, silent H.264 playback,
and the existing player/PiP/Settings-opening implementation. Combined onboarding loops are
15.5 seconds; Full Access recovery loops are 13 seconds, including five seconds showing the
uncovered system notice. No runtime dependency is added to either iOS target.
Physical iPhone PiP and return-to-app verification remain open for the user.
All six replacement clips passed visual inspection, full decoding and final-state
checks. The October 8 unsigned simulator build succeeded and packaged identical
copies of all six MP4s. No app release is claimed.

October 9 validation: the six revised clips passed visual review, full decoding,
format/duration checks and final-state switch checks. The unsigned simulator
container/extension build succeeded for arm64 and x86_64. All six bundled videos
match the source outputs byte for byte, and the seven setup strings match their
English/Simplified Chinese translations in the built app. Physical-device PiP
and return-to-app permission detection remain unverified.

## New event contract

Existing events and successful server `ai_rewrite` / `ai_rewrite_accepted` retain
their meanings. New events supplement them; never sum server acceptance and local
replacement acceptance as two acceptances.

| Question | Event / properties | Source |
|---|---|---|
| Was a step entered, then completed, deliberately skipped, or bypassed? | `onboarding_step_entered`, `onboarding_step_exited`; `step`, persistent `onboarding_attempt_id`, unique `step_entry_id`, `outcome`, `duration_ms`, `detected` when applicable | Container |
| Was keyboard setup instruction delivered? | `keyboard_setup_guide`; `guide_attempt_id`, outcomes `requested`, `pip_started`, `pip_unavailable`, `pip_not_ready`, `pip_failed`, `pip_start_timeout`; video availability | Container |
| Did Settings open and did enablement become observable? | `keyboard_setup_settings_opened.accepted`, `keyboard_setup_settings_returned.detected`, `keyboard_setup_rechecked.detected` | Container |
| Was permission observed later? | `keyboard_permission_observed.full_access`; first controller observation and subsequent state changes | Local App Group relay |
| Did someone actually request AI, and what prevented it? | `ai_rewrite_attempted`, `ai_rewrite_attempt_blocked`; `readiness_blocker`: Full Access, sign-in, consent, cloud disabled, empty/unavailable/too-long capture, empty reply source | Local relay, explicit AI commands only |
| Did a request reach the server or fail there? | `ai_rewrite_attempt_received`, `ai_rewrite_server_failed.failure_reason`, `ai_rewrite_stream_interrupted`, `ai_rewrite_server_cancelled` | Existing backend request |
| Was output actually available to read? | `ai_rewrite_generation_started`, `ai_rewrite_first_candidate_shown`, `ai_rewrite_result_shown`, `ai_rewrite_generation_failed`, `ai_rewrite_generation_cancelled` | Local relay |
| Was replacement successful? | `ai_rewrite_replacement`; `outcome=accepted/failed`, exact originating `event_id`, local `selected_index` | Local relay |
| Was a result explicitly dismissed or closed automatically? | `ai_rewrite_result_closed`; `close_reason=explicit_dismissal/document_changed/superseded`, originating `event_id` | Local relay |
| What did the user explicitly report? | `ai_rewrite_usefulness`; `reason=useful/wording/meaning/latency/replacement`, exact `event_id`, local `selected_index` | Optional result menu → local relay |

Practice exit outcomes are `completed` only with confirmed detection/accepted
replacement; otherwise a timeout-enabled Continue is `timeout_bypass`. Explicit
Skip stays separate. Other exits include `back`, `declined`, and
`continued_unconfirmed`. A cold resume carries `resumed_from_entry_id`; it does
not manufacture a terminal outcome for the earlier visit. View re-rendering must
not generate a new page-entry record.

Container events carry app version/build and actual `occurred_at`. Step events
include keyboard-enabled/active state, current system Full Access detection,
last observed extension Full Access state, and consent state. These observations
are distinct: a historical extension flag is not proof of current permission.
The legacy one-shot `full_access_granted` now also accepts current system
detection and records `detection_source`; its timestamp remains detection time.

Each explicit AI command starts a unique `attempt_id`. Requests carry
`diagnostics`: attempt/root IDs, optional parent generation ID, generation kind
(`fresh`, `regenerate`, `refine`), actual attempt time, onboarding attempt ID and
app build. The backend validates these fields and adds their metadata to
successful generation analytics/DB payloads; older clients omit them and keep
their original behavior. Server time is reception time; client attempt time is
also retained and is client-reported, not trusted server clock time.

Fresh commands start new roots; regeneration/refinement retain the original root.
Refining or accepting an earlier candidate uses that candidate's generation, not
the latest batch. Replacement failures and result closes now also use that exact
segment. Feedback is a user report, not proof of satisfaction or a technical
failure. The optional menu does not interrupt acceptance.

## Privacy, identity, and remaining blind spots

- No diagnostic collects text, prompts, clipboard contents, host app identity,
  keystrokes, or free-form error messages. Only categorical metadata and IDs.
- The keyboard has no analytics SDK. New local diagnostic writes occur on
  explicit AI interactions and permission observations, never on ordinary keys.
  No new keyboard telemetry network request is added. Backend tracking uses
  the already-authorized rewrite request, with background analytics capture.
- Local events have unique keys in App Group, occurrence timestamp and the
  PostHog distinct ID cached at occurrence. The container relays them on initial
  appearance and foregrounding with that original identity, original timestamp,
  `$insert_id`, relay time and delay. Account changes do not relabel queued events.
  Events without a captured identity are discarded rather than assigned to a
  different later account. This is an explicit loss mode.
- The local queue retains at most 200 events. A drain acknowledges only its
  snapshot's keys, preserving events appended while draining. SDK enqueue is
  best effort, not an ingestion acknowledgement. Crashes, overflow, inaccessible
  App Group storage (including permission-related restrictions), uninstall, or
  never reopening the container can lose signals. Missing local events remain
  unknown behavior. Metadata values from the extension are strings.
- Server requests are observable even without a later app reopen, after the
  backend change is deployed. Requests blocked before transmission, rejected by
  the gateway, malformed before request parsing, or lost in transit are outside
  server coverage. Analytics ingestion itself is best effort. Server-received
  attempts and relayed attempts must be joined/deduplicated by `attempt_id`.
- Existing best-effort selection/action feedback continues; new relay events
  supplement it. Do not call missing acceptance rejection or missing feedback
  satisfaction. The actual time permission was toggled in Settings is unmeasured.

## Next gap to fill

Prioritize signup → first live generation after enablement. In the mature
baseline, 47 of 98 signed-up users generated within seven days; 51 did not.
Among those 51, 28 lacked observed Full Access, 17 had last declined consent,
with overlap 12: 33 had at least one recorded barrier. Missing permission
detection is not proof that permission was off. The remaining 18 had both
permission evidence and consent but no successful generation, whose cause was
not observable without attempt/failure tracking.

The next product change should provide a post-signup readiness check and one
clear path to a first live rewrite: guide missing permission, respect consent
decisions, confirm that the demo has ended, and let the user explicitly request
AI on their own text. Do not automatically submit host text on recovery. This
second flow is proposed, not implemented in this change; fix and measure gaps
one at a time.

## Validation and release

Local checks: unsigned app + extension build passed; 55 AI tests and four new
App Group diagnostic tests passed; 13 backend tests passed, including metadata
privacy/lineage, older-client behavior, server-received failures, and the existing
prompt rollout. The three localized clips were visually checked and are present
in the built app. No physical-device PiP, peak-memory, or measured-conversion
claim follows from these checks.

`backend-diagnostics.patch` contains only this session's changes to the existing
Edge Function. It applied cleanly to the captured v61 release at
`/private/tmp/key-prompt-rollout-release`, whose original `index.ts` SHA-256 is
`1daf1f38575361b825bcbe3753a9732ab5376c2b4d688412e3e51934db639f5b`.
The isolated patched copy is `/private/tmp/keigo-activation-release`; add
`rewrite-diagnostics.ts` from the backend source. Type checking and the same 13
tests passed against the isolated release. Never deploy the dirty local backend
wholesale. No schema migration, prompt, model, experiment assignment or saved
button change is needed for this diagnostic patch. No backend deployment was
performed. The app changes require the next app release.

Physical-device acceptance must cover fresh keyboard disabled/enabled states,
Settings open rejection, PiP unavailable/failed, repeated taps, app background/
return, dismissal/back/skip, all three languages and large text/VoiceOver. Confirm
both enablement and Full Access guides float over Settings on a supported device.
Verify keyboard practice success vs timeout vs Skip, earlier-candidate replacement
after regeneration, explicit vs document-change close, usefulness selection,
offline relay, app relaunch, account switching and complete live rewrite recovery.

After release, compare mature seven-day first-observed install cohorts by app
version/build and cohort week with the same exclusion/timezone. Primary outcome:
observed keyboard enablement (baseline 110/193); also report actual setup-page
entry → Settings open → return → confirmed detection and all bypass outcomes.
Guardrails: signup and first live generation (98 and 48 of the baseline 193),
replacement acceptance, failures and useful return. Use fourteen days as a
sensitivity; immature windows are unavailable. There is no randomized experiment
in this change, so before/after differences remain associations.

For the next signup change, use successful live generation after signup
(47/98 baseline) as the primary outcome; observed attempt blockers and failure
categories explain the residual gap. Then evaluate days 1–7 and 8–14 return from
first real acceptance, counting independent fresh generations separately from
regeneration/refinement and app reopening separately from AI reuse.
