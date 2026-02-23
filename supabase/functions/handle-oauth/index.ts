import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const APP_BASE_URL = Deno.env.get("APP_BASE_URL") ?? "http://127.0.0.1:7357";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": APP_BASE_URL,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json(500, { error: "Missing Supabase env vars" });
    }

    const authHeader = req.headers.get("authorization");
    if (!authHeader) return json(401, { error: "Missing Authorization header" });

    // 1) Validate the caller (JWT)
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json(401, { error: "Invalid JWT" });
    }

    const user = userData.user;

    // 2) Parse request
    const { provider, access_token, refresh_token, expires_in } = await req.json();

    if (!provider || !access_token || !expires_in) {
      return json(400, { error: "Missing fields: provider, access_token, expires_in" });
    }

    const expiresAt = new Date(Date.now() + Number(expires_in) * 1000).toISOString();

    // 3) Use service role to update secure tokens column
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { error } = await supabaseAdmin.rpc("update_connected_account", {
      p_user_id: user.id, // ✅ from JWT, not from request body
      p_provider: provider,
      p_status: "connected",
      p_tokens: { access_token, refresh_token },
      p_expires_at: expiresAt,
    });

    if (error) return json(400, { error: error.message });

    return json(200, { success: true });
  } catch (e) {
    console.error("handle-oauth error:", e);
    return json(500, { error: String(e?.message ?? e) });
  }
});
