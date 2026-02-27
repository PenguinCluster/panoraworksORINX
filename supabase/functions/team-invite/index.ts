import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Helper for CORS headers
function corsHeaders(req: Request) {
  const origin = req.headers.get("origin") ?? "";
  const allowOrigin = origin.length > 0 ? origin : "*";
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Vary": "Origin",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}

// Helper for JSON responses
function json(status: number, body: Record<string, unknown>, headers: HeadersInit) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}

// Build the nested redirect URL correctly
function buildRedirectTo(appBaseUrl: string, inviteToken: string): string {
  // 1. Final destination (Flutter Join Team screen)
  const finalDest = `/join-team?token=${inviteToken}`;
  
  // 2. Intermediate (Set Password screen) - Encode finalDest
  const setPasswordPath = `/set-password?next=${encodeURIComponent(finalDest)}`;
  
  // 3. Entry point (Auth Callback) - Encode setPasswordPath
  return `${appBaseUrl}/auth/callback?next=${encodeURIComponent(setPasswordPath)}`;
}

function isAlreadyInvitedOrExistsError(message: string) {
  const m = (message || "").toLowerCase();
  return (
    m.includes("already registered") ||
    m.includes("already been registered") ||
    m.includes("user already registered") ||
    m.includes("already exists") ||
    m.includes("already invited") ||
    m.includes("user already invited") ||
    m.includes("err_already_in_workspace") ||
    m.includes("err_already_owner")
  );
}

serve(async (req) => {
  const CORS = corsHeaders(req);

  // 1) Handle Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const APP_BASE_URL = Deno.env.get("APP_BASE_URL") ?? "http://127.0.0.1:7357";
    
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json(500, { error: "Missing Supabase environment variables" }, CORS);
    }

    // 2) Extract bearer token
    const authHeader = req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : authHeader;

    if (!token) return json(401, { error: "Missing Authorization bearer token" }, CORS);

    // 3) Verify the owner's token
    const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: userData, error: userErr } = await authClient.auth.getUser(token);
    if (userErr || !userData?.user) {
      return json(401, { error: "Invalid JWT", details: userErr?.message }, CORS);
    }

    // 4) Parse request body
    const body = await req.json().catch(() => ({}));
    const email = (body as any)?.email?.toString()?.trim();
    const role = ((body as any)?.role?.toString() || "manager").trim();
    const team_id = (body as any)?.team_id?.toString();
    const is_admin_toggle = !!(body as any)?.is_admin_toggle;

    if (!email || !team_id) {
      return json(400, { error: "Missing email or team_id" }, CORS);
    }

    // Admin client for restricted actions
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // 5) Update Team Invites Table via RPC
    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: rpcData, error: rpcError } = await supabaseUser.rpc("send_team_invite", {
      invite_email: email,
      invite_team_id: team_id,
      invite_role: role,
      invite_is_admin_toggle: is_admin_toggle,
    });

    if (rpcError) {
      const errMsg = rpcError.message;
      if (errMsg.includes("already a member")) {
        return json(409, { error: "User is already a team member" }, CORS);
      }
      return json(400, { error: errMsg || "Database invite failed" }, CORS);
    }

    const teamInviteToken = (rpcData as any)?.token;
    if (!teamInviteToken) {
      return json(500, { error: "RPC did not return invite token" }, CORS);
    }

    // 6) Trigger Supabase Auth Invite
    const redirectTo = buildRedirectTo(APP_BASE_URL, teamInviteToken);
    
    const { data: inviteAuthData, error: inviteAuthError } = await supabaseAdmin.auth.admin.inviteUserByEmail(email, {
      redirectTo: redirectTo,
      data: {
        invited_to_team_id: team_id,
        invited_role: role,
        skip_default_team: true,
      }
    });

    if (inviteAuthError) {
      const errorMsg = inviteAuthError.message || "";
      
      if (errorMsg.includes("ERR_ALREADY_OWNER")) {
        return json(400, { error: "User already has an account." }, CORS);
      }
      
      if (isAlreadyInvitedOrExistsError(errorMsg)) {
        return json(200, { 
          success: true, 
          message: "User already exists. They can log in to see the invite.",
          token: teamInviteToken 
        }, CORS);
      }
      
      return json(500, { error: "Auth invite failed", details: errorMsg }, CORS);
    }

    // Success
    return json(200, { 
      success: true, 
      message: "Invite sent successfully via Supabase Auth.",
      token: teamInviteToken 
    }, CORS);

  } catch (err) {
    console.error("team-invite error:", err);
    // FIXED: Corrected corsHeaders(req) call
    return json(500, { error: String((err as any)?.message ?? err) }, corsHeaders(req));
  }
});