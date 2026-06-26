type RefinementIntent = "morePolite" | "moreDetailed" | "moreConcise";

type RewriteRequest = {
  prompt: string;
  text: string;
  replyTo?: string;
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

type ProviderName = "cerebras" | "groq";

type ProviderResult = {
  provider: ProviderName;
  result: RewriteResult;
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
  | "content_blocked"
  | "provider_rate_limited"
  | "provider_error";

type UsageBucket = {
  units: number;
  requests: number;
};

class ProviderError extends Error {
  constructor(
    public readonly provider: ProviderName,
    public readonly code: "content_blocked" | "provider_rate_limited" | "provider_error",
    public readonly userMessage: string,
    message: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = "ProviderError";
  }
}

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

const localUsage = new Map<string, UsageBucket>();

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

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonError("invalid_json", "Request body must be JSON.", 400);
  }

  if (isFeedbackRequest(body)) {
    return await handleFeedback(userId, body);
  }

  const parsed = parseRewriteRequest(body);
  if ("error" in parsed) {
    return parsed.error;
  }

  const request = parsed.value;
  const maxChars = envInt("MAX_REWRITE_CHARS", 2000);
  if ([...request.text].length > maxChars) {
    return jsonError("text_too_long", "Text is too long.", 413);
  }
  if (request.replyTo && [...request.replyTo].length > maxChars) {
    return jsonError("text_too_long", "Text is too long.", 413);
  }
  if ([...request.prompt].length > MAX_PROMPT_CHARS) {
    return jsonError("prompt_too_long", "Prompt is too long.", 413);
  }

  const providers = configuredProviders();
  if (providers.length === 0) {
    return jsonError("configuration_missing", "No rewrite provider API key is configured.", 503);
  }

  const usage = await reserveUsage(userId, request.candidateCount ?? DEFAULT_CANDIDATES);
  if (!usage.allowed) {
    return jsonError("rate_limited", usage.message, 429);
  }

  try {
    const rewrite = await rewriteWithProviders(providers, request);
    const result = rewrite.result;
    const latencyMs = Date.now() - startedAt;
    console.log(JSON.stringify({
      event: "keyboard_rewrite",
      provider: rewrite.provider,
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
      latencyMs,
      status: "ok",
    }));
    const eventId = crypto.randomUUID();
    // Fire-and-forget: keep the worker alive long enough to finish the
    // insert, but don't make the user wait for it.
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil(
      logRewriteEvent(eventId, {
        userId,
        request,
        result,
        provider: rewrite.provider,
        latencyMs,
      }),
    );
    return json({ ...result, eventId });
  } catch (error) {
    const providerError = error instanceof ProviderError ? error : null;
    console.error(JSON.stringify({
      event: "keyboard_rewrite",
      provider: providerError?.provider,
      userId,
      commandKey: request.commandKey,
      inputLength: [...request.text].length,
      latencyMs: Date.now() - startedAt,
      status: providerError?.code ?? "provider_error",
      message: error instanceof Error ? error.message : "unknown error",
    }));
    if (providerError) {
      const status = providerError.code === "content_blocked" ? 422
        : providerError.code === "provider_rate_limited" ? 429
        : 502;
      return jsonError(providerError.code, providerError.userMessage, status);
    }
    return jsonError("provider_error", "AIの処理に失敗しました。少し待ってからもう一度お試しください。", 502);
  }
});

function parseRewriteRequest(body: unknown):
  { value: Required<Pick<RewriteRequest, "prompt" | "text" | "candidateCount">> & RewriteRequest } | { error: Response }
{
  if (!body || typeof body !== "object") {
    return { error: jsonError("invalid_request", "Request body must be an object.", 400) };
  }

  const data = body as Record<string, unknown>;
  const prompt = data.prompt;
  const text = data.text;
  const replyTo = data.replyTo;
  const commandKey = data.commandKey;
  const title = data.title;
  const locale = data.locale;
  const appVersion = data.appVersion;
  const refinementValue = data.refinement;
  const candidateCountValue = data.candidateCount;

  if (typeof prompt !== "string" || prompt.trim().length === 0) {
    return { error: jsonError("invalid_request", "Prompt is required.", 400) };
  }

  const hasReplyTo = typeof replyTo === "string" && replyTo.trim().length > 0;

  // In reply mode the message being replied to is the required input; the user's
  // draft (`text`) is optional intent and may be empty.
  if (typeof text !== "string" || (text.trim().length === 0 && !hasReplyTo)) {
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
      replyTo: hasReplyTo ? (replyTo as string) : undefined,
      commandKey: typeof commandKey === "string" ? commandKey : undefined,
      title: typeof title === "string" ? title : undefined,
      locale: typeof locale === "string" ? locale : "ja-JP",
      appVersion: typeof appVersion === "string" ? appVersion : "unknown",
      candidateCount,
      refinement,
    },
  };
}

function isFeedbackRequest(body: unknown): body is { eventId: string; selectedIndex: number } {
  if (!body || typeof body !== "object") return false;
  const data = body as Record<string, unknown>;
  return typeof data.eventId === "string" && typeof data.selectedIndex === "number";
}

// Records which candidate the user accepted, turning a logged rewrite into a
// labeled (input, chosen) preference example. Scoped by user_id so a caller can
// only annotate their own events. Best-effort: the client does not block on it.
async function handleFeedback(
  userId: string,
  body: { eventId: string; selectedIndex: number },
): Promise<Response> {
  const eventId = body.eventId.trim();
  const selectedIndex = Math.floor(body.selectedIndex);
  if (!/^[0-9a-fA-F-]{36}$/.test(eventId) || !Number.isFinite(selectedIndex) || selectedIndex < 0) {
    return jsonError("invalid_request", "Invalid feedback.", 400);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !serviceRoleKey) {
    return jsonError("configuration_missing", "Feedback storage is not configured.", 503);
  }

  try {
    const response = await fetch(
      `${supabaseURL}/rest/v1/ai_rewrite_events?id=eq.${eventId}&user_id=eq.${userId}`,
      {
        method: "PATCH",
        headers: {
          "Authorization": `Bearer ${serviceRoleKey}`,
          "apikey": serviceRoleKey,
          "Content-Type": "application/json",
          "Prefer": "return=minimal",
        },
        body: JSON.stringify({
          selected_index: selectedIndex,
          selected_at: new Date().toISOString(),
        }),
      },
    );
    if (!response.ok) {
      console.error(JSON.stringify({
        event: "ai_rewrite_feedback_failed",
        httpStatus: response.status,
        message: (await response.text()).slice(0, 400),
      }));
      return jsonError("provider_error", "Failed to record feedback.", 502);
    }
  } catch (error) {
    console.error(JSON.stringify({
      event: "ai_rewrite_feedback_failed",
      message: error instanceof Error ? error.message : "unknown error",
    }));
    return jsonError("provider_error", "Failed to record feedback.", 502);
  }

  return json({ ok: true });
}

async function reserveUsage(userId: string, units: number): Promise<{ allowed: boolean; message: string }> {
  const now = new Date();
  const dayBucket = now.toISOString().slice(0, 10);
  const hourBucket = now.toISOString().slice(0, 13);
  const minuteBucket = now.toISOString().slice(0, 16);

  if ((Deno.env.get("USAGE_GUARD_MODE") ?? "local") === "db") {
    return await reserveDatabaseUsage(userId, units, dayBucket, hourBucket, minuteBucket);
  }

  return reserveLocalUsage(userId, units, dayBucket, hourBucket, minuteBucket);
}

async function reserveDatabaseUsage(
  userId: string,
  units: number,
  dayBucket: string,
  hourBucket: string,
  minuteBucket: string,
): Promise<{ allowed: boolean; message: string }> {
  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !serviceRoleKey) {
    return {
      allowed: false,
      message: "AIの利用制限を確認できませんでした。少し待ってからもう一度お試しください。",
    };
  }

  const response = await fetch(`${supabaseURL}/rest/v1/rpc/reserve_ai_rewrite_usage`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
      "apikey": serviceRoleKey,
    },
    body: JSON.stringify({
      p_user_id: userId,
      p_units: units,
      p_day_bucket: dayBucket,
      p_hour_bucket: hourBucket,
      p_minute_bucket: minuteBucket,
      p_user_daily_unit_limit: envInt("USER_DAILY_REWRITE_UNITS", 900),
      p_user_hourly_request_limit: envInt("USER_HOURLY_REWRITE_REQUESTS", 120),
      p_user_minute_request_limit: envInt("USER_MINUTE_REWRITE_REQUESTS", 12),
      p_global_daily_unit_limit: envInt("GLOBAL_DAILY_REWRITE_UNITS", 100000),
      p_global_minute_request_limit: envInt("GLOBAL_MINUTE_REWRITE_REQUESTS", 300),
    }),
  });

  if (!response.ok) {
    console.error(JSON.stringify({
      event: "keyboard_rewrite_usage_guard",
      status: "error",
      httpStatus: response.status,
      message: (await response.text()).slice(0, 400),
    }));
    return {
      allowed: false,
      message: "AIの利用制限を確認できませんでした。少し待ってからもう一度お試しください。",
    };
  }

  const payload = await response.json();
  return {
    allowed: payload?.allowed === true,
    message: typeof payload?.message === "string"
      ? payload.message
      : "AIの利用が一時的に制限されています。少し待ってからもう一度お試しください。",
  };
}

function reserveLocalUsage(
  userId: string,
  units: number,
  dayBucket: string,
  hourBucket: string,
  minuteBucket: string,
): { allowed: boolean; message: string } {
  const checks: Array<[string, number, keyof UsageBucket, string]> = [
    [`user:${userId}:day:${dayBucket}`, envInt("USER_DAILY_REWRITE_UNITS", 900), "units", "本日のAI利用上限に達しました。明日もう一度お試しください。"],
    [`user:${userId}:hour:${hourBucket}`, envInt("USER_HOURLY_REWRITE_REQUESTS", 120), "requests", "短時間のAI利用が多すぎます。少し待ってからもう一度お試しください。"],
    [`user:${userId}:minute:${minuteBucket}`, envInt("USER_MINUTE_REWRITE_REQUESTS", 12), "requests", "短時間のAI利用が多すぎます。少し待ってからもう一度お試しください。"],
    [`global:day:${dayBucket}`, envInt("GLOBAL_DAILY_REWRITE_UNITS", 100000), "units", "本日のAI利用上限に達しました。時間をおいてもう一度お試しください。"],
    [`global:minute:${minuteBucket}`, envInt("GLOBAL_MINUTE_REWRITE_REQUESTS", 300), "requests", "AIが混み合っています。少し待ってからもう一度お試しください。"],
  ];

  for (const [key, limit, field, message] of checks) {
    const bucket = localUsage.get(key) ?? { units: 0, requests: 0 };
    const next = bucket[field] + (field === "units" ? units : 1);
    if (next > limit) {
      return { allowed: false, message };
    }
  }

  for (const [key] of checks) {
    const bucket = localUsage.get(key) ?? { units: 0, requests: 0 };
    bucket.units += units;
    bucket.requests += 1;
    localUsage.set(key, bucket);
  }

  return { allowed: true, message: "" };
}

async function logRewriteEvent(
  eventId: string,
  input: {
    userId: string;
    request: RewriteRequest;
    result: RewriteResult;
    provider: ProviderName;
    latencyMs: number;
  },
): Promise<void> {
  if ((Deno.env.get("EVENT_LOGGING_ENABLED") ?? "true") === "false") {
    return;
  }
  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !serviceRoleKey) return;

  const payload = {
    prompt: input.request.prompt,
    input: input.request.text,
    reply_to: input.request.replyTo ?? null,
    candidates: input.result.candidates,
    language: input.result.language,
    command_key: input.request.commandKey ?? null,
    title: input.request.title ?? null,
    refinement: input.request.refinement ?? null,
    locale: input.request.locale ?? null,
    app_version: input.request.appVersion ?? null,
    candidate_count: input.request.candidateCount ?? DEFAULT_CANDIDATES,
    provider: input.provider,
    input_length: [...input.request.text].length,
    prompt_length: [...input.request.prompt].length,
    output_length: input.result.candidates.reduce(
      (sum, c) => sum + [...c.replacement].length,
      0,
    ),
    latency_ms: input.latencyMs,
  };

  try {
    const response = await fetch(`${supabaseURL}/rest/v1/ai_rewrite_events`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${serviceRoleKey}`,
        "apikey": serviceRoleKey,
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
      },
      body: JSON.stringify({
        id: eventId,
        user_id: input.userId,
        payload,
      }),
    });
    if (!response.ok) {
      console.error(JSON.stringify({
        event: "ai_rewrite_event_log_failed",
        httpStatus: response.status,
        message: (await response.text()).slice(0, 400),
      }));
    }
  } catch (error) {
    console.error(JSON.stringify({
      event: "ai_rewrite_event_log_failed",
      message: error instanceof Error ? error.message : "unknown error",
    }));
  }
}

function configuredProviders(): ProviderName[] {
  const primary = Deno.env.get("REWRITE_PROVIDER") === "groq" ? "groq" : "cerebras";
  const fallbackEnabled = (Deno.env.get("REWRITE_PROVIDER_FALLBACK") ?? "true") !== "false";
  const providers: ProviderName[] = primary === "cerebras" ? ["cerebras", "groq"] : ["groq", "cerebras"];
  return providers.filter((provider, index) => {
    if (index > 0 && !fallbackEnabled) return false;
    return provider === "cerebras"
      ? !!Deno.env.get("CEREBRAS_API_KEY")
      : !!Deno.env.get("GROQ_API_KEY");
  });
}

async function rewriteWithProviders(
  providers: ProviderName[],
  request: RewriteRequest,
): Promise<ProviderResult> {
  let lastError: unknown;
  for (const provider of providers) {
    try {
      return {
        provider,
        result: await rewriteWithProvider(provider, request),
      };
    } catch (error) {
      lastError = error;
      const providerError = error instanceof ProviderError ? error : null;
      console.error(JSON.stringify({
        event: "keyboard_rewrite_provider_attempt",
        provider,
        status: providerError?.code ?? "provider_error",
        message: error instanceof Error ? error.message : "unknown error",
      }));
      if (providerError && providerError.code === "content_blocked") {
        throw error;
      }
    }
  }
  throw lastError;
}

async function rewriteWithProvider(
  provider: ProviderName,
  request: RewriteRequest,
): Promise<RewriteResult> {
  const apiKey = provider === "cerebras"
    ? Deno.env.get("CEREBRAS_API_KEY")
    : Deno.env.get("GROQ_API_KEY");
  if (!apiKey) {
    throw new ProviderError(
      provider,
      "provider_error",
      "AIの設定が不足しています。",
      `${provider} API key is not configured.`,
    );
  }

  const model = provider === "cerebras"
    ? Deno.env.get("CEREBRAS_MODEL") ?? "gpt-oss-120b"
    : Deno.env.get("GROQ_MODEL") ?? "openai/gpt-oss-120b";
  const candidateCount = request.candidateCount ?? DEFAULT_CANDIDATES;
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    provider === "cerebras" ? envInt("CEREBRAS_TIMEOUT_MS", 8000) : envInt("GROQ_TIMEOUT_MS", 8000),
  );

  const baseTokens = provider === "cerebras"
    ? envInt("CEREBRAS_MAX_OUTPUT_TOKENS", 600)
    : envInt("GROQ_MAX_OUTPUT_TOKENS", 600);
  const maxCompletionTokens = baseTokens * candidateCount;
  const reasoningEffort = provider === "cerebras"
    ? Deno.env.get("CEREBRAS_REASONING_EFFORT")
    : Deno.env.get("GROQ_REASONING_EFFORT");

  const isReply = typeof request.replyTo === "string" && request.replyTo.trim().length > 0;
  const body: Record<string, unknown> = {
    model,
    messages: [
      {
        role: "system",
        content: isReply
          ? systemInstructionsForReply(candidateCount)
          : systemInstructions(candidateCount),
      },
      { role: "user", content: userPrompt(request) },
    ],
    max_completion_tokens: maxCompletionTokens,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "keyboard_rewrite_response",
        strict: true,
        schema: rewriteSchema(candidateCount),
      },
    },
  };

  if (reasoningEffort) {
    body.reasoning_effort = reasoningEffort;
  }

  const endpoint = provider === "cerebras"
    ? Deno.env.get("CEREBRAS_CHAT_COMPLETIONS_URL") ?? "https://api.cerebras.ai/v1/chat/completions"
    : Deno.env.get("GROQ_CHAT_COMPLETIONS_URL") ?? "https://api.groq.com/openai/v1/chat/completions";

  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });
  } catch (error) {
    throw new ProviderError(
      provider,
      "provider_error",
      "AIの処理に失敗しました。少し待ってからもう一度お試しください。",
      error instanceof Error ? error.message : "unknown provider request error",
    );
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    const message = await response.text();
    throw providerErrorFromResponse(provider, response.status, message);
  }

  const payload = await response.json();
  const finishReason = payload?.choices?.[0]?.finish_reason;
  if (finishReason === "content_filter") {
    throw new ProviderError(
      provider,
      "content_blocked",
      "この内容はAIで書き換えできません。内容を変えてもう一度お試しください。",
      `${provider} content_filter`,
      422,
    );
  }
  const text = extractMessageContent(payload, provider);
  const result = JSON.parse(text) as RewriteResult;
  return normalizeResult(result, request);
}

function providerErrorFromResponse(provider: ProviderName, status: number, body: string): ProviderError {
  const lower = body.toLowerCase();
  if (status === 429) {
    return new ProviderError(
      provider,
      "provider_rate_limited",
      "AIが混み合っています。少し待ってからもう一度お試しください。",
      `${provider} ${status}: ${body.slice(0, 400)}`,
      status,
    );
  }
  if (
    (status === 400 || status === 403 || status === 422) &&
    (lower.includes("content_filter") ||
      lower.includes("safety") ||
      lower.includes("policy") ||
      lower.includes("moderation"))
  ) {
    return new ProviderError(
      provider,
      "content_blocked",
      "この内容はAIで書き換えできません。内容を変えてもう一度お試しください。",
      `${provider} ${status}: ${body.slice(0, 400)}`,
      status,
    );
  }
  return new ProviderError(
    provider,
    "provider_error",
    "AIの処理に失敗しました。少し待ってからもう一度お試しください。",
    `${provider} ${status}: ${body.slice(0, 400)}`,
    status,
  );
}

function extractMessageContent(payload: any, provider: ProviderName): string {
  const choice = payload?.choices?.[0];
  const content = choice?.message?.content;
  if (typeof content === "string" && content.trim().length > 0) {
    return content;
  }

  // Some providers return content as an array of parts.
  if (Array.isArray(content)) {
    const text = content
      .map((part: any) =>
        typeof part?.text === "string" ? part.text : "",
      )
      .join("")
      .trim();
    if (text) return text;
  }

  throw new ProviderError(
    provider,
    "provider_error",
    "AIの処理に失敗しました。少し待ってからもう一度お試しください。",
    `${provider} response did not contain message content.`,
  );
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
  const candidateInstruction = candidateCount === 3
    ? [
      "Return exactly 3 candidate rewrites in this fixed order:",
      "1. Standard: balanced and natural for the requested command.",
      "2. Slightly softer: warmer and a little more casual, without slang.",
      "3. Slightly more polite: one notch more courteous, without becoming stiff.",
      "Keep the differences subtle unless the command or refinement explicitly asks for a stronger change.",
      "Avoid near-duplicates.",
    ].join("\n")
    : `Return exactly ${candidateCount} distinct candidate rewrites that meaningfully differ in phrasing, structure, or emphasis. Avoid near-duplicates.`;

  return [
    "You are a Japanese mobile keyboard writing assistant.",
    "Apply the user-supplied command instruction to the target text only.",
    "Preserve meaning, names, numbers, URLs, dates, emoji, and line breaks.",
    "Do not add explanations, greetings, markdown, quotes, or commentary.",
    candidateInstruction,
    "Return strict JSON matching the schema.",
  ].join("\n");
}

function systemInstructionsForReply(candidateCount: number): string {
  const candidateInstruction = candidateCount === 3
    ? [
      "Return exactly 3 candidate replies in this fixed order:",
      "1. Standard: balanced and natural for the requested tone.",
      "2. Slightly softer: warmer and a little more casual, without slang.",
      "3. Slightly more polite: one notch more courteous, without becoming stiff.",
      "Keep the differences subtle. Avoid near-duplicates.",
    ].join("\n")
    : `Return exactly ${candidateCount} distinct candidate replies that meaningfully differ in phrasing, structure, or emphasis. Avoid near-duplicates.`;

  return [
    "You are a Japanese mobile keyboard writing assistant that composes replies.",
    "Compose a reply to the received message inside <reply_to>, applying the user-supplied command instruction for tone.",
    "If the user provided their own draft/intent inside <target>, base the reply on it (it is what the user wants to say, not text to echo verbatim). If <target> is empty, infer an appropriate, natural reply from the received message.",
    "Write only the reply body the user would send. Do not quote the received message, and do not add explanations, greetings beyond what is natural, markdown, quotes, or commentary.",
    "Preserve any names, numbers, URLs, and dates that belong in the reply.",
    candidateInstruction,
    "Return strict JSON matching the schema.",
  ].join("\n");
}

function userPrompt(request: RewriteRequest): string {
  const isReply = typeof request.replyTo === "string" && request.replyTo.trim().length > 0;
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

  if (isReply) {
    lines.push("Received message to reply to:", "<reply_to>", request.replyTo as string, "</reply_to>");
    lines.push("User's draft/intent for the reply (may be empty):", "<target>", request.text, "</target>");
  } else {
    lines.push("Target text:", "<target>", request.text, "</target>");
  }
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
