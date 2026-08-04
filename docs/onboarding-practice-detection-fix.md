# Onboarding practice pages — unresponsive detection (2026-08-04)

Users could get permanently stuck on the guided practice pages: they switched
keyboards or typed, and the page never reacted. Severe on iOS 26, intermittent
on iOS 16.

## Root cause

Every completion proof was an **edge-triggered event crossing the process
boundary**, with no state check and no retry.

`didOpenKeyboard` had exactly two proofs, and both required a *fresh*
`viewWillAppear` in the extension after the page opened:

- `onboardingPracticeKeyboardSeenAt` — written once per keyboard appearance
- `KeyboardUsageDailyStore` open-count delta — same single moment

So a user already on 敬語ボタン when the page opened produced no evidence at
all, and nothing they did afterwards re-evaluated it. Arming practice mode was
also a race: the container armed it ~450 ms before the field focused, and an
extension that appeared before that write was visible in its process skipped its
signals for the whole presentation — made frequent by disarming on every
non-practice page. The local fallback (`text.count >= 3`) is defeated by kana
composition, which never reaches the SwiftUI binding.

## Changes

| # | Change | Where |
|---|---|---|
| 1 | Timeout unlock (20 s / 35 s / 45 s) opens the CTA no matter what, plus a quieter hint line under the preserved instruction, plus `onboarding_practice_stalled` telemetry carrying the sub-signals | `InteractiveOnboardingFlow.swift` |
| 2 | `KeyboardStatusContext.isKeyboardActive` is now the primary switch proof — a state, not an event. Probed on a slow cadence, stops once detected or timed out (per-tick publishes corrupt marked text) | `InteractiveOnboardingFlow.swift` |
| 3 | Practice stays armed for the whole keyboard section (pages 1–8) instead of per exercise page — removes the arm/appear race | `configurePractice` |
| 4 | Extension re-stamps `KeyboardSeenAt` from `textDidChange`/`selectionDidChange`, not only on appearance. Throttled on the *check* (2 s) so non-onboarding users don't pay an App Group read per keystroke. Signal window widened to 30 s | `KeyboardViewController.swift` |
| 5 | Accepting a candidate moved from `.onTapGesture` to the verified raw-touch surface (iOS 26 drops SwiftUI taps on hosted cells). Copy fixed: the page said press 「置き換え」, which does not exist — the gesture is tapping the centred card | `SnapCarousel.swift`, `InteractiveOnboardingFlow.swift` |
| 6 | `en` + `zh-Hans` for the three new/changed strings (Xcode had added empty stubs, so non-JP users saw raw Japanese) | `Localizable.xcstrings` |
| 7 | Reply-pill latch fix — see below | `AIKeyboardController.swift` |

### 7. Reply pill (separate bug, affects daily use)

`promoteReplyIfFreshCopy` consumed the pasteboard `changeCount` *before*
deciding whether the pill could show. A `hasStrings == false` at that instant —
a cold-launching extension can see the new count before the item is readable —
left the pill hidden **and** the count marked seen, so every later 0.6 s poll
returned early. Only a second copy could recover it.

Now the count is consumed only once `hasStrings` is true; otherwise the monitor
retries. Side effect (matches the existing stated intent): a fresh non-string
copy no longer hides an already-shown pill.

**Follow-up (2026-08-04, later):** consuming the count at first sight was still
fragile — iOS can deliver more than one appearance callback per presentation,
and the re-run reset `replyAvailable` and then found the count already seen. Net
effect: copy first, focus a field second → no pill; only copying again with the
keyboard already up worked. Detection is now pure (`promoteReplyIfFreshCopy`
never writes the stored count); the count is marked seen only in
`markClipboardSeenOnDisappear`, called from `viewWillDisappear`. Any number of
appear-refreshes or polls now compute the same answer, and the pill session ends
when the keyboard goes away.

## Regression fix (2026-08-04, same day)

The widened accepted-signal window over-corrected: the rewrite and reply pages
share one App Group key (`onboardingPracticeAcceptedAt`), practice now stays
armed across the section (change 3) so nothing clears it between pages, and the
30 s *backward* window meant the rewrite page's acceptance completed the reply
page on its first poll — checkmark shown before the user copied anything.

Fix: each practice page clears the accepted-at key in `onAppear`, and the
comparison is forward-only (`acceptedAt > pageOpenedAt`; same-device clock, so
no skew to tolerate). The 30 s backward window survives only where it is
intentional: the switch page's seen/typed signals, where "already on our
keyboard" should count.

## Verified on iOS 26.4 simulator

- Timeout unlock fires; hint renders; English translation renders
- `isKeyboardEnabled` (KeyboardKit's private-KVC input-mode read) **still works
  on iOS 26.4** — disproves the theory that page 7 could stick in a
  「設定を開く」 loop from a false `needsKeyboard`
- Practice arming is visible cross-process
- Pages 6 and 7 confirmed working in a manual run

**Not verified**: `isKeyboardActive == true` while our keyboard is displayed, and
the reply-pill fix. Both need a tap the tooling can't synthesise (no assistive
access); the reply page additionally needs the Full Access grant, which a
reinstall clears.

## Simulator testbed

`scripts/sim-keyboard-testbed.sh <udid> [page]` installs the app, enables the
keyboard without walking Settings (`.GlobalPreferences AppleKeyboards`), forces
the software keyboard on, and parks the app on a chosen onboarding page.

Note: `ConnectHardwareKeyboard` in `com.apple.iphonesimulator` **does nothing**
on Xcode 26. The hardware-keyboard attachment is CoreSimulator device runtime
state, set via `-setHardwareKeyboardEnabled:keyboardType:error:`; the script
compiles a small helper that calls it.

One gesture stays manual: long-press the globe → choose 敬語ボタン. iOS keeps
the selected input mode in state that isn't writable from outside.

## Open items

- Two DEBUG probes still in the code: `🔎 [switch-probe]` (page 6) and
  `📋 [reply-pill]`. Remove once the two unverified items above are confirmed.
- Page 8's Full Access check reads a value only the extension writes, so right
  after a fresh install it claims Full Access is missing until the keyboard has
  appeared once. The timeout covers the dead end; the message is still wrong.
- The raw-touch tap surface now exists in three private copies
  (`CandidateTapSurface`, `KeyboardToolbarTapSurface`, `CandidateCardTapSurface`).
  Worth hoisting into one shared type if a fourth appears.
- Two superseded xcstrings keys are now orphaned; Xcode will mark them stale.
- Optional: drive the practice reply pill from a container-written "just copied"
  App Group signal instead of the pasteboard, so the exercise needs no Full
  Access. Trade-off: the pill would no longer be driven by the real clipboard
  during onboarding.
