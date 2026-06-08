# keyboard-rewrite-openai (deprecated)

OpenAI Responses API (`gpt-5.1`) を使っていた旧実装。2026-06-06に Groq Chat Completions API に切り替えたため保管。

Supabase CLI は `_` プレフィックス付きフォルダを Edge Function のデプロイ対象から除外するため、ここに置いても自動デプロイされない。

## 復元手順

1. このフォルダの `index.ts` を `supabase/functions/keyboard-rewrite/index.ts` に上書きコピー。
2. Supabase Secrets に `OPENAI_API_KEY` を再設定（任意で `OPENAI_MODEL`, `OPENAI_TIMEOUT_MS`, `OPENAI_MAX_OUTPUT_TOKENS`, `OPENAI_REASONING_EFFORT`）。
3. `supabase functions deploy keyboard-rewrite` で再デプロイ。

## 旧実装の特徴

- エンドポイント: `https://api.openai.com/v1/responses` (Responses API)
- 既定モデル: `gpt-5.1`
- `reasoning.effort = low`
- `max_output_tokens` ベース
- 構造化出力は `text.format.type = json_schema`
