# Change Audit - 2026-06-26

Current branch: `feat/reply-to-message`

Note: this audit was written before splitting the working tree into commits.
The changes were then committed as:
- `cc41f87 feat: add flick keyboard and typing feedback`
- `1566d93 feat: update keyboard settings and reply onboarding`
- `9b50b70 docs: document deferred paste control path`
- `92917c7 chore: bump version to 1.0.5 build 8`

Base state:
- `main` / `origin/main` are at `85429e5` (`chore: bump version to 1.0.4 (build 6) for App Store release`).
- This branch has one local commit on top of `main`: `f176c2a feat: AI reply-to-message via clipboard + system paste control`.
- The branch is not configured to track a remote branch.
- There are no staged changes.

## Already Committed

`f176c2a` adds the reply-to-message AI flow:
- Captures reply context from copied text.
- Sends `replyTo` through the rewrite request/backend.
- Adds default reply prompt data.
- Adds keyboard toolbar reply affordance.
- Adds AI and replacement tests.
- Updates backend and AI rewrite docs.

## Uncommitted Code Changes

### 1. Flick / 10-key Japanese input mode

Primary files:
- `Sources/JapaneseKeyboardCore/FlickKanaTable.swift`
- `Sources/JapaneseKeyboardCore/InputBuffer.swift`
- `Sources/JapaneseKeyboardCore/KanaInputBuffer.swift`
- `Sources/JapaneseKeyboardUI/Flick/*`
- `Sources/KeyboardPreferences/KeyboardSettingsStore.swift`
- `iOS/KeyboardExtension/KeyboardViewController.swift`
- `iOS/Container/ProfileScreen.swift`
- `Tests/JapaneseKeyboardCoreTests/*Kana*Tests.swift`

What changed:
- Adds `KeyboardStyle.japaneseFlick`.
- Adds a direct kana buffer and shared `InputBuffer` abstraction.
- Adds flick mapping data for kana keys, kogaki/dakuten toggle, punctuation, and wa/ya special mappings.
- Adds a SwiftUI 10-key flick keyboard view with custom touch-down/move/up gesture handling.
- Adds a profile screen picker for romaji vs flick input.
- Adds core tests for flick tables, kana input buffer, and `InputManager` kana composition.

Risk / cleanup before commit:
- `KeyboardViewController.configureInputManager()` currently returns early when the stored style equals the cached style. Because `keyboardStyle` is initialized from storage, opening directly in flick mode can keep the default romaji `InputManager`.
- `switchKeyboardStyle(_:)` writes `keyboardStyle = style` before calling `configureInputManager()`, so runtime switching may also skip rebuilding the manager.
- `AIKeyboardController` stores the `InputManager` passed at init. If the keyboard style changes after the AI controller is initialized, AI flush/reset checks can point at the old manager.

### 2. Button haptics

Primary files:
- `iOS/KeyboardExtension/KeyboardViewController.swift`
- `iOS/KeyboardExtension/JapaneseActionHandler.swift`
- `Sources/JapaneseKeyboardUI/Common/CandidateBar.swift`
- `Sources/JapaneseKeyboardUI/Qwerty/QwertyKeyboardView.swift`
- `iOS/KeyboardExtension/AI/AIKeyboardToolbarView.swift`
- `iOS/KeyboardExtension/AI/AIResultOverlayView.swift`
- `iOS/KeyboardExtension/AI/SnapCarousel.swift`
- `iOS/Container/ProfileScreen.swift`
- `iOS/Container/RootContainerView.swift`

What changed:
- Adds a local `KeyboardHapticFeedback` wrapper in the extension.
- Fires key haptics manually from `JapaneseActionHandler` and custom SwiftUI keyboard controls.
- Moves carousel selection haptics out of `SnapCarousel` into the controller-provided callback.
- Gates haptics behind the app setting and Full Access.
- Adds a container modal when enabling haptics without Full Access.

Risk / cleanup before commit:
- Needs real-device feel check. Simulator build cannot validate haptic quality.
- Watch for duplicate haptics on KeyboardKit-managed keys, since the manual trigger runs on `.press` / `.repeatPress`.

### 3. iPad / container UI and onboarding updates

Primary files:
- `iOS/Container/ProfileScreen.swift`
- `iOS/Container/AboutScreen.swift`
- `iOS/Container/RootContainerView.swift`
- `iOS/Container/KeyboardOnboardingPages.swift`
- `iOS/Container/OnboardingFlow.swift`

What changed:
- Adds keyboard input method settings UI.
- Adds reply feature onboarding page.
- Adds reply feature announcement sheet for existing users.
- Changes About/Profile Full Access status to use `KeyboardStatusContext`.
- Adjusts tab bar glass/animation behavior.

Risk / cleanup before commit:
- Verify first-run behavior: new users should not also see the existing-user reply feature sheet after onboarding.
- The UI compiles, but should be checked on small iPhone and iPad layouts.

### 4. Next-word prediction after commit

Primary files:
- `Sources/JapaneseKeyboardCore/InputManager.swift`
- `Sources/JapaneseKeyboardCore/KanaKanjiAdapter.swift`
- `Sources/JapaneseKeyboardUI/Common/CandidateBar.swift`
- `iOS/KeyboardExtension/KeyboardViewController.swift`

What changed:
- Enables AzooKey Japanese prediction / typo correction options.
- Stores the last conversion result so post-composition prediction can use rich AzooKey candidate context.
- Shows prediction suggestions in the candidate bar after committing a candidate/composition.
- Tapping a prediction inserts it directly.

Risk / cleanup before commit:
- This is separate from flick/haptics/iPad UI and should be committed separately or explicitly documented in a combined commit.
- Needs typing-path memory/performance check because `requireJapanesePrediction` and typo correction are now enabled.

### 5. Reply mode follow-up / UIPasteControl rollback documentation

Primary files:
- `iOS/KeyboardExtension/AI/AIKeyboardController.swift`
- `iOS/KeyboardExtension/AI/AIKeyboardToolbarView.swift`
- `docs/ai-rewrite.md`
- `docs/archive/uipastecontrol-research.md`

What changed:
- Replaces the previously committed system `UIPasteControl` toolbar path with a custom `返信` pill that reads `UIPasteboard.general.string`.
- Documents that this triggers the iOS paste permission prompt.
- Adds detailed archived research for future `UIPasteControl` work.

Risk / cleanup before commit:
- This changes the behavior promised by the existing commit message (`system paste control`). Either amend/split the existing commit or make a clear follow-up commit like `fix: use reply pill while paste control is deferred`.

### 6. Native keyboard polish

Primary files:
- `Sources/JapaneseKeyboardUI/Qwerty/QwertyKeyboardView.swift`

What changed:
- Forces inactive shift key background to match system function-key styling.
- Adjusts vertical key insets to better match native iOS key height/gaps.

Risk / cleanup before commit:
- Visual-only, but should be checked in light/dark mode and iPad.

### 7. Version bump

Primary files:
- `iOS/Container/Resources/Info.plist`
- `iOS/KeyboardExtension/Resources/Info.plist`

What changed:
- Bumps version `1.0.4` build `6` to version `1.0.5` build `8`.

Risk / cleanup before commit:
- Commit only if this branch is intended to be the next App Store/TestFlight build. Otherwise keep the bump out until release time.

### 8. Debug/reference assets

Untracked:
- `debug/IMG_51863C6E0D0F-1.jpeg`
- `debug/keigo.jpeg`
- `debug/native.jpeg`
- `截屏 2026-06-25 0.14.55.png`

Recommendation:
- Do not commit these unless they are intentionally moved into `docs/` or `public/` with a clear purpose.

## Verification

Ran:
- `git diff --check`: passed.
- `swift test`: blocked before tests by SwiftPM dependency/platform resolution (`KeyboardKitDependencies` / `LicenseKit` macOS metadata).
- `xcodebuild -project KeigoButton.xcodeproj -scheme KeyboardExtension -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData build CODE_SIGNING_ALLOWED=NO`: passed error filter; only AppIntents metadata warning.
- `xcodebuild -project KeigoButton.xcodeproj -scheme KeigoButton -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData build CODE_SIGNING_ALLOWED=NO`: passed error filter; only AppIntents metadata warning.

## Recommended Commit Plan

Do not make one giant commit.

Suggested order:
1. Fix the `InputManager` lifecycle issue in `KeyboardViewController` and the stale `AIKeyboardController` manager coupling.
2. Commit flick input mode + tests + settings picker.
3. Commit haptics + Full Access gating/modal.
4. Commit next-word prediction after commit.
5. Commit reply-mode follow-up and `UIPasteControl` research docs.
6. Commit container onboarding/reply announcement UI.
7. Commit native keyboard visual polish.
8. Commit version bump only when preparing the build.

Small cleanup before any commit:
- Fix typo in `docs/development.md`: `thatDon` should be removed.
- Keep untracked debug screenshots out of the commit.
