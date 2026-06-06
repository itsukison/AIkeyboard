# keyboard-rewrite

Supabase Edge Function for AIキーボード rewrite.

Endpoint:

```text
POST https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite
```

Required headers:

```text
Content-Type: application/json
X-AI-Keyboard-Client-Token: <AI_KEYBOARD_REWRITE_TOKEN>
X-AI-Keyboard-Device-Id: <stable anonymous device id>
```

Request:

```json
{
  "command": "proofread",
  "text": "今日はとてもいい天気ですね",
  "locale": "ja-JP",
  "appVersion": "1.0.0"
}
```

Response:

```json
{
  "replacement": "今日はとてもいい天気ですね。",
  "language": "ja",
  "changed": true
}
```

Secrets:

- `OPENAI_API_KEY`: required.
- `AI_KEYBOARD_REWRITE_TOKEN`: required shared client token for early/TestFlight builds.
- `OPENAI_MODEL`: optional in docs; current deployed function uses `gpt-5.1`.
- `OPENAI_REASONING_EFFORT`: optional, defaults to `low`.
- `OPENAI_TIMEOUT_MS`: optional, defaults to `12000`.
- `OPENAI_MAX_OUTPUT_TOKENS`: optional, defaults to `800`.
- `MAX_REWRITE_CHARS`: optional, defaults to `2000`.
- `DAILY_REWRITE_LIMIT`: optional, defaults to `50`.

Privacy:

- The function does not log raw input or output text.
- Logs include command, input/output lengths, changed flag, latency, and status.
- The iOS keyboard should call this endpoint only after the user taps an AI command.
