import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const FW_SECRET = Deno.env.get("FLUTTERWAVE_SECRET_KEY") ?? "";
const APP_BASE_URL = Deno.env.get("APP_BASE_URL") ?? "http://127.0.0.1:7357";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!FW_SECRET) {
      return new Response(
        JSON.stringify({ error: "Missing FLUTTERWAVE_SECRET_KEY secret" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { email, name, amount, plan_id, user_id, interval, billing_profile  } = await req.json();

    if (!email || !name || !amount || !plan_id || !user_id || !interval || !billing_profile) {
      return new Response(
        JSON.stringify({ error: "Missing fields: email, name, amount, plan_id, user_id, interval, biling_profile" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const tx_ref = `orinx_${user_id}_${Date.now()}`;
    const redirect_url =
      `${APP_BASE_URL}/#/app/settings/billing`;

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
      return new Response(
        JSON.stringify({ error: "Flutterwave init failed", details: fwJson }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(JSON.stringify(fwJson), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("Edge Function Error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
