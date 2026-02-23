import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

function json(status: number, body: Record<string, unknown>, headers: HeadersInit) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}

function normalizeEmail(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

serve(async (req) => {
  const CORS = corsHeaders(req);

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    
    if (!SUPABASE_URL || !SERVICE_ROLE || !ANON_KEY) {
      return json(500, { error: "Missing Supabase environment variables" }, CORS);
    }

    const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const body = await req.json().catch(() => ({}));
    const token = String((body as any)?.token ?? "").trim();
    const action = String((body as any)?.action ?? "accept").trim().toLowerCase();

    if (!token) return json(400, { error: "Missing token" }, CORS);

    // 1) Validate invite token
    const { data: invite, error: inviteError } = await supabaseAdmin
      .from("team_invites")
      .select("*")
      .eq("token", token)
      .eq("status", "pending")
      .gt("expires_at", new Date().toISOString())
      .single();

    if (inviteError || !invite) {
      return json(
        400,
        { error: "Invalid or expired token", details: inviteError?.message ?? null },
        CORS,
      );
    }

    const inviteEmail = normalizeEmail(invite.email);

    // 2) PREPARE: return invite metadata
    if (action === "prepare") {
      return json(
        200,
        {
          success: true,
          email: inviteEmail,
          team_id: invite.team_id,
          role: invite.role,
        },
        CORS,
      );
    }

    // 3) ACCEPT: requires logged-in user via Authorization header
    if (action === "accept") {
      const authHeader = req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";

      if (!authHeader) {
        return json(401, { error: "Missing Authorization header" }, CORS);
      }

      const bearer = authHeader.startsWith("Bearer ")
        ? authHeader.slice(7).trim()
        : authHeader.trim();

      if (!bearer) {
        return json(401, { error: "Missing bearer token in Authorization header" }, CORS);
      }

      const userClient = createClient(SUPABASE_URL, ANON_KEY, {
        auth: { autoRefreshToken: false, persistSession: false },
      });

      // Explicit token verification (more reliable than relying on global header binding)
      const { data: userData, error: userError } = await userClient.auth.getUser(bearer);
      const user = userData?.user;

      if (userError || !user) {
        return json(401, { error: "Invalid JWT: Token expired or invalid", details: userError?.message ?? null }, CORS);
      }

      const loggedInEmail = normalizeEmail(user.email);
      if (loggedInEmail !== inviteEmail) {
        return json(
          403,
          {
            error: "Email mismatch",
            message: `This invite is for ${inviteEmail}, but you are logged in as ${loggedInEmail}. Please sign out and log in with the correct account.`,
            details: {
              inviteEmail,
              loggedInEmail,
            },
          },
          CORS,
        );
      }

      // ✅ Single-team rule (by user_id)
      const { data: existingActive, error: existingActiveError } = await supabaseAdmin
        .from("team_members")
        .select("team_id")
        .eq("user_id", user.id)
        .eq("status", "active")
        .maybeSingle();

      if (existingActiveError) {
        console.error("existingActive check error:", existingActiveError);
        return json(
          500,
          { error: "Database error checking membership", details: existingActiveError.message },
          CORS,
        );
      }

      if (existingActive?.team_id && existingActive.team_id !== invite.team_id) {
        return json(409, { error: "User is already active in another team" }, CORS);
      }

      // Activate membership (team_members should store ACTIVE memberships only)
      const { error: memberError } = await supabaseAdmin
        .from("team_members")
        .upsert(
          {
            team_id: invite.team_id,
            user_id: user.id,
            email: inviteEmail,
            role: invite.role,
            status: "active",
            invited_by: invite.invited_by,
            updated_at: new Date().toISOString(),
          },
          { onConflict: "team_id,email" },
        );

      if (memberError) {
        console.error("Member upsert error:", memberError);
        return json(
          500,
          { error: "Failed to activate membership", details: memberError.message },
          CORS,
        );
      }

      // Mark invite accepted
      const { error: inviteUpdateError } = await supabaseAdmin
        .from("team_invites")
        .update({
          status: "accepted",
          accepted_at: new Date().toISOString(),
        })
        .eq("id", invite.id);

      if (inviteUpdateError) {
        console.error("Invite status update error:", inviteUpdateError);
        // Fallback if accepted_at column missing
        if ((inviteUpdateError.message ?? "").toLowerCase().includes("accepted_at")) {
             await supabaseAdmin.from("team_invites").update({ status: "accepted" }).eq("id", invite.id);
        }
      }

      return json(
        200,
        {
          success: true,
          team_id: invite.team_id,
          role: invite.role,
          email: inviteEmail,
        },
        CORS,
      );
    }

    return json(400, { error: "Invalid action. Use 'prepare' or 'accept'." }, CORS);
  } catch (e) {
    console.error("team-accept-invite unhandled error:", e);
    return json(500, { error: "Internal Server Error" }, corsHeaders(req));
  }
});
