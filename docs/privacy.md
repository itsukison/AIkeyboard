# Privacy

This document is the authoritative source for the App Store Privacy
Nutrition Label and for in-app/website privacy copy. If product copy
contradicts this file, fix the copy.

Last verified against code: 2026-06-07.

## Promise to the user

Plain Japanese, for in-app copy:

> AIキーボードは、あなたがAIボタンをタップした時だけテキストを送信します。
> 通常の日本語入力でキーストロークが送信されることはありません。
> Cloud AIを使うにはiOSの「フルアクセスを許可」が必要です。
> フルアクセスをオフにしても、通常のキーボードはそのまま使えます。

Plain English (for App Store copy / web):

> AIキーボード sends text only when you tap an AI command. Normal typing
> is never sent to the network. Cloud AI requires the iOS "Allow Full
> Access" permission, because iOS blocks all network access for
> third-party keyboards without it. The base Japanese keyboard works
> without Full Access.

## What is sent, when, and to whom

| Trigger | Sent | Destination | Logged |
|---|---|---|---|
| Tapping any AI prompt | Captured input text + prompt string + locale + app version | Supabase Edge Function (`keyboard-rewrite`) | Lengths, command key, latency, status — **not the raw text** |
| Token refresh | Refresh token | Supabase Auth (`/auth/v1/token`) | Standard Supabase auth log |
| Anything else | Nothing | — | — |

The Supabase Edge Function calls **Groq** to perform the rewrite. The
captured input text is included in the LLM request payload. Groq's data
handling is governed by Groq's enterprise terms.

## What is *never* sent

- Per-keystroke logging — the extension has no such code path.
- Pasteboard content — the extension does not read the pasteboard in v1.
- Conversion learning data — stored in the App Group only, never
  transmitted.
- Anonymized device identifier without a user-initiated request.

## What is stored on the device

App Group (`group.co.gastroduce-japan.bikey.japanese`), in
`UserDefaults`:

- Keyboard settings (style, haptics, Cloud AI toggle)
- User-defined AI prompts (`userPromptEntries`)
- Conversion learning data (`conversionPreferenceEntries`)
- Supabase auth tokens (`aiAccessToken`, `aiRefreshToken`,
  `aiTokenExpiresAt`)
- An anonymous device UUID (`anonymousDeviceId`) generated on first run

Everything is read/written by both the container app and the keyboard
extension via the App Group. There is no shared keychain in v1.

## What is stored on the backend

Supabase Postgres tables (manage in the Supabase dashboard):

- `auth.users` — standard Supabase Auth records for signed-in users.
- No raw rewrite text. Edge Function logs include only:
  - `userId` (Supabase auth `sub`)
  - `commandKey`, `refinement`
  - `inputLength`, `promptLength`, `outputLength` (character counts)
  - `latencyMs`, `status`

Raw input/output text is **not persisted** on the backend. It is sent to
Groq for one inference call and then dropped.

## Apple App Store Privacy Nutrition Label

Use these answers when filling out App Store Connect's privacy
questionnaire.

### Data linked to user

| Type | Used for | Optional / required |
|---|---|---|
| Email address | Auth (sign in) | Required for Cloud AI |
| User ID (Supabase `sub`) | Auth + quota | Required for Cloud AI |

### Data not linked to user

| Type | Used for |
|---|---|
| Diagnostics — performance | latencyMs in Edge Function logs |
| Usage — product interaction | commandKey, inputLength buckets |

### Data not collected

- Contacts, location, browsing history, search history, financial info,
  health/fitness, sensitive info, contact info beyond email.

### Tracking

The app does **not** track users across apps and websites owned by
other companies. No `AppTrackingTransparency` prompt is required.

## Permissions surfaced to the user

| Permission | When asked | What we do with it |
|---|---|---|
| Allow Full Access (keyboard) | Container app onboarding, when user enables Cloud AI | Required by iOS for any keyboard network access. We use it solely to call `keyboard-rewrite`. |

No other iOS permissions are requested.

## Auditing in code

If a future change adds a new network call from the extension or a new
piece of stored data, update the tables above before merging. Reviewers
should reject PRs that add new outbound calls without a corresponding
privacy update.

Concrete grep checks for self-audit:

```bash
# Any URLSession in the extension target should only hit
# keyboard-rewrite or auth/v1/token.
grep -rn 'URLSession\|URLRequest\|URL(string' \
  iOS/KeyboardExtension Sources/JapaneseKeyboardAI

# Pasteboard reads — should return nothing for v1.
grep -rn 'UIPasteboard' iOS/KeyboardExtension Sources

# App Group keys — should be a closed set defined in
# KeyboardSettingsStore.swift.
grep -rn 'forKey:' Sources/KeyboardPreferences
```
