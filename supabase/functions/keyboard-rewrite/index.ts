import { redactPII } from "./redact.ts";

type RefinementIntent = "morePolite" | "moreDetailed" | "moreConcise";

type ConsentScope =
  | "none"
  | "internal_improvement"
  | "research_benchmark"
  | "commercial_dataset";

type ConsentState = {
  optIn: boolean;
  scope: ConsentScope;
  rawAllowed: boolean;
  version: string | null;
};

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
  analyticsAppInstanceId?: string;
  // Selection mode: `text` is a fragment the user highlighted inside a larger
  // text. The context fields are prompt-only — never log or store them.
  selection?: boolean;
  selectionContextBefore?: string;
  selectionContextAfter?: string;
};

type RewriteCandidate = {
  replacement: string;
  changed: boolean;
};

type RewriteResult = {
  candidates: RewriteCandidate[];
  language: "ja" | "en" | "ko" | "zh" | "mixed";
};

type ProviderName = "azure" | "cerebras" | "groq";

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

// Stamps the consent version on stored rows so exports tie to the policy
// revision in force. Retention is opt-in (see logRewriteEvent).
const DEFAULT_CONSENT_VERSION = "2026-07-02";

// PostHog ingestion. The project token is the same public client key shipped in
// the container app binary (safe to expose); override with the
// POSTHOG_PROJECT_TOKEN secret. Analytics are emitted here, on the server —
// never from the keyboard extension (memory ceiling + no-network-in-typing-path).
const POSTHOG_PROJECT_TOKEN_DEFAULT = "phc_rkuAvbqxdVqqG5jZuySrJq8CH4NrYG97Z2B7vv7GXhJw";
const POSTHOG_HOST_DEFAULT = "https://us.i.posthog.com";
const GA_FIREBASE_APP_ID_DEFAULT = "1:6299557478:ios:07929a5061fe07dda997a7";

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

  if (isActionEvent(body)) {
    return await handleActionEvent(userId, body);
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
  if (request.selectionContextBefore && [...request.selectionContextBefore].length > maxChars) {
    return jsonError("text_too_long", "Text is too long.", 413);
  }
  if (request.selectionContextAfter && [...request.selectionContextAfter].length > maxChars) {
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
    (globalThis as any).EdgeRuntime?.waitUntil(Promise.all([
      logRewriteEvent(eventId, {
        userId,
        request,
        result,
        provider: rewrite.provider,
        latencyMs,
      }),
      captureRewriteAnalytics(eventId, {
        userId,
        request,
        result,
        provider: rewrite.provider,
        latencyMs,
      }),
    ]));
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
  const analyticsAppInstanceId = optionalAnalyticsAppInstanceId(data.analyticsAppInstanceId);
  const selection = data.selection === true;
  const selectionContextBefore = data.selectionContextBefore;
  const selectionContextAfter = data.selectionContextAfter;

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
      analyticsAppInstanceId,
      selection,
      selectionContextBefore: selection && typeof selectionContextBefore === "string" && selectionContextBefore.length > 0
        ? selectionContextBefore
        : undefined,
      selectionContextAfter: selection && typeof selectionContextAfter === "string" && selectionContextAfter.length > 0
        ? selectionContextAfter
        : undefined,
    },
  };
}

type FeedbackEvent = {
  eventId: string;
  selectedIndex: number;
  analyticsAppInstanceId?: string;
};

function isFeedbackRequest(body: unknown): body is FeedbackEvent {
  if (!body || typeof body !== "object") return false;
  const data = body as Record<string, unknown>;
  return typeof data.eventId === "string" && typeof data.selectedIndex === "number";
}

// Records which candidate the user accepted, turning a logged rewrite into a
// labeled (input, chosen) preference example. Scoped by user_id so a caller can
// only annotate their own events. Best-effort: the client does not block on it.
async function handleFeedback(
  userId: string,
  body: FeedbackEvent,
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

  // deno-lint-ignore no-explicit-any
  (globalThis as any).EdgeRuntime?.waitUntil(
    captureFeedbackAnalytics(
      userId,
      eventId,
      selectedIndex,
      optionalAnalyticsAppInstanceId(body.analyticsAppInstanceId),
    ),
  );
  return json({ ok: true });
}

const ACTION_TYPES = new Set([
  "selected",
  "inserted",
  "copied",
  "dismissed",
  "regenerated",
  "replace_failed",
]);

type ActionEvent = {
  eventId: string;
  action: string;
  selectedIndex?: number;
  latencyMs?: number;
  analyticsAppInstanceId?: string;
};

function isActionEvent(body: unknown): body is ActionEvent {
  if (!body || typeof body !== "object") return false;
  const data = body as Record<string, unknown>;
  return typeof data.eventId === "string" && typeof data.action === "string";
}

// Records a user action on a rewrite result (regenerated / dismissed / …) in
// the append-only ai_rewrite_action_events log, keyed by the originating
// event_id. Best-effort: the keyboard fires it detached and never blocks on it.
async function handleActionEvent(
  userId: string,
  body: ActionEvent,
): Promise<Response> {
  if ((Deno.env.get("EVENT_LOGGING_ENABLED") ?? "true") === "false") {
    return json({ ok: true });
  }
  const eventId = body.eventId.trim();
  if (!/^[0-9a-fA-F-]{36}$/.test(eventId) || !ACTION_TYPES.has(body.action)) {
    return jsonError("invalid_request", "Invalid action event.", 400);
  }
  const selectedIndex = typeof body.selectedIndex === "number" &&
      Number.isFinite(body.selectedIndex) && body.selectedIndex >= 0
    ? Math.floor(body.selectedIndex)
    : null;
  const latencyMs = typeof body.latencyMs === "number" &&
      Number.isFinite(body.latencyMs) && body.latencyMs >= 0
    ? Math.floor(body.latencyMs)
    : null;

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !serviceRoleKey) {
    return jsonError("configuration_missing", "Action logging is not configured.", 503);
  }

  try {
    const response = await fetch(`${supabaseURL}/rest/v1/ai_rewrite_action_events`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${serviceRoleKey}`,
        "apikey": serviceRoleKey,
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
      },
      body: JSON.stringify({
        event_id: eventId,
        user_id: userId,
        user_id_hash: await hashUserId(userId),
        action: body.action,
        selected_index: selectedIndex,
        latency_ms: latencyMs,
      }),
    });
    if (!response.ok) {
      console.error(JSON.stringify({
        event: "ai_rewrite_action_log_failed",
        httpStatus: response.status,
        message: (await response.text()).slice(0, 400),
      }));
      return jsonError("provider_error", "Failed to record action.", 502);
    }
  } catch (error) {
    console.error(JSON.stringify({
      event: "ai_rewrite_action_log_failed",
      message: error instanceof Error ? error.message : "unknown error",
    }));
    return jsonError("provider_error", "Failed to record action.", 502);
  }

  // deno-lint-ignore no-explicit-any
  (globalThis as any).EdgeRuntime?.waitUntil(Promise.all([
    capturePostHogEvent("ai_rewrite_action", userId, {
      event_id: eventId,
      action: body.action,
      selected_index: selectedIndex,
      latency_ms: latencyMs,
    }),
    captureGoogleAnalyticsEvent(
      "ai_rewrite_action",
      userId,
      optionalAnalyticsAppInstanceId(body.analyticsAppInstanceId),
      {
        event_id: eventId,
        action: body.action,
        selected_index: selectedIndex,
        latency_ms: latencyMs,
      },
    ),
  ]));
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

  // Fail closed: retention is opt-in. Text is stored only when the user has an
  // explicit opt-in record (scope commercial_dataset / research_benchmark).
  // Absent record or opt_in false == metadata only. Raw text further requires
  // raw_text_allowed.
  const consent = await fetchConsent(supabaseURL, serviceRoleKey, input.userId);
  const scope: ConsentScope = consent?.optIn ? consent.scope : "none";
  const eligible = scope !== "none";

  // Metadata is always stored (product analytics + the eventId feedback join).
  const payload: Record<string, unknown> = {
    language: input.result.language,
    command_key: input.request.commandKey ?? null,
    title: input.request.title ?? null,
    refinement: input.request.refinement ?? null,
    locale: input.request.locale ?? null,
    app_version: input.request.appVersion ?? null,
    candidate_count: input.request.candidateCount ?? DEFAULT_CANDIDATES,
    provider: input.provider,
    is_reply: typeof input.request.replyTo === "string" &&
      input.request.replyTo.trim().length > 0,
    // Selection mode: lengths only. The context text itself is prompt-only and
    // must never be stored, in any consent branch — promised in the privacy doc.
    is_selection: input.request.selection === true,
    selection_context_before_length: input.request.selectionContextBefore
      ? [...input.request.selectionContextBefore].length
      : 0,
    selection_context_after_length: input.request.selectionContextAfter
      ? [...input.request.selectionContextAfter].length
      : 0,
    input_length: [...input.request.text].length,
    prompt_length: [...input.request.prompt].length,
    output_length: input.result.candidates.reduce(
      (sum, c) => sum + [...c.replacement].length,
      0,
    ),
    latency_ms: input.latencyMs,
  };

  // Text is only added for consented scopes, always PII-redacted first. Raw
  // text is stored only if the user separately allowed it (raw_text_allowed).
  // candidates[] keeps the model order (no display randomization in v1), so the
  // selected candidate is derivable from selected_index at export time.
  if (eligible) {
    payload.prompt_redacted = redactPII(input.request.prompt);
    payload.input_redacted = redactPII(input.request.text);
    payload.reply_to_redacted = input.request.replyTo
      ? redactPII(input.request.replyTo)
      : null;
    payload.candidates = input.result.candidates.map((c) => ({
      text_redacted: redactPII(c.replacement),
      changed: c.changed,
    }));
    if (consent?.rawAllowed) {
      payload.prompt_raw = input.request.prompt;
      payload.input_raw = input.request.text;
      payload.reply_to_raw = input.request.replyTo ?? null;
      payload.candidates_raw = input.result.candidates;
    }
  }

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
        user_id_hash: await hashUserId(input.userId),
        data_use_scope: scope,
        consent_version: eligible ? consent?.version ?? DEFAULT_CONSENT_VERSION : null,
        dataset_eligible: eligible,
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

// Reads the user's retention consent (authoritative, server-side). Any failure
// or missing row returns null, which the caller treats as no consent — fail
// closed, never store raw text on uncertainty.
async function fetchConsent(
  supabaseURL: string,
  serviceRoleKey: string,
  userId: string,
): Promise<ConsentState | null> {
  const validScopes: ConsentScope[] = [
    "none",
    "internal_improvement",
    "research_benchmark",
    "commercial_dataset",
  ];
  try {
    const response = await fetch(
      `${supabaseURL}/rest/v1/user_ai_consent?user_id=eq.${userId}` +
        `&select=ai_improvement_opt_in,data_use_scope,raw_text_allowed,consent_version`,
      {
        headers: {
          "Authorization": `Bearer ${serviceRoleKey}`,
          "apikey": serviceRoleKey,
        },
      },
    );
    if (!response.ok) return null;
    const rows = await response.json();
    const row = Array.isArray(rows) ? rows[0] : null;
    if (!row) return null;
    const scope = validScopes.includes(row.data_use_scope)
      ? row.data_use_scope as ConsentScope
      : "none";
    return {
      optIn: row.ai_improvement_opt_in === true,
      scope,
      rawAllowed: row.raw_text_allowed === true,
      version: typeof row.consent_version === "string" ? row.consent_version : null,
    };
  } catch {
    return null;
  }
}

// Pseudonymous, unlinkable user id for exported datasets. HMAC-SHA256 of the
// Supabase user id under a server-only pepper; exports use this, never user_id.
// Returns null if the pepper is unset (the column stays empty rather than
// leaking a reversible hash).
async function hashUserId(userId: string): Promise<string | null> {
  const pepper = Deno.env.get("USER_ID_HASH_PEPPER");
  if (!pepper) return null;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(pepper),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(userId),
  );
  return [...new Uint8Array(signature)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Mirrors each AI rewrite into product analytics so dashboards can chart usage
// and count active users. Server-side by design — the
// keyboard extension must never emit analytics. `distinct_id` is the Supabase
// user id, which is the same id the container app calls PostHog `identify` with,
// so these events unify onto the same person. Metadata only: no user text leaves
// here (the text stays in ai_rewrite_events).
async function captureRewriteAnalytics(
  eventId: string,
  input: {
    userId: string;
    request: RewriteRequest;
    result: RewriteResult;
    provider: ProviderName;
    latencyMs: number;
  },
): Promise<void> {
  const properties = {
    event_id: eventId,
    command_key: input.request.commandKey ?? null,
    title: input.request.title ?? null,
    refinement: input.request.refinement ?? null,
    provider: input.provider,
    language: input.result.language,
    locale: input.request.locale ?? null,
    app_version: input.request.appVersion ?? null,
    is_reply: typeof input.request.replyTo === "string" &&
      input.request.replyTo.trim().length > 0,
    candidate_count: input.result.candidates.length,
    input_length: [...input.request.text].length,
    prompt_length: [...input.request.prompt].length,
    output_length: input.result.candidates.reduce(
      (sum, c) => sum + [...c.replacement].length,
      0,
    ),
    latency_ms: input.latencyMs,
  };
  await Promise.all([
    capturePostHogEvent("ai_rewrite", input.userId, properties),
    captureGoogleAnalyticsEvent(
      "ai_rewrite",
      input.userId,
      input.request.analyticsAppInstanceId,
      properties,
    ),
  ]);
}

// Records the accepted candidate as `ai_rewrite_accepted`, keyed by the
// originating event_id, so analytics can compute the rewrite acceptance rate.
async function captureFeedbackAnalytics(
  userId: string,
  eventId: string,
  selectedIndex: number,
  analyticsAppInstanceId?: string,
): Promise<void> {
  const properties = {
    event_id: eventId,
    selected_index: selectedIndex,
  };
  await Promise.all([
    capturePostHogEvent("ai_rewrite_accepted", userId, properties),
    captureGoogleAnalyticsEvent(
      "ai_rewrite_accepted",
      userId,
      analyticsAppInstanceId,
      properties,
    ),
  ]);
}

async function capturePostHogEvent(
  event: string,
  distinctId: string,
  properties: Record<string, unknown>,
): Promise<void> {
  if ((Deno.env.get("POSTHOG_ANALYTICS_ENABLED") ?? "true") === "false") {
    return;
  }
  const token = Deno.env.get("POSTHOG_PROJECT_TOKEN") ?? POSTHOG_PROJECT_TOKEN_DEFAULT;
  const host = (Deno.env.get("POSTHOG_HOST") ?? POSTHOG_HOST_DEFAULT).replace(/\/+$/, "");
  if (!token) return;

  try {
    const response = await fetch(`${host}/capture/`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        api_key: token,
        event,
        distinct_id: distinctId,
        properties: { ...properties, $lib: "keyboard-rewrite-edge" },
      }),
    });
    if (!response.ok) {
      console.error(JSON.stringify({
        event: "posthog_capture_failed",
        name: event,
        httpStatus: response.status,
        message: (await response.text()).slice(0, 400),
      }));
    }
  } catch (error) {
    console.error(JSON.stringify({
      event: "posthog_capture_failed",
      name: event,
      message: error instanceof Error ? error.message : "unknown error",
    }));
  }
}

async function captureGoogleAnalyticsEvent(
  event: string,
  userId: string,
  appInstanceId: string | undefined,
  properties: Record<string, unknown>,
): Promise<void> {
  if (!appInstanceId || (Deno.env.get("GA_ANALYTICS_ENABLED") ?? "true") === "false") {
    return;
  }
  const apiSecret = Deno.env.get("GA_MEASUREMENT_PROTOCOL_API_SECRET");
  const firebaseAppId = Deno.env.get("GA_FIREBASE_APP_ID") ?? GA_FIREBASE_APP_ID_DEFAULT;
  if (!apiSecret || !firebaseAppId) return;

  const query = new URLSearchParams({
    firebase_app_id: firebaseAppId,
    api_secret: apiSecret,
  });
  try {
    const response = await fetch(`https://www.google-analytics.com/mp/collect?${query}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        app_instance_id: appInstanceId,
        user_id: userId,
        events: [{
          name: event,
          params: {
            ...googleAnalyticsParameters(properties),
            // Without engagement_time_msec, GA4 records the event but does
            // not mark the user active, so retention/DAU miss keyboard-only
            // users.
            engagement_time_msec: 100,
          },
        }],
      }),
    });
    if (!response.ok) {
      console.error(JSON.stringify({
        event: "google_analytics_capture_failed",
        name: event,
        httpStatus: response.status,
        message: (await response.text()).slice(0, 400),
      }));
    }
  } catch (error) {
    console.error(JSON.stringify({
      event: "google_analytics_capture_failed",
      name: event,
      message: error instanceof Error ? error.message : "unknown error",
    }));
  }
}

function googleAnalyticsParameters(
  properties: Record<string, unknown>,
): Record<string, string | number> {
  const parameters: Record<string, string | number> = {};
  for (const [key, value] of Object.entries(properties)) {
    if (key === "title" || value === null || value === undefined) continue;
    if (typeof value === "string") {
      parameters[key] = [...value].slice(0, 100).join("");
    } else if (typeof value === "number" && Number.isFinite(value)) {
      parameters[key] = value;
    } else if (typeof value === "boolean") {
      parameters[key] = value ? 1 : 0;
    }
  }
  return parameters;
}

function optionalAnalyticsAppInstanceId(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const identifier = value.trim();
  return identifier.length > 0 && identifier.length <= 100 ? identifier : undefined;
}

const ALL_PROVIDERS: ProviderName[] = ["azure", "cerebras", "groq"];

function providerHasKey(provider: ProviderName): boolean {
  switch (provider) {
    case "azure":
      return !!Deno.env.get("AZURE_OPENAI_API_KEY") && !!Deno.env.get("AZURE_OPENAI_ENDPOINT");
    case "cerebras":
      return !!Deno.env.get("CEREBRAS_API_KEY");
    case "groq":
      return !!Deno.env.get("GROQ_API_KEY");
  }
}

function configuredProviders(): ProviderName[] {
  const requested = Deno.env.get("REWRITE_PROVIDER");
  const primary: ProviderName = requested === "azure"
    ? "azure"
    : requested === "groq"
    ? "groq"
    : "cerebras";
  const fallbackEnabled = (Deno.env.get("REWRITE_PROVIDER_FALLBACK") ?? "true") !== "false";
  const ordered: ProviderName[] = [primary, ...ALL_PROVIDERS.filter((p) => p !== primary)];
  return ordered.filter((provider, index) => {
    if (index > 0 && !fallbackEnabled) return false;
    return providerHasKey(provider);
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

type ProviderConfig = {
  apiKey: string | undefined;
  model: string;
  endpoint: string;
  authHeaders: Record<string, string>;
  timeoutMs: number;
  baseTokens: number;
  reasoningEffort: string | undefined;
};

// Azure OpenAI differs from the OpenAI-shaped Cerebras/Groq endpoints in two
// ways: the deployment name lives in the URL path (not the request body) and
// auth is the `api-key` header, not `Authorization: Bearer`. The api-version is
// a secret so it can be bumped without a redeploy if a model needs a newer one.
function resolveProviderConfig(provider: ProviderName): ProviderConfig {
  if (provider === "azure") {
    const base = (Deno.env.get("AZURE_OPENAI_ENDPOINT") ?? "").replace(/\/+$/, "");
    const deployment = Deno.env.get("AZURE_OPENAI_DEPLOYMENT") ?? "gpt-4.1";
    const apiVersion = Deno.env.get("AZURE_OPENAI_API_VERSION") ?? "2025-04-01-preview";
    const apiKey = Deno.env.get("AZURE_OPENAI_API_KEY");
    return {
      apiKey,
      model: deployment,
      endpoint: `${base}/openai/deployments/${deployment}/chat/completions?api-version=${apiVersion}`,
      authHeaders: { "api-key": apiKey ?? "" },
      timeoutMs: envInt("AZURE_TIMEOUT_MS", 12000),
      baseTokens: envInt("AZURE_MAX_OUTPUT_TOKENS", 600),
      reasoningEffort: Deno.env.get("AZURE_REASONING_EFFORT") || undefined,
    };
  }
  if (provider === "cerebras") {
    const apiKey = Deno.env.get("CEREBRAS_API_KEY");
    return {
      apiKey,
      model: Deno.env.get("CEREBRAS_MODEL") ?? "gpt-oss-120b",
      endpoint: Deno.env.get("CEREBRAS_CHAT_COMPLETIONS_URL") ?? "https://api.cerebras.ai/v1/chat/completions",
      authHeaders: { "Authorization": `Bearer ${apiKey ?? ""}` },
      timeoutMs: envInt("CEREBRAS_TIMEOUT_MS", 8000),
      baseTokens: envInt("CEREBRAS_MAX_OUTPUT_TOKENS", 600),
      reasoningEffort: Deno.env.get("CEREBRAS_REASONING_EFFORT") || undefined,
    };
  }
  const apiKey = Deno.env.get("GROQ_API_KEY");
  return {
    apiKey,
    model: Deno.env.get("GROQ_MODEL") ?? "openai/gpt-oss-120b",
    endpoint: Deno.env.get("GROQ_CHAT_COMPLETIONS_URL") ?? "https://api.groq.com/openai/v1/chat/completions",
    authHeaders: { "Authorization": `Bearer ${apiKey ?? ""}` },
    timeoutMs: envInt("GROQ_TIMEOUT_MS", 8000),
    baseTokens: envInt("GROQ_MAX_OUTPUT_TOKENS", 600),
    reasoningEffort: Deno.env.get("GROQ_REASONING_EFFORT") || undefined,
  };
}

async function rewriteWithProvider(
  provider: ProviderName,
  request: RewriteRequest,
): Promise<RewriteResult> {
  const config = resolveProviderConfig(provider);
  if (!config.apiKey) {
    throw new ProviderError(
      provider,
      "provider_error",
      "AIの設定が不足しています。",
      `${provider} API key is not configured.`,
    );
  }

  const candidateCount = request.candidateCount ?? DEFAULT_CANDIDATES;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.timeoutMs);

  const maxCompletionTokens = config.baseTokens * candidateCount;
  const reasoningEffort = config.reasoningEffort;

  const isReply = typeof request.replyTo === "string" && request.replyTo.trim().length > 0;
  const body: Record<string, unknown> = {
    model: config.model,
    messages: [
      {
        role: "system",
        content: isReply
          ? systemInstructionsForReply(candidateCount)
          : request.selection
          ? systemInstructionsForSelection(candidateCount)
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

  let response: Response;
  try {
    response = await fetch(config.endpoint, {
      method: "POST",
      signal: controller.signal,
      headers: {
        ...config.authHeaders,
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
    "Preserve meaning, names, numbers, URLs, dates, and emoji. Preserve line breaks unless the command explicitly asks to restructure or format the text.",
    "Do not add explanations, markdown, quotes, commentary, or unsupported facts. Add greetings or closings only when the command explicitly requests them.",
    candidateInstruction,
    "Return strict JSON matching the schema.",
  ].join("\n");
}

function systemInstructionsForSelection(candidateCount: number): string {
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
    "The target text is a fragment the user selected inside a larger text. Apply the user-supplied command instruction to the fragment only.",
    "Rewrite the fragment so it fits seamlessly where it stands: match its grammatical role, and continue naturally from <context_before> into <context_after> when they are provided. The fragment may start or end mid-sentence — keep it that way.",
    "Never rewrite, repeat, or complete the surrounding context. Never add greetings, closings, or sentence endings that belong to the surrounding text.",
    "Preserve meaning, names, numbers, URLs, dates, and emoji. Preserve line breaks unless the command explicitly asks to restructure or format the text.",
    "Do not add explanations, markdown, quotes, commentary, or unsupported facts.",
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
  } else if (request.selection) {
    if (request.selectionContextBefore) {
      lines.push("Text immediately before the fragment (do not rewrite):", "<context_before>", request.selectionContextBefore, "</context_before>");
    }
    if (request.selectionContextAfter) {
      lines.push("Text immediately after the fragment (do not rewrite):", "<context_after>", request.selectionContextAfter, "</context_after>");
    }
    lines.push("Target fragment (selected inside a larger text):", "<target>", request.text, "</target>");
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
