type RefinementIntent = "morePolite" | "moreDetailed" | "moreConcise";

type RewriteRequest = {
  prompt: string;
  text: string;
  commandKey?: string;
  title?: string;
  locale?: string;
  appVersion?: string;
  candidateCount?: number;
  refinement?: RefinementIntent;
};

type RewriteCandidate = {
  replacement: string;
  changed: boolean;
};

type RewriteResult = {
  candidates: RewriteCandidate[];
  language: "ja" | "en" | "ko" | "zh" | "mixed";
};

type ApiErrorCode =
  | "method_not_allowed"
  | "unauthorized"
  | "invalid_json"
  | "invalid_request"
  | "prompt_too_long"
  | "text_too_long"
  | "rate_limited"
  | "configuration_missing"
  | "provider_error";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const refinements = new Set<RefinementIntent>([
  "morePolite",
  "moreDetailed",
  "moreConcise",
]);

const MIN_CANDIDATES = 1;
const MAX_CANDIDATES = 5;
const DEFAULT_CANDIDATES = 3;
const MAX_PROMPT_CHARS = 1000;

const dailyUsage = new Map<string, number>();

Deno.serve(async (req) => {
  const startedAt = Date.now();

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonError("method_not_allowed", "Use POST.", 405);
  }

  // verify_jwt=true means Supabase's gateway already validated the JWT
  // before invoking this function. We can trust the `sub` claim and avoid
  // a roundtrip to the auth service (which `supabase.auth.getUser()` would do).
  const authHeader = req.headers.get("Authorization") ?? "";
  const userId = userIdFromAuthHeader(authHeader);
  if (!userId) {
    return jsonError("unauthorized", "Invalid session.", 401);
  }

  const parsed = await parseRewriteRequest(req);
  if ("error" in parsed) {
    return parsed.error;
  }

  const request = parsed.value;
  const maxChars = envInt("MAX_REWRITE_CHARS", 2000);
  if ([...request.text].length > maxChars) {
    return jsonError("text_too_long", "Text is too long.", 413);
  }
  if ([...request.prompt].length > MAX_PROMPT_CHARS) {
    return jsonError("prompt_too_long", "Prompt is too long.", 413);
  }

  if (!(await consumeDailyQuota(userId, request.candidateCount ?? DEFAULT_CANDIDATES))) {
    return jsonError("rate_limited", "Daily rewrite limit reached.", 429);
  }

  const openAIKey = Deno.env.get("OPENAI_API_KEY");
  if (!openAIKey) {
    return jsonError("configuration_missing", "OPENAI_API_KEY is not configured.", 503);
  }

  try {
    const result = await rewriteWithOpenAI(openAIKey, request);
    console.log(JSON.stringify({
      event: "keyboard_rewrite",
      userId,
      commandKey: request.commandKey,
      refinement: request.refinement,
      candidateCount: result.candidates.length,
      inputLength: [...request.text].length,
      promptLength: [...request.prompt].length,
      outputLength: result.candidates.reduce(
        (sum, c) => sum + [...c.replacement].length,
        0,
      ),
      latencyMs: Date.now() - startedAt,
      status: "ok",
    }));
    return json(result);
  } catch (error) {
    console.error(JSON.stringify({
      event: "keyboard_rewrite",
      userId,
      commandKey: request.commandKey,
      inputLength: [...request.text].length,
      latencyMs: Date.now() - startedAt,
      status: "provider_error",
      message: error instanceof Error ? error.message : "unknown error",
    }));
    return jsonError("provider_error", "Rewrite provider failed.", 502);
  }
});

async function parseRewriteRequest(req: Request): Promise<
  { value: Required<Pick<RewriteRequest, "prompt" | "text" | "candidateCount">> & RewriteRequest } | { error: Response }
> {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return { error: jsonError("invalid_json", "Request body must be JSON.", 400) };
  }

  if (!body || typeof body !== "object") {
    return { error: jsonError("invalid_request", "Request body must be an object.", 400) };
  }

  const data = body as Record<string, unknown>;
  const prompt = data.prompt;
  const text = data.text;
  const commandKey = data.commandKey;
  const title = data.title;
  const locale = data.locale;
  const appVersion = data.appVersion;
  const refinementValue = data.refinement;
  const candidateCountValue = data.candidateCount;

  if (typeof prompt !== "string" || prompt.trim().length === 0) {
    return { error: jsonError("invalid_request", "Prompt is required.", 400) };
  }

  if (typeof text !== "string" || text.trim().length === 0) {
    return { error: jsonError("invalid_request", "Text is required.", 400) };
  }

  let refinement: RefinementIntent | undefined;
  if (typeof refinementValue === "string") {
    if (!refinements.has(refinementValue as RefinementIntent)) {
      return { error: jsonError("invalid_request", "Unsupported refinement intent.", 400) };
    }
    refinement = refinementValue as RefinementIntent;
  }

  let candidateCount = DEFAULT_CANDIDATES;
  if (typeof candidateCountValue === "number" && Number.isFinite(candidateCountValue)) {
    candidateCount = Math.min(MAX_CANDIDATES, Math.max(MIN_CANDIDATES, Math.floor(candidateCountValue)));
  }

  return {
    value: {
      prompt,
      text,
      commandKey: typeof commandKey === "string" ? commandKey : undefined,
      title: typeof title === "string" ? title : undefined,
      locale: typeof locale === "string" ? locale : "ja-JP",
      appVersion: typeof appVersion === "string" ? appVersion : "unknown",
      candidateCount,
      refinement,
    },
  };
}

async function consumeDailyQuota(userId: string, units: number): Promise<boolean> {
  const limit = envInt("DAILY_REWRITE_LIMIT", 50);
  const today = new Date().toISOString().slice(0, 10);
  const key = `${today}:${userId}`;
  const used = dailyUsage.get(key) ?? 0;
  if (used + units > limit) return false;
  dailyUsage.set(key, used + units);
  return true;
}

async function rewriteWithOpenAI(
  apiKey: string,
  request: RewriteRequest,
): Promise<RewriteResult> {
  const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-5.1";
  const candidateCount = request.candidateCount ?? DEFAULT_CANDIDATES;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), envInt("OPENAI_TIMEOUT_MS", 15000));

  const baseTokens = envInt("OPENAI_MAX_OUTPUT_TOKENS", 800);
  const maxOutputTokens = baseTokens * candidateCount;

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    signal: controller.signal,
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      instructions: systemInstructions(candidateCount),
      input: [{
        role: "user",
        content: [{
          type: "input_text",
          text: userPrompt(request),
        }],
      }],
      reasoning: { effort: Deno.env.get("OPENAI_REASONING_EFFORT") ?? "low" },
      max_output_tokens: maxOutputTokens,
      store: false,
      text: {
        format: {
          type: "json_schema",
          name: "keyboard_rewrite_response",
          strict: true,
          schema: rewriteSchema(candidateCount),
        },
      },
    }),
  }).finally(() => clearTimeout(timeout));

  if (!response.ok) {
    const message = await response.text();
    throw new Error(`OpenAI ${response.status}: ${message.slice(0, 400)}`);
  }

  const payload = await response.json();
  const text = extractOutputText(payload);
  const result = JSON.parse(text) as RewriteResult;
  return normalizeResult(result, request);
}

function extractOutputText(payload: any): string {
  if (typeof payload.output_text === "string") return payload.output_text;

  const pieces: string[] = [];
  for (const item of payload.output ?? []) {
    for (const content of item.content ?? []) {
      if (typeof content.text === "string") pieces.push(content.text);
      if (typeof content.output_text === "string") pieces.push(content.output_text);
    }
  }

  const text = pieces.join("").trim();
  if (!text) throw new Error("OpenAI response did not contain output text.");
  return text;
}

function normalizeResult(result: RewriteResult, request: RewriteRequest): RewriteResult {
  if (!result || !Array.isArray(result.candidates) || result.candidates.length === 0) {
    throw new Error("Invalid provider JSON.");
  }

  const allowedLanguages: Array<RewriteResult["language"]> = ["ja", "en", "ko", "zh", "mixed"];
  const language = allowedLanguages.includes(result.language)
    ? result.language
    : "ja";

  const candidates: RewriteCandidate[] = result.candidates
    .filter((c): c is RewriteCandidate => !!c && typeof c.replacement === "string")
    .map((c) => ({
      replacement: c.replacement,
      changed: typeof c.changed === "boolean" ? c.changed : c.replacement !== request.text,
    }));

  if (candidates.length === 0) {
    throw new Error("Invalid provider JSON: no candidates.");
  }

  return { candidates, language };
}

function systemInstructions(candidateCount: number): string {
  return [
    "You are a Japanese mobile keyboard writing assistant.",
    "Apply the user-supplied command instruction to the target text only.",
    "Preserve meaning, names, numbers, URLs, dates, emoji, and line breaks.",
    "Do not add explanations, greetings, markdown, quotes, or commentary.",
    `Return exactly ${candidateCount} distinct candidate rewrites that meaningfully differ in phrasing, structure, or emphasis. Avoid near-duplicates.`,
    "Return strict JSON matching the schema.",
  ].join("\n");
}

function userPrompt(request: RewriteRequest): string {
  const lines = [
    `Command: ${request.prompt}`,
    `Locale: ${request.locale ?? "ja-JP"}`,
    `Candidates requested: ${request.candidateCount ?? DEFAULT_CANDIDATES}`,
    `App version: ${request.appVersion ?? "unknown"}`,
  ];

  if (request.refinement) {
    lines.push(
      `Refinement: ${refinementInstruction(request.refinement)} The "Target text" below is a previous rewrite the user wants further refined — refine that text, not the very first original.`,
    );
  }

  lines.push("Target text:", "<target>", request.text, "</target>");
  return lines.join("\n");
}

function refinementInstruction(intent: RefinementIntent): string {
  switch (intent) {
    case "morePolite":
      return "Make it even more polite and respectful while keeping the same language and meaning.";
    case "moreDetailed":
      return "Add more detail and supporting context while keeping meaning and tone consistent.";
    case "moreConcise":
      return "Make it shorter and more direct while preserving the essential meaning.";
  }
}

function rewriteSchema(candidateCount: number): Record<string, unknown> {
  return {
    type: "object",
    additionalProperties: false,
    required: ["candidates", "language"],
    properties: {
      candidates: {
        type: "array",
        minItems: candidateCount,
        maxItems: candidateCount,
        items: {
          type: "object",
          additionalProperties: false,
          required: ["replacement", "changed"],
          properties: {
            replacement: { type: "string" },
            changed: { type: "boolean" },
          },
        },
      },
      language: { type: "string", enum: ["ja", "en", "ko", "zh", "mixed"] },
    },
  };
}

function envInt(name: string, fallback: number): number {
  const value = Number(Deno.env.get(name));
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function jsonError(code: ApiErrorCode, message: string, status: number): Response {
  return json({ error: { code, message } }, status);
}

function userIdFromAuthHeader(authHeader: string): string | null {
  if (!authHeader.toLowerCase().startsWith("bearer ")) return null;
  const token = authHeader.slice(7).trim();
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const padded = parts[1] + "=".repeat((4 - parts[1].length % 4) % 4);
    const json = atob(padded.replace(/-/g, "+").replace(/_/g, "/"));
    const payload = JSON.parse(json);
    return typeof payload.sub === "string" ? payload.sub : null;
  } catch {
    return null;
  }
}
