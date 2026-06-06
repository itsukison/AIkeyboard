# AIキーボード Backend Handoff

Date: 2026-06-06

This is the short handoff for the next agent implementing Cloud AI in the iOS keyboard.

## Backend

Use this Supabase project only:

```text
Project ref: eercsucvxnszqletxued
Project URL: https://eercsucvxnszqletxued.supabase.co
Function: keyboard-rewrite
Endpoint: https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite
```

Do not use `wsttwofhxbcgfpwvxazj`; that was a reference/legacy project.

## Auth

The first TestFlight backend uses custom shared-token auth, not Supabase JWT auth.

Required request headers:

```text
Content-Type: application/json
X-AI-Keyboard-Client-Token: <AI_KEYBOARD_REWRITE_TOKEN>
X-AI-Keyboard-Device-Id: <anonymous stable device id>
```

The shared token is stored as the Supabase Edge Function secret:

```text
AI_KEYBOARD_REWRITE_TOKEN
```

Do not store `OPENAI_API_KEY` in the iOS app. It exists only as a Supabase Edge Function secret.

## Request

```json
{
  "command": "proofread",
  "text": "これはテストです",
  "locale": "ja-JP",
  "appVersion": "dev"
}
```

Commands:

- `proofread`
- `natural`
- `polite`
- `concise`
- `translateToEnglish`
- `translateToJapanese`

## Response

```json
{
  "replacement": "これはテストです。",
  "language": "ja",
  "changed": true
}
```

Error:

```json
{
  "error": {
    "code": "provider_error",
    "message": "Rewrite provider failed."
  }
}
```

## Verified

Live test passed on 2026-06-06:

```bash
curl -i -X POST \
  https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite \
  -H 'Content-Type: application/json' \
  -H 'X-AI-Keyboard-Client-Token: <token>' \
  -H 'X-AI-Keyboard-Device-Id: test-device' \
  -d '{"command":"proofread","text":"これはテストです","locale":"ja-JP","appVersion":"dev"}'
```

Returned:

```json
{
  "replacement": "これはテストです。",
  "language": "ja",
  "changed": true
}
```

## iOS Implementation Steps

1. Add `CloudRewriteService` in the keyboard extension.
2. Gate cloud calls behind Full Access and the user's Cloud AI setting.
3. Capture whole available input text with `UITextDocumentProxy`.
4. Send the captured whole input to `keyboard-rewrite`.
5. Show the result card.
6. On Replace, validate context, move cursor to the end of the captured input, delete the captured input, and insert `replacement`.
7. Never send text while typing. Send text only after the user taps an AI command.

## Current Backend Limitations

- Daily quota is in-memory per warm Edge Function runtime. Replace with database-backed quota before public launch.
- Shared token auth is acceptable for early TestFlight only. Replace with real auth/device attestation or authenticated sessions before public release.
- Current deployed model is `gpt-5.1` with low reasoning effort.
