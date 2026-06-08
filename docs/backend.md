# Backend — `keyboard-rewrite` Edge Function

Last verified against `supabase/functions/keyboard-rewrite/index.ts` on
2026-06-08.

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
  "language": "ja",
  "eventId": "8f6c2a30-1b9c-4d20-a9f6-c2e62d3b9a01"
}
```

`language` is one of `ja` / `en` / `ko` / `zh` / `mixed`.

`eventId` is the primary key of the row inserted into `public.ai_rewrite_events`
for this rewrite. It is `null` if event logging is disabled
(`EVENT_LOGGING_ENABLED=false`) or the insert failed. The client may send it
back later through a feedback endpoint to record which candidate the user
selected. Unknown fields on this response are safe to ignore — old clients
that do not decode `eventId` keep working.

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
| `rate_limited` | 429 | Per-user or global abuse guard tripped |
| `configuration_missing` | 503 | No provider key is configured |
| `content_blocked` | 422 | Provider blocked the content for safety/policy reasons |
| `provider_rate_limited` | 429 | Provider returned a model/API rate limit |
| `provider_error` | 502 | Provider returned non-OK, timed out, or returned invalid JSON |

## Provider

Provider selection is server-side only. The iOS app still calls only the
Supabase Edge Function.

Default order:

1. Cerebras Chat Completions
   (`https://api.cerebras.ai/v1/chat/completions`) with
   `CEREBRAS_MODEL = gpt-oss-120b`.
2. Groq Chat Completions
   (`https://api.groq.com/openai/v1/chat/completions`) with
   `GROQ_MODEL = openai/gpt-oss-120b`.

Both use `response_format = json_schema` (strict). Set
`REWRITE_PROVIDER=groq` to prefer Groq, or
`REWRITE_PROVIDER_FALLBACK=false` to disable fallback. Safety/content blocks
do **not** fall back to another provider.

The prompt is built in `userPrompt()` and `systemInstructions()` inside
`index.ts`. Refinement intents map to one-line tone instructions in
`refinementInstruction()`.

## Secrets

Set in Supabase Dashboard → Project Settings → Edge Functions → Secrets.

| Key | Required | Default |
|---|---|---|
| `CEREBRAS_API_KEY` | one provider required | — |
| `GROQ_API_KEY` | one provider required | — |
| `REWRITE_PROVIDER` | no | `cerebras` |
| `REWRITE_PROVIDER_FALLBACK` | no | `true` |
| `CEREBRAS_MODEL` | no | `gpt-oss-120b` |
| `CEREBRAS_TIMEOUT_MS` | no | `8000` |
| `CEREBRAS_MAX_OUTPUT_TOKENS` | no | `600` (per candidate; total = value × candidateCount) |
| `CEREBRAS_REASONING_EFFORT` | no | unset (`low` / `medium` / `high` for `gpt-oss-120b`) |
| `GROQ_MODEL` | no | `openai/gpt-oss-120b` |
| `GROQ_TIMEOUT_MS` | no | `8000` |
| `GROQ_MAX_OUTPUT_TOKENS` | no | `600` (per candidate; total = value × candidateCount) |
| `GROQ_REASONING_EFFORT` | no | unset. Only valid for `openai/gpt-oss-*` models (values: `low` / `medium` / `high`). Leave unset for Llama / Kimi. |
| `MAX_REWRITE_CHARS` | no | `2000` |
| `USAGE_GUARD_MODE` | no | `local` (`db` for production) |
| `USER_DAILY_REWRITE_UNITS` | no | `900` candidates/day/user |
| `USER_HOURLY_REWRITE_REQUESTS` | no | `120` requests/hour/user |
| `USER_MINUTE_REWRITE_REQUESTS` | no | `12` requests/minute/user |
| `GLOBAL_DAILY_REWRITE_UNITS` | no | `100000` candidates/day/project |
| `GLOBAL_MINUTE_REWRITE_REQUESTS` | no | `300` requests/minute/project |
| `EVENT_LOGGING_ENABLED` | no | `true` (set `false` to disable `ai_rewrite_events` inserts) |

Provider API keys and the Supabase service role key must never be put in the
iOS app. The keyboard only knows the Supabase URL and publishable key.

## Usage Guard

The guard counts one unit per requested candidate. With the default
`candidateCount = 3`, `USER_DAILY_REWRITE_UNITS = 900` means roughly 300 full
rewrite requests per user per day. The default is intentionally useful for real
users while still blocking scripted abuse.

Modes:

- `USAGE_GUARD_MODE=local` — in-memory guard per warm Edge Function runtime.
  Good for local/dev and harmless as a first line of defense, but not enough
  for launch.
- `USAGE_GUARD_MODE=db` — calls
  `public.reserve_ai_rewrite_usage(...)` through the service role key. Apply
  `supabase/migrations/20260608000000_ai_rewrite_usage_limits.sql` before
  enabling this mode.

The migration creates an RLS-enabled usage table and grants access only to
`service_role`. `anon` and `authenticated` cannot read or update usage rows.

## Privacy

- Console logs include only: provider, command key, refinement, candidate
  count, input/prompt/output character lengths, latency, status. Raw text is
  not written to console logs.
- Raw rewrite payloads (prompt, input, all candidates, metadata) **are**
  persisted to the `public.ai_rewrite_events` table — this is the
  collection path covered by `docs/web/privacy.md` §2.1 / §7 / §11. Disable
  with `EVENT_LOGGING_ENABLED=false`.
- The iOS keyboard sends text only when the user taps an AI command —
  never per keystroke.

## Event log and retention

Table: `public.ai_rewrite_events`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` | Returned as `eventId` in the response |
| `user_id` | `uuid` | Supabase auth `sub` |
| `created_at` | `timestamptz` | Defaults to `now()` |
| `payload` | `jsonb` | `{ prompt, input, candidates, language, command_key, title, refinement, locale, app_version, candidate_count, provider, *_length, latency_ms }` |
| `selected_index` | `integer` (nullable) | Populated by a future feedback endpoint |
| `selected_at` | `timestamptz` (nullable) | Populated by a future feedback endpoint |

RLS is on; only `service_role` can read/write. Inserts happen synchronously
inside the request handler but a failed insert never fails the user
response — the client just receives `eventId: null`.

Retention helpers (schedule via `pg_cron` or external scheduler):

- `select public.delete_ai_rewrite_events_older_than(30);` — drop events
  older than 30 days. Returns the deleted row count.
- `select public.delete_old_ai_rewrite_usage_buckets(48, 35);` — drop
  minute/hour usage buckets older than 48 hours and day buckets older than
  35 days. Bucket rows are not user-facing — the values themselves only
  matter inside their bucket window.

Cold archive to Supabase Storage (NDJSON.gz) is deliberately not wired up
yet — defer until production volume justifies it.

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

- **Production usage guard must be DB mode**: `USAGE_GUARD_MODE=local` is still
  per-warm-runtime. Before public launch, apply the usage migration and set
  `USAGE_GUARD_MODE=db`.
- **Retention scheduling not yet automated.** The
  `delete_ai_rewrite_events_older_than` and
  `delete_old_ai_rewrite_usage_buckets` functions exist but are not yet on
  a `pg_cron` schedule.
- **No selected-candidate feedback path yet.** `eventId` is returned but the
  iOS client does not post selection back. Required for the highest-value
  signal in the collected data.
- **No abuse logging beyond Edge Function console logs.** Wire to
  Sentry / Logflare before launch.
- **No Retry-After display** — provider 429s are mapped to
  `provider_rate_limited`, but the client does not yet show provider-specific
  retry timing.

## Rollback

If a provider deploy goes bad, the previous OpenAI Responses API (`gpt-5.1`)
implementation is recoverable from git history. Find the commit before the
Groq/Cerebras provider work with:

```bash
git log --oneline -- supabase/functions/keyboard-rewrite/index.ts
git show <commit>:supabase/functions/keyboard-rewrite/index.ts > /tmp/openai.ts
```

Re-set `OPENAI_API_KEY` (and optionally `OPENAI_MODEL`,
`OPENAI_TIMEOUT_MS`, `OPENAI_MAX_OUTPUT_TOKENS`,
`OPENAI_REASONING_EFFORT`) in Supabase secrets, then deploy.
