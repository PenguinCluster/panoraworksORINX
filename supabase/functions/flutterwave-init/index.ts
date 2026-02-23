import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const APP_BASE_URL = Deno.env.get("APP_BASE_URL") ?? "http://127.0.0.1:7357";
const FW_SECRET = Deno.env.get("FLUTTERWAVE_SECRET_KEY") ?? "";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

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

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (!FW_SECRET) return json(500, { error: "Missing FLUTTERWAVE_SECRET_KEY secret" });
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) return json(500, { error: "Missing Supabase env" });

    // Create a Supabase client that uses the user's JWT from the request.
    const authHeader = req.headers.get("authorization") || "";
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    // Validate JWT by asking Supabase who the user is.
    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData?.user) {
      return json(401, { error: "Unauthorized: missing/invalid JWT" });
    }

    const user = userData.user;

    const {
      email,
      name,
      amount,
      plan_id,
      interval,
      billing_profile,
    } = await req.json();

    if (!email || !amount || !plan_id || !interval || !billing_profile) {
      return json(400, {
        error: "Missing fields: email, amount, plan_id, interval, billing_profile",
      });
    }

    // IMPORTANT: do NOT trust user_id from client.
    const user_id = user.id;

    const tx_ref = `orinx_${user_id}_${Date.now()}`;
    const redirect_url = `${APP_BASE_URL}/#/app/settings/billing`;

    const payload = {
      tx_ref,
      amount: Number(amount),
      currency: "USD",
      redirect_url,
      payment_options: "card",
      customer: {
        email,
        name: name ?? email.split("@")[0],
      },
      customizations: {
        title: "ORINX Subscription",
        description: `Plan ${plan_id} (${interval})`,
      },
      meta: {
        user_id,
        plan_id,
        interval,
        billing_profile: billing_profile ?? null,
      },
    };

    const res = await fetch("https://api.flutterwave.com/v3/payments", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${FW_SECRET}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const fwJson = await res.json();

    if (!res.ok || fwJson?.status !== "success") {
      console.error("Flutterwave init failed:", { status: res.status, fwJson });
      return json(400, { error: "Flutterwave init failed", details: fwJson });
    }

    return json(200, fwJson);
  } catch (e) {
    console.error("Edge Function Error:", e);
    return json(400, { error: String(e) });
  }
});
