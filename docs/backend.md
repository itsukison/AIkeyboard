# Backend — `keyboard-rewrite` Edge Function

Last verified against `supabase/functions/keyboard-rewrite/index.ts` on
2026-06-07.

## Endpoint

```
POST https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite
```

Project ref `eercsucvxnszqletxued`, region `ap-northeast-1`. The legacy
project ref `wsttwofhxbcgfpwvxazj` mentioned in old docs is **not** ours.

## Auth

Supabase JWT auth (NOT the old shared-token scheme).

```
Authorization: Bearer <Supabase user access token>
apikey: <Supabase publishable key>
Content-Type: application/json
```

The Edge Function pulls `sub` out of the JWT for per-user quota keying.
`verify_jwt = true` in the function config so Supabase's gateway validates
the token before invocation — the function itself just decodes the
claim, it does not re-verify.

Token lifecycle:

1. Container app signs the user in via Supabase auth (email, OAuth, etc).
2. Session tokens are cached in App Group via `AIAuthStore.writeTokens(...)`.
3. Keyboard extension reads tokens via `AIAuthStore.readAccessToken()`. If
   the access token is within 30 s of expiry, the keyboard calls
   `auth/v1/token?grant_type=refresh_token` directly to refresh, and writes
   the new tokens back to the App Group.

## Request

```json
{
  "prompt": "ビジネスで通用する自然な敬語に書き直してください。",
  "text": "今日はとてもいい天気ですね",
  "commandKey": "polite",
  "title": "敬語",
  "locale": "ja-JP",
  "appVersion": "0.1.0",
  "candidateCount": 3,
  "refinement": null
}
```

- `prompt` (required): instruction string from the user-configured
  `UserPrompt.prompt`. Max 1000 chars.
- `text` (required): the captured input. Max 2000 chars by default
  (`MAX_REWRITE_CHARS`).
- `commandKey` (optional): builtin key like `polite` / `natural` /
  `email` / `translateToEnglish`, or nil for user-defined prompts. Used
  only for logging.
- `title` (optional): display title of the prompt, logging only.
- `locale` (optional): defaults to `ja-JP`. Set to `en-US` for the English
  translation built-in.
- `candidateCount` (optional): 1–5, defaults to 3. The function asks the
  model for exactly this many distinct rewrites.
- `refinement` (optional): one of `morePolite` / `moreDetailed` /
  `moreConcise`. When set, the `text` is treated as a previous rewrite to
  be further refined, not the original.

## Response

```json
{
  "candidates": [
    { "replacement": "本日は大変良い天気ですね。", "changed": true },
    { "replacement": "今日は素晴らしい天気でございますね。", "changed": true },
    { "replacement": "本日はとても良い天気ですね。", "changed": true }
  ],
  "language": "ja"
}
```

`language` is one of `ja` / `en` / `ko` / `zh` / `mixed`.

## Errors

```json
{ "error": { "code": "rate_limited", "message": "Daily rewrite limit reached." } }
```

| Code | HTTP | When |
|---|---|---|
| `method_not_allowed` | 405 | Anything other than POST/OPTIONS |
| `unauthorized` | 401 | Missing/invalid JWT |
| `invalid_json` | 400 | Body is not JSON |
| `invalid_request` | 400 | Missing `prompt` or `text`, unsupported refinement |
| `prompt_too_long` | 413 | `prompt` exceeds `MAX_PROMPT_CHARS` (1000) |
| `text_too_long` | 413 | `text` exceeds `MAX_REWRITE_CHARS` (2000 default) |
| `rate_limited` | 429 | Per-user daily quota exhausted |
| `configuration_missing` | 503 | `GROQ_API_KEY` is unset |
| `provider_error` | 502 | Groq returned non-OK or invalid JSON |

## Provider

Groq Chat Completions (`https://api.groq.com/openai/v1/chat/completions`)
with `response_format = json_schema` (strict). Default model
`openai/gpt-oss-120b`.

Alternatives (override `GROQ_MODEL`):

- `llama-3.3-70b-versatile` — conservative, ~275 tok/s, JSON schema strict
- `moonshotai/kimi-k2-instruct` — best Japanese quality, ~200 tok/s
- `llama-3.1-8b-instant` — fastest, ~750 tok/s, only `json_object` mode

The prompt is built in `userPrompt()` and `systemInstructions()` inside
`index.ts`. Refinement intents map to one-line tone instructions in
`refinementInstruction()`.

## Secrets

Set in Supabase Dashboard → Project Settings → Edge Functions → Secrets.

| Key | Required | Default |
|---|---|---|
| `GROQ_API_KEY` | yes | — |
| `GROQ_MODEL` | no | `openai/gpt-oss-120b` |
| `GROQ_TIMEOUT_MS` | no | `8000` |
| `GROQ_MAX_OUTPUT_TOKENS` | no | `600` (per candidate; total = value × candidateCount) |
| `GROQ_REASONING_EFFORT` | no | unset. Only valid for `openai/gpt-oss-*` models (values: `low` / `medium` / `high`). Leave unset for Llama / Kimi. |
| `MAX_REWRITE_CHARS` | no | `2000` |
| `DAILY_REWRITE_LIMIT` | no | `50` |

`GROQ_API_KEY` must never be put in the iOS app. The keyboard only knows
the Supabase URL and publishable key.

## Privacy

- Raw input/output is never logged.
- Logs include only: provider, command key, refinement, candidate count,
  input/prompt/output character lengths, latency, status.
- The iOS keyboard sends text only when the user taps an AI command —
  never per keystroke.

## Deploy

```bash
cd supabase
supabase functions deploy keyboard-rewrite
```

## Verify

```bash
# CORS preflight
curl -i -X OPTIONS \
  https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite

# Unauthenticated → 401
curl -i -X POST \
  https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"テスト","text":"これはテストです"}'

# Authenticated → 200
curl -i -X POST \
  https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <user JWT>' \
  -H 'apikey: <publishable key>' \
  -d '{"prompt":"丁寧に書き直して","text":"今日はいい天気ですね","candidateCount":3}'
```

## Known limitations (block public launch)

- **In-memory daily quota**: the `dailyUsage` `Map<string, number>` is
  per-warm-runtime. A cold start resets it; multiple warm instances each
  hold their own. Acceptable for TestFlight, not for public launch.
  Replace with a Postgres table keyed on `(user_id, day)`.
- **No abuse logging beyond Edge Function console logs.** Wire to
  Sentry / Logflare before launch.
- **No model-level rate limit handling** — Groq 429s become
  `provider_error` to the client. Add Retry-After parsing if it becomes
  user-visible.

## Rollback

If a Groq deploy goes bad, the previous OpenAI Responses API (`gpt-5.1`)
implementation is recoverable from git history. Find the commit before
the Groq switch (around 2026-06-06) with:

```bash
git log --oneline -- supabase/functions/keyboard-rewrite/index.ts
git show <commit>:supabase/functions/keyboard-rewrite/index.ts > /tmp/openai.ts
```

Re-set `OPENAI_API_KEY` (and optionally `OPENAI_MODEL`,
`OPENAI_TIMEOUT_MS`, `OPENAI_MAX_OUTPUT_TOKENS`,
`OPENAI_REASONING_EFFORT`) in Supabase secrets, then deploy.
