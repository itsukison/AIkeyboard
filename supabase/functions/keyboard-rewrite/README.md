# keyboard-rewrite

Supabase Edge Function backing AIキーボード's Cloud AI rewrite mode. Calls
Groq Chat Completions (`openai/gpt-oss-120b` by default).

The full contract — endpoint, auth, request/response shape, error codes,
secrets, deployment, verification, and rollback — is documented in
[`docs/backend.md`](../../../docs/backend.md).

Source of truth: `index.ts` in this directory.
