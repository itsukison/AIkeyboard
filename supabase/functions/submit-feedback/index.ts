import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ApiErrorCode =
  | "method_not_allowed"
  | "unauthorized"
  | "invalid_body"
  | "configuration_missing"
  | "insert_failed";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const CATEGORIES: Record<string, string> = {
  bug: "バグ報告",
  request: "機能リクエスト",
  other: "その他",
};

const MAX_MESSAGE_LENGTH = 4000;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonError("method_not_allowed", "Use POST.", 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const userId = userIdFromAuthHeader(authHeader);
  if (!userId) {
    return jsonError("unauthorized", "Invalid session.", 401);
  }

  let body: { category?: unknown; message?: unknown; appVersion?: unknown };
  try {
    body = await req.json();
  } catch {
    return jsonError("invalid_body", "Body must be JSON.", 400);
  }

  const message = typeof body.message === "string" ? body.message.trim() : "";
  if (!message) {
    return jsonError("invalid_body", "Message is required.", 400);
  }
  if (message.length > MAX_MESSAGE_LENGTH) {
    return jsonError("invalid_body", "Message is too long.", 400);
  }

  const category = typeof body.category === "string" && body.category in CATEGORIES
    ? body.category
    : "other";
  const appVersion = typeof body.appVersion === "string"
    ? body.appVersion.slice(0, 64)
    : null;

  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) {
    return jsonError(
      "configuration_missing",
      "Service role is not configured.",
      503,
    );
  }

  const admin = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData } = await admin.auth.admin.getUserById(userId);
  const userEmail = userData?.user?.email ?? null;

  const { error } = await admin.from("feedback").insert({
    user_id: userId,
    category,
    message,
    app_version: appVersion,
    user_email: userEmail,
  });
  if (error) {
    console.error(JSON.stringify({
      event: "submit_feedback",
      userId,
      status: "error",
      message: error.message,
    }));
    return jsonError("insert_failed", error.message, 500);
  }

  await notifyByEmail({ category, message, appVersion, userEmail });

  console.log(JSON.stringify({
    event: "submit_feedback",
    userId,
    category,
    status: "ok",
  }));
  return json({ ok: true });
});

async function notifyByEmail(input: {
  category: string;
  message: string;
  appVersion: string | null;
  userEmail: string | null;
}): Promise<void> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) return; // Email is best-effort; the row is already saved.

  const to = Deno.env.get("FEEDBACK_NOTIFY_EMAIL") ?? "itsukison00@gmail.com";
  const from = Deno.env.get("FEEDBACK_FROM_EMAIL") ??
    "敬語ボタン <onboarding@resend.dev>";
  const categoryLabel = CATEGORIES[input.category] ?? input.category;

  const lines = [
    `カテゴリ: ${categoryLabel}`,
    `送信者: ${input.userEmail ?? "(不明)"}`,
    `アプリ: ${input.appVersion ?? "(不明)"}`,
    "",
    input.message,
  ];

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to,
        reply_to: input.userEmail ?? undefined,
        subject: `【敬語ボタン】${categoryLabel}`,
        text: lines.join("\n"),
      }),
    });
    if (!res.ok) {
      console.error(JSON.stringify({
        event: "submit_feedback_email",
        status: "error",
        httpStatus: res.status,
      }));
    }
  } catch (err) {
    console.error(JSON.stringify({
      event: "submit_feedback_email",
      status: "error",
      message: err instanceof Error ? err.message : String(err),
    }));
  }
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
