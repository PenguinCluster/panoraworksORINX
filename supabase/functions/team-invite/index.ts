import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    const { email, role, team_id, is_admin_toggle } = await req.json();

    if (!email || !team_id) {
      throw new Error("Missing email or team_id");
    }

    // 1. Call the Database RPC to handle permissions, validation, and token generation
    const { data: rpcData, error: rpcError } = await supabaseClient.rpc(
      "send_team_invite",
      {
        invite_email: email,
        invite_team_id: team_id,
        invite_role: role || "manager",
        invite_is_admin_toggle: is_admin_toggle || false,
      }
    );

    if (rpcError) {
      console.error("RPC Error:", rpcError);
      return new Response(JSON.stringify({ error: rpcError.message }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    if (rpcData.error) {
       console.error("RPC Logic Error:", rpcData.error);
       return new Response(JSON.stringify({ error: rpcData.error }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const token = rpcData.token;
    const appBaseUrl = Deno.env.get("APP_BASE_URL") ?? "http://localhost:3000"; // Fallback or env
    const inviteLink = `${appBaseUrl}/#/join-team?token=${token}`;
    const resendApiKey = Deno.env.get("RESEND_API_KEY");

    if (!resendApiKey) {
      console.error("Missing RESEND_API_KEY");
      // We still return success for the invite creation, but warn about email
      return new Response(
        JSON.stringify({
          success: true,
          message: "Invite created but email failed (Missing API Key)",
          token: token, // Return token for debug/manual sharing
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    // 2. Send Email via Resend
    const emailRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify({
        from: "PanoraWorks <onboarding@resend.dev>", // Update with verified domain if available
        to: [email],
        subject: "Join the team on PanoraWorks",
        html: `
          <h1>You've been invited!</h1>
          <p>You have been invited to join the team on PanoraWorks.</p>
          <p>Click the link below to accept the invitation:</p>
          <a href="${inviteLink}">${inviteLink}</a>
          <p>This link will expire in 7 days.</p>
        `,
      }),
    });

    const emailData = await emailRes.json();

    if (!emailRes.ok) {
      console.error("Resend Error:", emailData);
      return new Response(
        JSON.stringify({
          success: true,
          message: "Invite created but email failed to send",
          token: token,
          emailError: emailData,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Invite sent successfully",
        token: token,
        emailId: emailData.id,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Edge Function Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
