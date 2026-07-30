// web-rewrite
//
// Powers the free browser tools on keigobutton.com (/keigo-henkan and friends).
// Those pages exist to rank for 「敬語変換」-class queries and convert the
// visitor into an app install, so this endpoint has to be usable with no
// account and no key — `verify_jwt = false` in config.toml.
//
// That makes it an unauthenticated LLM endpoint on the public internet. Four
// guards stand in front of it, and none of them should be relaxed:
//
//   1. Origin allowlist — browsers cannot call it from anywhere else.
//   2. Hard input cap (MAX_INPUT_CHARS) — bounds the prompt cost per call.
//   3. Small max_completion_tokens × 2 candidates — bounds the output cost.
//   4. Per-IP daily counter in Postgres — bounds calls per visitor.
//
// The counter is deliberately the *last* line, not the first: it fails open on
// infrastructure errors (same posture as generate-prompt-preset) so a database
// hiccup degrades the free tool rather than breaking it. Guards 1–3 are always
// on and are what actually bound the spend.
//
// The daily cap is also a product feature: hitting it is the moment the page
// tells the visitor that the keyboard has no limit and needs no copy-paste.

const ALLOWED_ORIGINS = new Set([
  "https://keigobutton.com",
  "https://www.keigobutton.com",
  "http://localhost:3000",
  "http://127.0.0.1:3000",
]);

const MAX_INPUT_CHARS = 300;
const CANDIDATE_COUNT = 2;
const DAILY_LIMIT = 5;
const MAX_OUTPUT_TOKENS = 500;

type Mode = "keigo" | "mail" | "natural" | "reply";

const MODES: Record<Mode, { label: string; instruction: string }> = {
  keigo: {
    label: "敬語",
    instruction:
      "入力文を、日本語のビジネス敬語に書き直してください。送る相手は社内の上司または取引先を想定し、チャットやメールにそのまま貼れる長さにしてください。",
  },
  mail: {
    label: "メール文",
    instruction:
      "入力文の内容をもとに、ビジネスメールの本文に書き直してください。宛名は入れず、本文と結びの一文までを出力してください。挨拶は「お世話になっております。」程度にとどめてください。",
  },
  natural: {
    label: "自然な言い方",
    instruction:
      "入力文を、丁寧すぎず失礼でもない自然な日本語に書き直してください。かたい漢語や過剰な敬語は避け、同僚や少し年上の相手に送れる調子にしてください。",
  },
  reply: {
    label: "返信文",
    instruction:
      "入力文は「受け取ったメッセージ」です。これに対する返信の本文を、日本語のビジネス敬語で作成してください。受け取ったメッセージを引用せず、返信本文だけを出力してください。",
  },
};

function corsHeadersFor(origin: string | null): Record<string, string> {
  // Echo only allowlisted origins. An unknown origin gets no CORS header at
  // all, so the browser blocks the response even though the request succeeded.
  const allowed = origin && ALLOWED_ORIGINS.has(origin) ? origin : "";
  return {
    ...(allowed ? { "Access-Control-Allow-Origin": allowed } : {}),
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
}

function json(body: unknown, status: number, origin: string | null): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeadersFor(origin),
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

const rewriteSchema = {
  type: "object",
  additionalProperties: false,
  required: ["candidates"],
  properties: {
    candidates: {
      type: "array",
      items: { type: "string" },
      description: "書き直した候補文",
    },
  },
} as const;

async function hashIp(ip: string): Promise<string> {
  const pepper = Deno.env.get("USER_ID_HASH_PEPPER") ?? "";
  const data = new TextEncoder().encode(`web:${pepper}:${ip}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Increments today's per-IP counter and reports how many calls remain.
 * `remaining` is surfaced to the client so the page can show the free quota
 * and swap in the install CTA at zero.
 */
async function reserveDailyUsage(
  ipHash: string,
): Promise<{ allowed: boolean; remaining: number }> {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return { allowed: true, remaining: DAILY_LIMIT };

  const windowStart = new Date();
  windowStart.setUTCHours(0, 0, 0, 0);

  try {
    const res = await fetch(`${url}/rest/v1/rpc/bump_web_rewrite_usage`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_ip_hash: ipHash,
        p_window_start: windowStart.toISOString(),
      }),
    });
    if (!res.ok) return { allowed: true, remaining: DAILY_LIMIT };

    const used = Number(await res.json());
    if (!Number.isFinite(used)) return { allowed: true, remaining: DAILY_LIMIT };
    return { allowed: used <= DAILY_LIMIT, remaining: Math.max(0, DAILY_LIMIT - used) };
  } catch {
    return { allowed: true, remaining: DAILY_LIMIT };
  }
}

function systemInstructions(mode: Mode): string {
  return [
    "あなたは日本語のビジネス文章を整える編集者です。",
    MODES[mode].instruction,
    "次のルールを厳守してください:",
    "- 原文の意味・意図を変えない。固有名詞・数字・日付・URLは書き換えない。",
    "- 原文に書かれていない事実・理由・約束を足さない。",
    "- 解説、前置き、マークダウン、かぎかっこでの囲みを付けない。",
    `- 候補を必ず${CANDIDATE_COUNT}つ返す。1つ目は標準、2つ目はもう一段ていねいな言い方にする。`,
    "- 候補どうしがほぼ同じ文にならないようにする。",
    "入力が日本語以外の場合も、出力は日本語にしてください。",
    "厳密にスキーマに従ったJSONだけを返してください。",
  ].join("\n");
}

async function rewrite(text: string, mode: Mode): Promise<string[]> {
  const apiKey = Deno.env.get("CEREBRAS_API_KEY");
  if (!apiKey) throw new Error("CEREBRAS_API_KEY is not configured.");

  const model = Deno.env.get("CEREBRAS_MODEL") ?? "gpt-oss-120b";
  const endpoint = Deno.env.get("CEREBRAS_CHAT_COMPLETIONS_URL") ??
    "https://api.cerebras.ai/v1/chat/completions";

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20_000);

  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: systemInstructions(mode) },
          { role: "user", content: text },
        ],
        max_completion_tokens: MAX_OUTPUT_TOKENS * CANDIDATE_COUNT,
        response_format: {
          type: "json_schema",
          json_schema: { name: "web_rewrite", strict: true, schema: rewriteSchema },
        },
      }),
    });
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`provider ${response.status}: ${detail.slice(0, 300)}`);
  }

  const payload = await response.json();
  const content = payload?.choices?.[0]?.message?.content;
  if (typeof content !== "string" || content.trim().length === 0) {
    throw new Error("provider returned no content");
  }

  const parsed = JSON.parse(content) as { candidates?: unknown };
  const candidates = Array.isArray(parsed.candidates)
    ? parsed.candidates
      .filter((c): c is string => typeof c === "string" && c.trim().length > 0)
      .map((c) => c.trim())
      .slice(0, CANDIDATE_COUNT)
    : [];

  if (candidates.length === 0) throw new Error("provider returned no candidates");
  return candidates;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeadersFor(origin) });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405, origin);
  }
  // Guard 1. A missing Origin header means a non-browser caller; allow it
  // through to the remaining guards rather than breaking curl-based checks.
  if (origin && !ALLOWED_ORIGINS.has(origin)) {
    return json({ error: "Forbidden origin." }, 403, origin);
  }

  let text: string;
  let mode: Mode;
  try {
    const body = await req.json();
    text = typeof body?.text === "string" ? body.text.trim() : "";
    mode = typeof body?.mode === "string" && body.mode in MODES ? body.mode as Mode : "keigo";
  } catch {
    return json({ error: "リクエストの形式が正しくありません。" }, 400, origin);
  }

  if (text.length === 0) {
    return json({ error: "文章を入力してください。" }, 400, origin);
  }
  // Guard 2.
  if (text.length > MAX_INPUT_CHARS) {
    return json(
      {
        error:
          `Web版は${MAX_INPUT_CHARS}文字までです。長い文章はアプリでお試しください。`,
        code: "too_long",
      },
      400,
      origin,
    );
  }

  // Guard 4.
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const usage = await reserveDailyUsage(await hashIp(ip));
  if (!usage.allowed) {
    return json(
      {
        error: "本日の無料回数（1日5回）を使い切りました。",
        code: "rate_limited",
        remaining: 0,
      },
      429,
      origin,
    );
  }

  try {
    const candidates = await rewrite(text, mode);
    return json({ candidates, remaining: usage.remaining, mode }, 200, origin);
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "web_rewrite_failed",
        mode,
        input_length: text.length,
        message: error instanceof Error ? error.message : "unknown error",
      }),
    );
    return json(
      { error: "変換できませんでした。少し待ってからもう一度お試しください。" },
      502,
      origin,
    );
  }
});
