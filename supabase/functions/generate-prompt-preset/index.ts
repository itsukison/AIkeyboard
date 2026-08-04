// generate-prompt-preset
//
// Onboarding-time button builder. Takes a short description of what the user
// wants the keyboard for — composed by the client from the builder's slot
// selections, or typed freehand — and returns exactly 4 keyboard buttons
// (1 main + 3 complementary) plus a worked example for the main button that the
// offline practice page replays.
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
const PRACTICE_OUTPUT_COUNT = 3;
const RATE_LIMIT_PER_HOUR = 30;

interface PresetButton {
  title: string;
  prompt: string;
}

/// The worked example the onboarding practice page replays for the main button.
/// Generated here, at button-creation time, because practice mode runs offline
/// and pre-auth (the container writes canned candidates into the App Group and
/// the keyboard replays them) — there is no way to produce this later.
interface PresetPractice {
  input: string;
  outputs: string[];
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
  required: ["buttons", "practice"],
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
            description: "ツールバーに表示する短いラベル。全角4文字以内。",
          },
          prompt: {
            type: "string",
            description: "このボタンを他と区別する書き換え指示だけを書いた日本語の文",
          },
        },
      },
    },
    practice: {
      type: "object",
      additionalProperties: false,
      required: ["input", "outputs"],
      description: "1つ目（メイン）のボタンの動作例",
      properties: {
        input: {
          type: "string",
          description: "メインボタンを使いたくなる20〜40文字程度の日本語の文章",
        },
        outputs: {
          type: "array",
          description: "inputにメインボタンのpromptを適用した結果を3つ",
          items: { type: "string" },
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

// Outcome-first, and each rule stated exactly once — the buttons this produces
// are consumed by `keyboard-rewrite`, whose own system prompt already fixes the
// invariants (preserve meaning/names/numbers/emoji, no markdown or commentary,
// return the rewritten text alone). Restating those here made every generated
// button repeat them, which per OpenAI's GPT-5.6 guidance costs tokens and
// degrades adherence. The explicit "do not write these" list below is load-
// bearing: without it the model reproduces them by habit.
function systemInstructions(): string {
  return [
    "あなたは日本語キーボードアプリの設定アシスタントです。",
    // "ちょうど4つ" is emphatic because it has to be: a production fix added
    // the same emphasis after the model returned short presets, which the
    // BUTTON_COUNT check then rejected as a hard failure.
    "ユーザーの用途から、キーボードのAIボタンを必ずちょうど4つ設計してください。1つ目がメイン、残り3つは併用しそうな補助ボタンです。",
    "",
    "title: ツールバーに表示される短いラベル。全角4文字以内。長いと隣のボタンを押しつぶします。",
    "prompt: そのボタンを押したときの書き換え指示。そのボタンを他と区別する内容だけを日本語で書いてください。",
    "",
    "promptに書かないでください（書き換え側で既に指定済みのため、繰り返すと精度が落ちます）:",
    "- 意味・意図・固有名詞・数字・日付・URL・絵文字を保つこと",
    "- 解説やマークダウンを付けないこと",
    "- 出力を変換後の文章だけにすること",
    "",
    "promptは「丁寧に」のような形容詞ではなく、「文末を〜です/ますにする」のような動作で書いてください。",
    "",
    "practiceは1つ目（メイン）のボタンの動作例です。outputsは、inputにメインボタンのpromptを適用した結果にしてください。メインボタンの指示に必ず従ってください（例: 敬語をやめる指示なら、outputsで敬語を使わない）。",
    "",
    "不適切・危険な用途には応じず、その場合は一般的な文章整形ボタン（敬語・自然に・要約・翻訳など）を返してください。",
  ].join("\n");
}

function userPrompt(description: string, useCase: string | null): string {
  const lines = [`用途:\n${description}`];
  if (useCase) {
    lines.push(`選んだカテゴリ: ${useCase}`);
  }
  return lines.join("\n\n");
}

// The buttons this produces are the strongest observed predictor of long-term
// retention, so this call runs on the same model as the rewrite path rather
// than the cheap one. It is once per user, behind a rate limit, and the client
// shows a spinner, so latency here is affordable. Cerebras stays as a fallback
// for when no OpenAI key is configured.
function providerConfig(): {
  name: "openai" | "cerebras";
  apiKey: string;
  model: string;
  endpoint: string;
  reasoningEffort: string | undefined;
} {
  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (openaiKey) {
    return {
      name: "openai",
      apiKey: openaiKey,
      model: Deno.env.get("PRESET_GEN_MODEL") ?? Deno.env.get("OPENAI_MODEL") ?? "gpt-5.6-terra",
      endpoint: Deno.env.get("OPENAI_CHAT_COMPLETIONS_URL") ??
        "https://api.openai.com/v1/chat/completions",
      reasoningEffort: Deno.env.get("PRESET_GEN_REASONING_EFFORT") ?? "low",
    };
  }

  const cerebrasKey = Deno.env.get("CEREBRAS_API_KEY");
  if (!cerebrasKey) {
    throw new Error("No preset-generation provider is configured.");
  }
  return {
    name: "cerebras",
    apiKey: cerebrasKey,
    model: Deno.env.get("CEREBRAS_MODEL") ?? "gpt-oss-120b",
    endpoint: Deno.env.get("CEREBRAS_CHAT_COMPLETIONS_URL") ??
      "https://api.cerebras.ai/v1/chat/completions",
    reasoningEffort: undefined,
  };
}

async function generatePreset(
  description: string,
  useCase: string | null,
): Promise<{ buttons: PresetButton[]; practice: PresetPractice | null }> {
  const config = providerConfig();

  const body: Record<string, unknown> = {
    model: config.model,
    messages: [
      { role: "system", content: systemInstructions() },
      { role: "user", content: userPrompt(description, useCase) },
    ],
    max_completion_tokens: 1600,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "prompt_preset",
        strict: true,
        schema: presetSchema,
      },
    },
  };
  if (config.reasoningEffort) {
    body.reasoning_effort = config.reasoningEffort;
  }
  if (config.name === "openai") {
    body.store = false;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20_000);

  let response: Response;
  try {
    response = await fetch(config.endpoint, {
      method: "POST",
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
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

  const parsed = JSON.parse(content) as {
    buttons?: PresetButton[];
    practice?: { input?: unknown; outputs?: unknown };
  };

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

  const practiceInput = typeof parsed.practice?.input === "string"
    ? parsed.practice.input.trim()
    : "";
  const practiceOutputs = Array.isArray(parsed.practice?.outputs)
    ? (parsed.practice.outputs as unknown[])
      .filter((o): o is string => typeof o === "string" && o.trim().length > 0)
      .slice(0, PRACTICE_OUTPUT_COUNT)
    : [];

  // A missing or short example is not fatal. Builds shipped before the practice
  // field existed call this endpoint and only read `buttons`, so failing the
  // whole request over it would break them; the current client falls back to its
  // built-in practice scenarios when the field is absent.
  const practice = practiceInput.length > 0 && practiceOutputs.length === PRACTICE_OUTPUT_COUNT
    ? { input: practiceInput, outputs: practiceOutputs }
    : null;

  return { buttons, practice };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("Method not allowed.", 405);
  }

  let description: string;
  let useCase: string | null;
  try {
    const body = await req.json();
    description = typeof body?.description === "string" ? body.description.trim() : "";
    useCase = typeof body?.useCase === "string" && body.useCase.trim().length > 0
      ? body.useCase.trim().slice(0, 40)
      : null;
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
    const { buttons, practice } = await generatePreset(description, useCase);
    return jsonResponse({ buttons, practice });
  } catch (error) {
    console.error("generate-prompt-preset failed:", error instanceof Error ? error.message : error);
    return errorResponse("ボタンを作成できませんでした。少し待ってからもう一度お試しください。", 502);
  }
});
