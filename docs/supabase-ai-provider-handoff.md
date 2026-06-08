# Supabase AI Provider Handoff

Last updated: 2026-06-08.

This handoff is for an agent with Supabase MCP access to the live
`AIキーボード` project.

## Correct Project

Use this project:

- Project ref: `eercsucvxnszqletxued`
- URL: `https://eercsucvxnszqletxued.supabase.co`
- Region: `ap-northeast-1`

Do **not** deploy to `wsttwofhxbcgfpwvxazj`. That project appears in the
current MCP account as `Bikey`, but this repo marks it as legacy and the iOS
app does not call it.

Code references:

- `Sources/JapaneseKeyboardAI/Service/CloudRewriteService.swift`
- `iOS/Container/SupabaseClient.swift`
- `docs/backend.md`

## What Was Done Locally

The Edge Function was updated in:

- `supabase/functions/keyboard-rewrite/index.ts`

Main behavior changes:

- Prefer Cerebras when `CEREBRAS_API_KEY` is configured.
- Use `gpt-oss-120b` on Cerebras by default.
- Keep Groq as fallback when `GROQ_API_KEY` is configured.
- Preserve the existing iOS request/response contract.
- Add clear Japanese user-facing backend errors:
  - `content_blocked`
  - `provider_rate_limited`
  - `provider_error`
- Replace the old low in-memory daily quota with abuse-oriented usage guards:
  - per-user minute/hour burst limits
  - high per-user daily candidate limit
  - global minute/day caps
- Add DB-backed usage guard support behind `USAGE_GUARD_MODE=db`.

The production DB migration was added in:

- `supabase/migrations/20260608000000_ai_rewrite_usage_limits.sql`

It creates:

- `public.ai_rewrite_usage_buckets`
- `public.reserve_ai_rewrite_usage(...)`

Security posture:

- RLS is enabled on the usage table.
- `anon` and `authenticated` have no table access.
- RPC execution is granted only to `service_role`.
- The Edge Function calls the RPC through Supabase REST using
  `SUPABASE_SERVICE_ROLE_KEY`.

Docs were updated:

- `AGENTS.md`
- `docs/backend.md`
- `docs/development.md`
- `docs/privacy.md`
- `docs/architecture.md`
- `supabase/functions/keyboard-rewrite/README.md`

## What Still Needs Remote Execution

The previous agent could not finish this because MCP was authenticated to the
wrong project set. Direct access to `eercsucvxnszqletxued` returned:

`MCP error -32600: You do not have permission to perform this action`

An agent with the correct MCP access should do the following.

## Remote Steps

1. Confirm project access.

   Required check:

   - `list_projects` includes `eercsucvxnszqletxued`, or
   - `get_project(id: "eercsucvxnszqletxued")` succeeds.

2. Confirm current Edge Function state.

   Check `keyboard-rewrite` exists on `eercsucvxnszqletxued` and has
   `verify_jwt = true`.

3. Apply the migration.

   Apply the SQL from:

   - `supabase/migrations/20260608000000_ai_rewrite_usage_limits.sql`

   Migration name:

   - `ai_rewrite_usage_limits`

4. Verify DB objects.

   Run a read-only check:

   ```sql
   select to_regclass('public.ai_rewrite_usage_buckets') as usage_table;

   select p.proname
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'reserve_ai_rewrite_usage';
   ```

5. Deploy the Edge Function.

   Deploy `keyboard-rewrite` to `eercsucvxnszqletxued` with:

   - entrypoint: `index.ts`
   - files:
     - `supabase/functions/keyboard-rewrite/index.ts`
     - `supabase/functions/keyboard-rewrite/deno.json`
   - import map path: `deno.json`
   - `verify_jwt: true`

6. Configure secrets.

   Required provider secret:

   - `CEREBRAS_API_KEY`

   Optional fallback provider secret:

   - `GROQ_API_KEY`

   Recommended production settings:

   - `REWRITE_PROVIDER=cerebras`
   - `REWRITE_PROVIDER_FALLBACK=true`
   - `USAGE_GUARD_MODE=db`
   - `USER_DAILY_REWRITE_UNITS=900`
   - `USER_HOURLY_REWRITE_REQUESTS=120`
   - `USER_MINUTE_REWRITE_REQUESTS=12`
   - `GLOBAL_DAILY_REWRITE_UNITS=100000`
   - `GLOBAL_MINUTE_REWRITE_REQUESTS=300`

   Optional provider tuning:

   - `CEREBRAS_MODEL=gpt-oss-120b`
   - `CEREBRAS_TIMEOUT_MS=8000`
   - `CEREBRAS_MAX_OUTPUT_TOKENS=600`
   - `CEREBRAS_REASONING_EFFORT=low`

7. Verify unauthenticated behavior.

   ```bash
   curl -i -X POST \
     https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite \
     -H 'Content-Type: application/json' \
     -d '{"prompt":"丁寧に書き直して","text":"今日はいい天気ですね"}'
   ```

   Expected: `401 unauthorized` from JWT enforcement.

8. Verify authenticated rewrite.

   Use a real Supabase user access token and publishable key:

   ```bash
   curl -i -X POST \
     https://eercsucvxnszqletxued.supabase.co/functions/v1/keyboard-rewrite \
     -H 'Content-Type: application/json' \
     -H 'Authorization: Bearer <user JWT>' \
     -H 'apikey: <publishable key>' \
     -d '{"prompt":"丁寧に書き直して","text":"今日はいい天気ですね","candidateCount":3}'
   ```

   Expected: `200` with `{ "candidates": [...], "language": "ja" }`.

9. Verify logs.

   Check Edge Function logs for:

   - `event = keyboard_rewrite`
   - `provider = cerebras`
   - `status = ok`
   - no raw input/output text

10. Verify DB usage rows.

   ```sql
   select scope, bucket, used_units, request_count, updated_at
   from public.ai_rewrite_usage_buckets
   order by updated_at desc
   limit 20;
   ```

   Expected: user/global rows increment after an authenticated rewrite.

## Notes For The Next Agent

- Supabase does not expose secret values after setting them. To check
  `CEREBRAS_API_KEY`, deploy and run an authenticated rewrite; a missing key
  returns `configuration_missing`.
- Do not put provider keys or `SUPABASE_SERVICE_ROLE_KEY` in the iOS app.
- If `USAGE_GUARD_MODE=db` is enabled before applying the migration, rewrites
  will be blocked with the usage-guard failure message.
- Safety/content blocks intentionally do not fall back to another provider.
- Provider 429s may fall back if another provider is configured. If all
  providers fail with 429, the client gets `provider_rate_limited`.
