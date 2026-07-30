// generate-prompt-preset
//
// Onboarding-time helper for the "その他（AIにおまかせ）" use case. Takes a
// short free-text description of what the user wants the keyboard for and
// returns exactly 4 keyboard buttons (1 main + 3 complementary), each with a
// short Japanese title and a full rewrite instruction in the house style.
//
// Called during onboarding, BEFORE the user has an account, so it must work
// with only the publishable key — `verify_jwt = false` in config.toml. It never
// touches user data; the only side effect is one LLM call. Keep the input cap
// and strict output schema in place: this is an unauthenticated LLM endpoint.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_DESCRIPTION_LENGTH = 200;
const BUTTON_COUNT = 4;
const RATE_LIMIT_PER_HOUR = 30;

interface PresetButton {
  title: string;
  prompt: string;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorResponse(message: string, status: number): Response {
  return jsonResponse({ error: message }, status);
}

const presetSchema = {
  type: "object",
  additionalProperties: false,
  required: ["buttons"],
  properties: {
    buttons: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["title", "prompt"],
        properties: {
          title: {
            type: "string",
            description: "ボタンの短い日本語ラベル（2〜6文字程度）",
          },
          prompt: {
            type: "string",
            description: "AIへの日本語の指示文",
          },
        },
      },
    },
  },
} as const;

// Per-IP hourly cap. Fails OPEN on any misconfiguration or limiter error so a
// limiter problem can never block a real user mid-onboarding — the strict input
// cap + output schema remain the always-on guards.
async function hashIp(ip: string): Promise<string> {
  const pepper = Deno.env.get("USER_ID_HASH_PEPPER") ?? "";
  const data = new TextEncoder().encode(`${pepper}:${ip}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function underRateLimit(ipHash: string): Promise<boolean> {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return true;

  const windowStart = new Date();
  windowStart.setUTCMinutes(0, 0, 0);

  try {
    const res = await fetch(`${url}/rest/v1/rpc/bump_preset_gen_usage`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_ip_hash: ipHash,
        p_window_start: windowStart.toISOString(),
        p_limit: RATE_LIMIT_PER_HOUR,
      }),
    });
    if (!res.ok) return true;
    return (await res.json()) === true;
  } catch {
    return true;
  }
}

function systemInstructions(): string {
  return [
    "あなたは日本語キーボードアプリの設定アシスタントです。",
    "ユーザーが入力した「用途」に合わせて、キーボードのAIボタンを4つ設計してください。",
    "1つ目はその用途の中心となるメインボタン、残り3つは相性の良い補助ボタンにしてください。",
    "各ボタンには、短い日本語のラベル（title、2〜6文字程度）と、AIへの指示文（prompt）を付けてください。",
    "指示文（prompt）は日本語で書き、次のルールに従ってください:",
    "- 入力された文章に対する変換・書き換えの指示として書く。",
    "- 原文の意味・意図を保ち、事実を勝手に足したり省いたりしない。固有名詞・数字・日付・URL・絵文字は保つ。",
    "- 解説やマークダウンを付けず、出力は変換後の文章だけにするよう明記する。",
    "不適切・危険な用途には応じず、その場合は一般的な文章整形ボタン（敬語・自然に・要約・翻訳など）を返してください。",
    "厳密にスキーマに従ったJSONだけを返してください。",
  ].join("\n");
}

function userPrompt(description: string): string {
  return `用途:\n${description}`;
}

async function generatePreset(description: string): Promise<PresetButton[]> {
  const apiKey = Deno.env.get("CEREBRAS_API_KEY");
  if (!apiKey) {
    throw new Error("CEREBRAS_API_KEY is not configured.");
  }
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
          { role: "system", content: systemInstructions() },
          { role: "user", content: userPrompt(description) },
        ],
        max_completion_tokens: 1200,
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "prompt_preset",
            strict: true,
            schema: presetSchema,
          },
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

  const parsed = JSON.parse(content) as { buttons?: PresetButton[] };
  const buttons = (parsed.buttons ?? [])
    .filter(
      (b): b is PresetButton =>
        !!b && typeof b.title === "string" && typeof b.prompt === "string" &&
        b.title.trim().length > 0 && b.prompt.trim().length > 0,
    )
    .slice(0, BUTTON_COUNT);

  if (buttons.length !== BUTTON_COUNT) {
    throw new Error("provider returned an incomplete preset");
  }
  return buttons;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("Method not allowed.", 405);
  }

  let description: string;
  try {
    const body = await req.json();
    description = typeof body?.description === "string" ? body.description.trim() : "";
  } catch {
    return errorResponse("Invalid request body.", 400);
  }

  if (description.length === 0) {
    return errorResponse("用途を入力してください。", 400);
  }
  if (description.length > MAX_DESCRIPTION_LENGTH) {
    return errorResponse("用途が長すぎます。", 400);
  }

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const ipHash = await hashIp(ip);
  if (!(await underRateLimit(ipHash))) {
    return errorResponse("リクエストが多すぎます。しばらくしてからお試しください。", 429);
  }

  try {
    const buttons = await generatePreset(description);
    return jsonResponse({ buttons });
  } catch (error) {
    console.error("generate-prompt-preset failed:", error instanceof Error ? error.message : error);
    return errorResponse("ボタンを作成できませんでした。少し待ってからもう一度お試しください。", 502);
  }
});
