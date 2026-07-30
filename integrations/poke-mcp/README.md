# Poke MCP bridge

Local-first MCP service that lets Poke use the repository's current GTM rules,
start sandboxed Codex marketing draft jobs, and publish an approved TikTok Photo
Mode episode through Buffer after an explicit confirmation step.

This is not part of either iOS target. It runs on the development Mac and reaches
Poke through an HTTPS reverse tunnel, so the server and tunnel must remain running.

## Safety model

- `start_marketing_draft` invokes `codex exec` with `workspace-write` and a
  draft-only instruction. It cannot publish through the MCP bridge.
- Publishing is two-step: `prepare_tiktok_publish` validates the local assets and
  returns a 10-minute, single-use confirmation phrase; `publish_tiktok_episode`
  accepts only that exact phrase.
- The bridge re-resolves the Buffer organization and connected `keigobutton`
  TikTok channel for each publish.
- `sending` is reported as pending. Only Buffer `sent` is success.
- No secret is stored in the repository. Buffer and remote-MCP credentials come
  from environment variables.

## Setup

Requires Node.js 18+, the local `codex` CLI, the linked Supabase CLI used by
`scripts/marketing/upload_buffer_slides.py`, and a Buffer API key.

```bash
cd integrations/poke-mcp
npm install
cp .env.example .env
```

Use `POKE_AUTH_MODE=api-key`, generate a long random `POKE_MCP_API_KEY`, and
enter that same value in Poke's MCP integration API Key field. Do not use a
Poke Kitchen API key here: Kitchen keys cannot create MCP tunnels, while this
key protects a server that Poke calls.

Start the service with the variables loaded in your shell:

```bash
set -a
source .env
set +a
npm run dev
```

In a second terminal, expose the endpoint with an HTTPS reverse-tunnel provider.
For example, localhost.run requires no installation:

```bash
ssh -R 80:localhost:3000 nokey@localhost.run
```

Copy the printed HTTPS URL, append `/mcp`, then create a custom MCP integration
at `https://poke.com/integrations/new`. Supply the same `POKE_MCP_API_KEY` as
the integration API key. The tunnel stays online only while that command is
running. Use onboarding context such as:

> 敬語ボタンのGTMアシスタント。企画や制作依頼では最初に該当するmarketing
> context toolを読む。公開は必ずprepareを先に呼び、要約と完全な確認フレーズを
> ユーザーに見せ、そのフレーズが明示的に返信されるまでpublishを呼ばない。
> Buffer statusがsentになるまで公開成功とは言わない。

Suggested first messages:

- `今週の「上司チャット救命室」の企画を3本作って`
- `TikTokに出せるエピソードを一覧にして`
- `014を再公開せず、次に公開できる素材があるか確認して`

## Local verification

```bash
npm test
npm run typecheck
curl -s http://127.0.0.1:3000/health
curl -s -X POST http://127.0.0.1:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

The current publishing tool supports the repository's TikTok Photo Mode flow
(one to ten ordered 1080 x 1350 PNGs). A hosted always-on service or arbitrary
video upload is a separate deployment step because the current renderer and
Supabase upload helper depend on this local checkout.
