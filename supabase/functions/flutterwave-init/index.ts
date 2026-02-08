import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const CLIENT_ID = Deno.env.get("FLUTTERWAVE_CLIENT_ID") ?? "";
const CLIENT_SECRET = Deno.env.get("FLUTTERWAVE_CLIENT_SECRET") ?? "";
const APP_BASE_URL = Deno.env.get("APP_BASE_URL") ?? "http://127.0.0.1:7357";

// Flutterwave v4 token endpoint (client_credentials)
const TOKEN_URL =
  "https://idp.flutterwave.com/realms/flutterwave/protocol/openid-connect/token";

// v4 sandbox base
const FW_BASE = "https://developersandbox-api.flutterwave.com";

async function getAccessToken(): Promise<string> {
  if (!CLIENT_ID || !CLIENT_SECRET) {
    throw new Error("Missing FLUTTERWAVE_CLIENT_ID/FLUTTERWAVE_CLIENT_SECRET secrets");
  }

  const body = new URLSearchParams();
  body.set("grant_type", "client_credentials");
  body.set("client_id", CLIENT_ID);
  body.set("client_secret", CLIENT_SECRET);

  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  const json = await res.json();
  if (!res.ok) {
    console.error("Token fetch failed:", { status: res.status, json });
    throw new Error(json?.error_description || json?.error || "Token fetch failed");
  }

  const token = json?.access_token;
  if (!token) throw new Error("No access_token returned from Flutterwave");
  return token;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { email, amount, plan_id, user_id, interval } = await req.json();

    if (!email || !amount || !plan_id || !user_id || !interval) {
      throw new Error("Missing required fields: email, amount, plan_id, user_id, interval");
    }

    const accessToken = await getAccessToken();

    const tx_ref = `orinx_${user_id}_${Date.now()}`;
    const redirect_url =
      `${APP_BASE_URL}/app/settings/pricing?status=verifying&tx_ref=${encodeURIComponent(tx_ref)}`;

    // NOTE: endpoint/payload may vary by your enabled v4 product.
    // This uses the v4 sandbox Orchestration direct orders pattern.
    const payload = {
      tx_ref,
      amount,
      currency: "USD",
      redirect_url,
      customer: { email, name: email.split("@")[0] },
      meta: { user_id, plan_id, interval },
    };

    const fwRes = await fetch(`${FW_BASE}/orchestration/direct-orders`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const fwJson = await fwRes.json();

    if (!fwRes.ok) {
      console.error("Flutterwave init failed:", { status: fwRes.status, fwJson });
      throw new Error(fwJson?.message || "Flutterwave init failed");
    }

    const link =
      fwJson?.data?.link || fwJson?.data?.checkout_url || fwJson?.data?.payment_url;

    if (!link) {
      console.error("No checkout link returned:", fwJson);
      throw new Error("No checkout link returned by Flutterwave");
    }

    return new Response(JSON.stringify({ status: "success", data: { link, tx_ref } }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("Edge Function Error:", e);
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
