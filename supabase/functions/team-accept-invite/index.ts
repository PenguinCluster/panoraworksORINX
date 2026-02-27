import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeEmail(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    if (!SUPABASE_URL || !SERVICE_ROLE) {
      return json(500, { error: "Missing environment variables" });
    }

    const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE);
    const body = await req.json().catch(() => ({}));
    const token = String(body?.token ?? "").trim();
    const action = String(body?.action ?? "accept").trim().toLowerCase();

    if (!token) return json(400, { error: "Missing invite token" });

    // 1. Fetch the invite
    const { data: invite, error: inviteError } = await supabaseAdmin
      .from("team_invites")
      .select("*")
      .eq("token", token)
      .eq("status", "pending")
      .gt("expires_at", new Date().toISOString())
      .single();

    if (inviteError || !invite) {
      return json(400, { error: "Invalid, expired, or already used invite link." });
    }

    const inviteEmail = normalizeEmail(invite.email);

    // 2. Action: PREPARE (Used to show UI before accepting)
    if (action === "prepare") {
      return json(200, {
        success: true,
        email: inviteEmail,
        team_id: invite.team_id,
        role: invite.role,
      });
    }

    // 3. Action: ACCEPT (The actual join logic)
    if (action === "accept") {
      const authHeader = req.headers.get("Authorization") ?? req.headers.get("authorization") ?? "";
      if (!authHeader) return json(401, { error: "No authorization header provided" });

      const userClient = createClient(SUPABASE_URL, ANON_KEY);
      const { data: { user }, error: userError } = await userClient.auth.getUser(authHeader.replace("Bearer ", ""));

      if (userError || !user) {
        return json(401, { error: "Session invalid or expired", details: userError?.message });
      }

      const loggedInEmail = normalizeEmail(user.email);
      if (loggedInEmail !== inviteEmail) {
        return json(403, { 
          error: "Email mismatch", 
          message: `This invite is for ${inviteEmail}, but you are logged in as ${loggedInEmail}.` 
        });
      }

      // THE KEY FIX: We UPSERT into team_members. 
      // If they are already in a "ghost" workspace, this adds them to the NEW workspace.
      // We use the 'role' explicitly defined in the invite (manager/member).
      const { error: memberError } = await supabaseAdmin
        .from("team_members")
        .upsert({
          team_id: invite.team_id,
          user_id: user.id,
          email: inviteEmail,
          role: invite.role, // Fixes the RBAC Lock by using the intended role
          status: "active",
          invited_by: invite.invited_by,
          updated_at: new Date().toISOString(),
        }, { onConflict: "team_id,user_id" });

      if (memberError) {
        console.error("Upsert Error:", memberError);
        return json(500, { error: "Failed to join the team database record." });
      }

      // Mark the invite as accepted
      await supabaseAdmin
        .from("team_invites")
        .update({ 
          status: "accepted", 
          accepted_at: new Date().toISOString() 
        })
        .eq("id", invite.id);

      return json(200, { 
        success: true, 
        team_id: invite.team_id, 
        role: invite.role 
      });
    }

    return json(400, { error: "Invalid action" });

  } catch (e) {
    console.error("Critical Edge Function Error:", e);
    return json(500, { error: "Internal Server Error", details: e.message });
  }
});