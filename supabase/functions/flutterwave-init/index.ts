import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const FLUTTERWAVE_CLIENT_ID = Deno.env.get("FLUTTERWAVE_CLIENT_ID") ?? "";
const FLUTTERWAVE_CLIENT_SECRET = Deno.env.get("FLUTTERWAVE_CLIENT_SECRET") ?? "";
const APP_BASE_URL = Deno.env.get("APP_BASE_URL") ?? "http://127.0.0.1:7357";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  console.log("flutterwave-init invoked", { method: req.method, url: req.url });
  console.log("secrets present?", {
    hasClientId: !!FLUTTERWAVE_CLIENT_ID,
    hasClientSecret: !!FLUTTERWAVE_CLIENT_SECRET,
    appBaseUrl: APP_BASE_URL,
  });

  try {
    if (!FLUTTERWAVE_CLIENT_ID || !FLUTTERWAVE_CLIENT_SECRET) {
      return new Response(
        JSON.stringify({ error: "Missing Flutterwave credentials in Supabase secrets." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const body = await req.json().catch(() => null);
    if (!body) {
      return new Response(JSON.stringify({ error: "Invalid JSON body." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { email, amount, plan_id, user_id, interval } = body;

    if (!email || !amount || !plan_id || !user_id || !interval) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: email, amount, plan_id, user_id, interval." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const tx_ref = `orinx_${user_id}_${Date.now()}`;
    const redirect_url = `${APP_BASE_URL}/app/settings/pricing?status=verifying&tx_ref=${encodeURIComponent(tx_ref)}`;

    // IMPORTANT:
    // This is NOT true OAuth. We are using the provided "Client Secret" as Bearer token
    // only as a temporary measure. We log the response so we can confirm if Flutterwave accepts it.
    const authToken = FLUTTERWAVE_CLIENT_SECRET;

    const payload = {
      tx_ref,
      amount,
      currency: "USD",
      redirect_url,
      payment_options: "card",
      customer: { email, name: String(email).split("@")[0] },
      customizations: {
        title: "ORINX Subscription",
        description: `Upgrade to Plan ${plan_id}`,
        logo: "",
      },
      meta: { user_id, plan_id, interval },
    };

    console.log("Initializing payment", { email, amount, plan_id, interval, tx_ref, redirect_url });

    const response = await fetch("https://api.flutterwave.com/v3/payments", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${authToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const text = await response.text();
    let data: any = null;
    try {
      data = JSON.parse(text);
    } catch {
      // keep raw text
    }

    console.log("Flutterwave response", {
      status: response.status,
      ok: response.ok,
      body: data ?? text,
    });

    if (!response.ok || !data || data.status !== "success") {
      return new Response(
        JSON.stringify({
          error: "Flutterwave init failed",
          flutterwave_status: response.status,
          flutterwave_body: data ?? text,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Flutterwave typically returns link under data.link
    const payment_link = data?.data?.link ?? null;

    return new Response(
      JSON.stringify({ payment_link, tx_ref, raw: data }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Edge Function Error:", err);
    return new Response(JSON.stringify({ error: String(err?.message ?? err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
