import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ApiErrorCode =
  | "method_not_allowed"
  | "unauthorized"
  | "configuration_missing"
  | "deletion_failed";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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

  const { error } = await admin.auth.admin.deleteUser(userId);
  if (error) {
    console.error(JSON.stringify({
      event: "delete_account",
      userId,
      status: "error",
      message: error.message,
    }));
    return jsonError("deletion_failed", error.message, 500);
  }

  console.log(JSON.stringify({
    event: "delete_account",
    userId,
    status: "ok",
  }));
  return json({ ok: true });
});

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
