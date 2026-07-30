# keyboard-rewrite

Supabase Edge Function backing AIキーボード's Cloud AI rewrite mode. Calls
OpenAI Chat Completions (`gpt-5.6-terra` by default) when an OpenAI key is
configured, with Cerebras (`gpt-oss-120b`) and the other configured providers
as fallback.

The full contract — endpoint, auth, request/response shape, error codes,
secrets, deployment, verification, and rollback — is documented in
[`docs/backend.md`](../../../docs/backend.md).

Source of truth: `index.ts` in this directory.
