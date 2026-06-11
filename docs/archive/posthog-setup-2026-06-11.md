<wizard-report>
# PostHog post-wizard report

The wizard has completed a PostHog integration for the Keigo Button iOS app (container target only — the keyboard extension deliberately has no network access per project guidelines).

## What changed

**New files:**
- `.env` — PostHog environment variable values for reference/CI

**Modified files:**
- `iOS/Container/App.swift` — added `PostHogEnv` enum and `PostHogSDK.shared.setup(config)` in `KeigoButtonApp.init()`
- `iOS/Container/UserSession.swift` — added `identify()` on sign-up/sign-in, `capture()` for auth lifecycle events, `reset()` on sign-out and account deletion
- `iOS/Container/AuthScreens.swift` — added `capture("sign_up_error")` and `capture("sign_in_error")` in the catch blocks
- `iOS/Container/OnboardingFlow.swift` — added `capture("onboarding_source_selected")` and `capture("onboarding_completed")` when the user finishes onboarding
- `iOS/Container/PromptsScreen.swift` — added `capture("prompt_created")`, `capture("prompt_updated")`, `capture("prompt_deleted")`
- `iOS/Container/HomeScreen.swift` — added `capture("demo_opened")` via `.onChange(of: showDemo)`
- `KeigoButton.xcodeproj/project.pbxproj` — added `posthog-ios` (v3.59.3) as a remote Swift Package dependency on the `KeigoButton` target only
- `KeigoButton.xcodeproj/xcshareddata/xcschemes/KeigoButton.xcscheme` — added `POSTHOG_PROJECT_TOKEN` and `POSTHOG_HOST` to the Run scheme environment variables

## Events instrumented

| Event | Description | File |
|-------|-------------|------|
| `signed_up` | User successfully created a new account | `iOS/Container/UserSession.swift` |
| `signed_in` | User successfully signed in with email and password | `iOS/Container/UserSession.swift` |
| `signed_out` | User confirmed sign-out from the profile screen | `iOS/Container/UserSession.swift` |
| `account_deleted` | User's account was successfully deleted | `iOS/Container/UserSession.swift` |
| `sign_up_error` | Sign-up submission failed; includes `error_message` | `iOS/Container/AuthScreens.swift` |
| `sign_in_error` | Sign-in submission failed; includes `error_message` | `iOS/Container/AuthScreens.swift` |
| `onboarding_source_selected` | User selected how they discovered the app; includes `source` | `iOS/Container/OnboardingFlow.swift` |
| `onboarding_completed` | User finished the onboarding flow | `iOS/Container/OnboardingFlow.swift` |
| `prompt_created` | User saved a new custom sub-prompt | `iOS/Container/PromptsScreen.swift` |
| `prompt_updated` | User edited and saved an existing prompt; includes `is_builtin` | `iOS/Container/PromptsScreen.swift` |
| `prompt_deleted` | User deleted a custom prompt | `iOS/Container/PromptsScreen.swift` |
| `demo_opened` | User tapped 'Try it' on the home screen hero card | `iOS/Container/HomeScreen.swift` |

## Next steps

We've built some insights and a dashboard for you to keep an eye on user behavior, based on the events we just instrumented:

- [Analytics basics (wizard) — Dashboard](https://us.posthog.com/project/465060/dashboard/1697210)
- [New sign-ups](https://us.posthog.com/project/465060/insights/Jym7SY2s) — Daily unique users who signed up (last 30 days)
- [Auth errors](https://us.posthog.com/project/465060/insights/xIFz2ICH) — Sign-up and sign-in error counts over time
- [Onboarding conversion rate](https://us.posthog.com/project/465060/insights/1WTTypCd) — Percentage of sign-ups who complete onboarding (formula: onboarding_completed / signed_up × 100)
- [Prompt activity](https://us.posthog.com/project/465060/insights/8sqM0amv) — Prompt create/update/delete actions over time
- [Discovery channels](https://us.posthog.com/project/465060/insights/qkE0bc9Y) — How users found the app, broken down by `source` (last 90 days)

### Agent skill

We've left an agent skill folder in your project at `.claude/skills/integration-swift/`. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.

</wizard-report>
