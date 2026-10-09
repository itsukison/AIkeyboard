Status: Backlog captured 2026-10-05; current implementation and validation status is recorded in each section. Work through remaining items one at a time.

# Mobile improvement backlog

The desktop app was pursued after mobile hit limitations in native-feeling typing
responsiveness and AI output quality. Work on desktop has since produced lessons
in prompt design, output evaluation, and measuring the actual product bottleneck.
Apply those lessons to mobile and test whether they improve real user outcomes.
Start with the iOS keyboard in this repository; carry relevant lessons to other
smartphone versions when those are revisited.

## 1. Urgent: restore toolbar login and permission recovery

- [x] Reproduce the reported regression after the user's recent iOS upgrade.
  Affected device: iPhone (5), iPhone 14, iOS 26.6.1 (23G83), app 1.0.19 (22).
  Privacy CTA taps reached the handler, but `openURL` returned false with
  `LSApplicationWorkspaceErrorDomain` code 115 while Full Access was disabled.
  The user confirmed that enabling Full Access made the button work. Login uses
  the same helper; its end-to-end recovery still needs separate verification.
- [ ] Fix the toolbar login button, which the user reports no longer works.
- [ ] Fix the toolbar permission/settings button, described by the user as
  "open accessibility." Verify the actual control and destination: iOS keyboard
  Full Access is distinct from macOS Accessibility permission.
- [ ] Make recovery understandable from the keyboard when sign-in or permission
  is missing. Users currently have to find the container app themselves and
  sign in again or regrant permission; that is too difficult to discover.

Completion means verifying the full recovery on a real affected device: tap the
toolbar action, reach the correct destination, sign in or grant permission,
return to the host app, and successfully use AI. Cover signed-out/expired-session
and missing-Full-Access states. A button responding or a destination opening
alone does not establish that recovery works.

### Recovery implementation — October 5, 2026

Implementation is ready for device verification; the completion checkboxes above remain open until
real-device acceptance. The keyboard now prioritizes Full Access setup, login,
consent, then Cloud AI enablement. It shows local manual instructions without
Full Access, and a retryable fallback if iOS rejects app opening. Login routes to
existing authentication directly; a valid container session is refreshed and
republished for the keyboard. Temporary authentication/network failures preserve
credentials, including at container startup. Recovery never automatically sends
the host's text after returning.

Follow-up: the Full Access toolbar action now says 「フルアクセスを許可」.
The app's 設定 → 敬語ボタンについて → フルアクセス screen reuses the
bundled Japanese setup video and Picture in Picture coordinator. Its
「動画を見ながら設定を開く」 action starts the floating guide before opening
app settings. Background audio capability is enabled in the container only,
as required for PiP. The keyboard still shows local instructions while Full
Access is off because app opening failed in that state on the affected phone.
Permission is requested first when missing, not repeatedly after it is granted.
Floating playback over Settings still requires real-device verification.
The follow-up unsigned device build passed for app and extension; the built app
contains the Japanese clip and the required `UIBackgroundModes = audio` entry.

The keyboard's manual help was subsequently shortened to search Settings for
「敬語ボタン」 → Keyboards → Allow Full Access. The Full Access panel now has
only the heading, instructions, and Close; the video explanation and manual
recheck button were removed. Automatic appearance/action checks remain. Recovery
copy and controls are bundled in Japanese, English, and Simplified Chinese and
follow the device language. The existing keyboard overlay sizing is unchanged.
The container's video guide remains available separately.
The shortened-help build passed for app and extension, and all three translated
instruction/Close strings were verified in the built extension bundle.

Focused automated coverage includes all readiness combinations, URL acceptance /
rejection / duplicate taps / late callbacks, refresh success and failure,
buffered and streaming 401 retries, and credentials replaced during a request.
Validation on October 5:

- Final unsigned iOS device build: passed for container and extension.
- iOS 26.5 simulator: all 52 `JapaneseKeyboardAITests` passed, including 13 new
  recovery tests.
- `JapaneseKeyboardUITests`: 32/34 passed. The unchanged numeric/symbolic
  punctuation tests expect half-width `?`/`!`, but the unchanged layout returns
  full-width `？`/`！`. No punctuation code or expectations were changed here.
- `git diff --check` passed for the affected source and test files.
- Physical-device recovery, accessibility/layout checks, and peak memory remain
  unverified; no release or device-install claim is implied by these builds.

Real-device acceptance still required:

- Full Access off: signed out, signed in, consent missing; setup help and typing.
- Japanese Full Access guide: video remains visible over Settings, permission
  confirmation, return to app, dismissal, repeated taps, and PiP unavailable.
- Full Access on: login, consent, settings, update, and rejected-open fallback.
- Expired/rejected session, offline startup/recovery, cancel, repeated taps, and
  revocation of Full Access.
- Cold/warm app, unfinished onboarding, and competing app presentations.
- Flick/QWERTY, light/dark, large text, and VoiceOver activation.
- Complete permission/login/consent recovery, return to Notes and another host,
  explicitly request a rewrite, and successfully replace text.
- Profile the extension with help visible; confirm peak memory under 40 MB.

References: [Apple keyboard open access](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard),
[Apple OpenURLAction](https://developer.apple.com/documentation/swiftui/openurlaction),
[Supabase sessions](https://supabase.com/docs/guides/auth/sessions).

## 2. Enable keyboard haptic feedback by default

- [x] Verify the effective fresh-install default across initialization and UI.
  Source audit found both the shared reader and settings UI defaulted to false,
  with no separate initialization or registered default for this preference.
- [x] Make haptics enabled when the user has not chosen a preference, while
  preserving an explicit choice to disable them.
- [ ] Verify fresh-install, upgrade, and settings-toggle behavior on device.

**Status, October 5: implemented; physical-device acceptance pending.** An
absent preference now defaults to On in both the shared reader and settings UI;
existing stored choices are preserved without migration or an initialization
write. Turning On without Full Access saves the choice and shows the existing
permission explanation. Actual feedback remains gated by Full Access, so
revocation never changes the preference and granting permission allows feedback
when the keyboard next refreshes its state. Feedback strength, timing, and key
callbacks are unchanged.

Validation on October 5:

- iOS 26.5 simulator: all 22 `KeyboardSettingsStoreTests` passed, including five
  new haptics tests for absent/Off/On preferences, unavailable defaults, and
  reading without persisting the default. A temporary tests-only scheme avoided
  the unrelated container build failure and was removed after verification.
- Unsigned iOS device build of `KeyboardExtension`: passed.
- Full container/extension build: blocked by the existing missing `purpose`
  argument in `UserSession.swift`'s `UserPromptRemoteStore.updatePrompt` call.
  The unrelated prompt/authentication changes were left untouched.
- `git diff --check` passed for the affected tracked source and test files.

Device acceptance must cover fresh install, upgrade with stored Off/On choices,
settings changes after reopening the keyboard, enabling without Full Access,
permission revocation/restoration, and QWERTY/flick/candidate feedback without
duplicate pulses. The affected iPhone was offline during this session; no
physical-device haptic validation or release is claimed.

## 3. Develop the polite prompt through user-selected outputs

**Status, October 5: implemented and live.** Eligible buttons for 50% of existing
accounts and all new accounts now use `gpt-6.1-sol` and the approved general/email
prompts. Controls, customized prompts, and excluded modes retain legacy behavior;
saved buttons are untouched. The remaining work is the outcome review, no earlier
than October 19 and after at least 200 mature eligible generations from 50
accounts in each existing-user arm. See the [rollout runbook](prompt-lab/ROLLOUT.md)
for exact criteria, evidence, and rollback. No review automation is scheduled.

The workflow is collaborative; do not choose the winning output or finalize the
prompt without the user's selections.

- [x] Ask AI to propose candidate prompts and realistic scenarios: rough intent,
  fragments, and messages people would actually type on a phone, with enough
  recipient/context information to evaluate appropriate politeness.
- [x] Generate multiple actual polite-language outputs and present options for
  the user to compare. Include common requests, refusals, apologies, scheduling,
  and follow-ups rather than only already-polished source sentences.
- [x] Have the user pick the best outputs and explain preferences where useful.
- [x] Reverse-engineer the prompt together from those choices, then generate
  again and iterate. Preserve facts, meaning, social intent, and commitment
  strength while improving wording and register.
- [x] Check the resulting prompt on fresh scenarios that were not used to tune
  it, and retain representative preferred outputs as evaluation examples.
- [ ] Validate the shipped result through acceptance and repeat use, alongside
  output review. Assertions about prompt strings alone do not establish quality.

## 4. Replace PostHog dashboard noise with decision-useful insights

**Status, October 5: treated as done based on the user's update.** Dashboard work
was not independently re-audited in the haptics session. The original criteria
are retained below for reference.

- Audit the current mobile dashboard and propose a compact view in which
  every insight answers a product question or supports a concrete decision.
- Focus on reaching the first accepted rewrite, observed failure stages,
  acceptance by use case/button, and return to meaningful product use.
- Identify measurement gaps before treating missing events as user behavior.
  Adapt the desktop's attempt IDs, terminal outcomes, failure context, and stable
  button-purpose labels where appropriate to mobile's architecture.
- Keep mobile separate from desktop and landing-page traffic; exclude known
  internal/test users and distinguish practice from real use where applicable.
- Use exact rewrite IDs for acceptance, explicit denominators, mature return
  windows, and sample sizes. Separate server latency from user-perceived latency.
- Review the focused replacement before retiring redundant dashboard cards;
  avoid losing useful historical definitions.

Existing constraints still apply: no keystroke collection or analytics SDK/network
activity in the typing path. Ordinary `keyboard_usage_day` data waits for the
container app to reopen and underobserves typing. Server-side `ai_rewrite` measures
successful AI generation, not all attempts or all keyboard use. An unaccepted
result is not, by itself, proof of poor language quality.

## 5. Investigate and improve onboarding

**October 5 implementation follow-up:** the onboarding keyboard-addition screen
now has its own floating enablement video, separate from the Full Access guide.
On October 8, both guides were replaced with actual iOS 26.5 Settings recordings
in Japanese, English, and Simplified Chinese, preserving the existing player and
PiP workflow. The October 9 revision starts both guides at the app's Settings
page. Onboarding shows keyboard enablement and Full Access in one Settings trip,
including the full system warning and Allow confirmation; the recovery guide
shows only Full Access. Written instructions and all three translations match.
Automatic onboarding continuation requires both permissions; keyboard-only
return explains the remaining step, with Skip/manual continuation still available.
Added step-entry/exit outcomes, setup-guide/detection signals,
metadata-only AI attempt/failure/result/replacement diagnostics, generation
lineage, explicit vs automatic result-close reasons, and optional structured
usefulness feedback. App Group relay preserves occurrence time and captured
identity; the keyboard has no analytics SDK or new telemetry network requests.
The unsigned build, 59 focused iOS tests and 13 backend tests passed. Device
acceptance, app release, isolated backend deployment and next-cohort conversion
measurement remain open. Next priority is signup → first live generation, with
permission/consent readiness and a clear transition out of the demo. See the
[implementation and tracking contract](activation-tracking/README.md) for exact
definitions, release isolation and remaining blind spots.

- [ ] Walk through fresh install, keyboard enablement/switching, Full Access,
  practice, authentication, and the first real accepted rewrite on device.
- [ ] Use the funnel and practice diagnostics to identify where users get stuck
  or leave; distinguish detection failures from confusion and deliberate skips.
- [ ] Prioritize the largest supported bottleneck, improve it, and measure the
  next cohort before expanding the redesign.
- [ ] Connect onboarding success to later useful activity, not just completion
  of screens or a guaranteed practice result.

## 6. Use quantitative learning throughout subsequent sessions

- [ ] Identify which users come back and which do not, segmented by observed
  use case, first successful experience, failures, input style, or version when
  those properties are available and sample sizes are sufficient.
- [ ] Determine what people use the keyboard's AI for, which outputs they accept,
  and which early behaviors are associated with later return.
- [ ] Separate fewer incoming users from worse activation or retention. Treat
  correlations as hypotheses about why users leave, then test those hypotheses.
- [ ] For each change, record the question, baseline, expected outcome, validation,
  and observed result here or in a linked investigation. Mark an item complete
  only after checking the real user workflow and state any remaining uncertainty.

## Starting evidence

The October 5 PostHog review used project **465060**, Japan time, and the configured
internal/test exclusion. September 5–October 4 had 346 AI users, 2,589 generated
rewrites, and 1,269 accepted results (49.0%, matched by rewrite ID). The polite
command had 438 acceptances from 1,161 results (37.7%); this makes it an evaluation
priority, not proof of a prompt defect. There were 35 recorded replacement failures
affecting 26 users. These are historical baselines; rerun the relevant query when
starting an implementation session.

References: [mobile PostHog](https://us.posthog.com/project/465060),
[existing KPI dashboard](https://us.posthog.com/project/465060/dashboard/1887280),
and [desktop guidance](../../../../laptop/AGENTS.md), particularly §6–7 on output
quality and measuring the complete rewrite workflow.
