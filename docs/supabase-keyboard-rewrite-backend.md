# Supabase Keyboard Rewrite Backend

Date: 2026-06-06

Supabase project:

- Project: AIキーボード backend project
- Project ref: `eercsucvxnszqletxued`
- Region: `ap-northeast-1`

Edge Function:

```text
keyboard-rewrite
https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite
```

Deployment status:

- Deployed as Supabase Edge Function `keyboard-rewrite`, verified live on 2026-06-06.
- `verify_jwt = false` intentionally, because the first TestFlight backend uses custom shared-token auth.
- The function itself rejects requests unless `X-AI-Keyboard-Client-Token` matches `AI_KEYBOARD_REWRITE_TOKEN`.

## Request

```http
POST /functions/v1/keyboard-rewrite
Content-Type: application/json
X-AI-Keyboard-Client-Token: <shared token>
X-AI-Keyboard-Device-Id: <anonymous stable device id>
```

```json
{
  "command": "proofread",
  "text": "今日はとてもいい天気ですね",
  "locale": "ja-JP",
  "appVersion": "1.0.0"
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
  "replacement": "今日はとてもいい天気ですね。",
  "language": "ja",
  "changed": true
}
```

Error shape:

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Invalid rewrite token."
  }
}
```

## Required Secrets

Set these in Supabase Dashboard > Project Settings > Edge Functions > Secrets:

```text
OPENAI_API_KEY=<OpenAI API key>
AI_KEYBOARD_REWRITE_TOKEN=<random shared client token for TestFlight>
```

Recommended optional secrets:

```text
OPENAI_MODEL=gpt-5.1
OPENAI_TIMEOUT_MS=12000
OPENAI_MAX_OUTPUT_TOKENS=800
MAX_REWRITE_CHARS=2000
DAILY_REWRITE_LIMIT=50
```

Current backend uses `gpt-5.1` by default and `reasoning.effort = low` for the first verified backend pass.

Do not put `OPENAI_API_KEY` in the iOS app. The app only needs:

- Supabase function URL
- `AI_KEYBOARD_REWRITE_TOKEN` for early TestFlight builds
- anonymous device id for rate-limit bucketing

## Verification

CORS preflight:

```bash
curl -i -X OPTIONS \
  https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite
```

Expected: `200 ok`.

Unauthenticated request:

```bash
curl -i -X POST \
  https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite \
  -H 'Content-Type: application/json' \
  -d '{"command":"proofread","text":"これはテストです","locale":"ja-JP","appVersion":"dev"}'
```

Expected: `401 unauthorized`.

Authenticated request after secrets are set:

```bash
curl -i -X POST \
  https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite \
  -H 'Content-Type: application/json' \
  -H 'X-AI-Keyboard-Client-Token: <AI_KEYBOARD_REWRITE_TOKEN>' \
  -H 'X-AI-Keyboard-Device-Id: test-device' \
  -d '{"command":"proofread","text":"これはテストです","locale":"ja-JP","appVersion":"dev"}'
```

Expected: `200` with `replacement`, `language`, and `changed`.

Verified live response on 2026-06-06:

```json
{
  "replacement": "これはテストです。",
  "language": "ja",
  "changed": true
}
```

## Privacy Behavior

- Raw input and output text are not logged.
- Logs include only command, input/output length, changed flag, latency, and status.
- The iOS keyboard should call this endpoint only after the user taps an AI command.

## Known First-Cut Limitation

The current daily quota is an in-memory Edge Function guard. It blocks bursts in a warm runtime but is not a durable global quota. Before public launch, replace it with a database-backed quota keyed by hashed anonymous device id or authenticated user id.

## iOS Client Notes

For the first TestFlight implementation, the keyboard extension should call:

```text
POST https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite
```

Headers:

```text
Content-Type: application/json
X-AI-Keyboard-Client-Token: <AI_KEYBOARD_REWRITE_TOKEN>
X-AI-Keyboard-Device-Id: <anonymous stable device id>
```

The iOS app should not use the old `wsttwofhxbcgfpwvxazj` project. That was a reference/legacy project and is not AIキーボード's backend.
