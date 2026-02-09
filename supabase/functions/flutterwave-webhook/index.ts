import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const FW_SECRET = Deno.env.get("FLUTTERWAVE_SECRET_KEY") ?? "";
const FW_HASH = Deno.env.get("FLUTTERWAVE_HASH") ?? "";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
};

function bad(status: number, message: string) {
  return new Response(message, { status, headers: corsHeaders });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  // 1) Verify Flutterwave webhook signature
  // Note: Flutterwave documentation states header is 'verif-hash'.
  // We MUST compare this against the hash set in Flutterwave Dashboard and stored in FLUTTERWAVE_HASH env.
  const signature = req.headers.get("verif-hash");
  
  console.log(`Webhook received. Signature: ${signature}`);

  if (!FW_HASH || !signature || signature !== FW_HASH) {
    console.error(`Invalid signature. Expected: ${FW_HASH}, Got: ${signature}`);
    // Return 200 to prevent retries if it's just a signature mismatch (security best practice sometimes, or 401)
    // For debugging, we return 401.
    return bad(401, "Unauthorized signature");
  }

  if (!FW_SECRET) return bad(500, "Missing FLUTTERWAVE_SECRET_KEY");
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return bad(500, "Missing Supabase service secrets");

  const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  let event: any;
  try {
    event = await req.json();
    console.log("Webhook Event Data:", JSON.stringify(event)); // Log the entire event for debugging
  } catch {
    return bad(400, "Invalid JSON");
  }

  // Flutterwave usually sends: event.event === 'charge.completed'
  if (event?.event !== "charge.completed") {
    console.log(`Ignored event type: ${event?.event}`);
    return new Response("Ignored", { status: 200, headers: corsHeaders });
  }

  const data = event?.data;
  const tx_id = data?.id;
  const tx_ref = data?.tx_ref;

  if (!tx_id || !tx_ref) {
    return bad(400, "Missing transaction id/tx_ref");
  }

  // 2) Verify the transaction with Flutterwave before updating DB (anti-spoof)
  const verifyRes = await fetch(`https://api.flutterwave.com/v3/transactions/${tx_id}/verify`, {
    method: "GET",
    headers: { Authorization: `Bearer ${FW_SECRET}` },
  });

  const verifyJson = await verifyRes.json();

  if (!verifyRes.ok || verifyJson?.status !== "success") {
    console.error("FW verify failed:", { status: verifyRes.status, verifyJson });
    return bad(400, "Verification failed");
  }

  const vData = verifyJson.data;

  // 3) Validate success
  const isSuccessful = vData?.status === "successful";
  if (!isSuccessful) {
    return new Response("Not successful", { status: 200, headers: corsHeaders });
  }

  // 4) Pull required meta (user_id, plan_id, interval)
  const meta = vData?.meta ?? {};
  const user_id = meta.user_id;
  const plan_id = meta.plan_id;
  const interval = meta.interval;

  if (!user_id || !plan_id || !interval) {
    console.error("Missing meta on verified tx:", { meta, tx_id, tx_ref });
    return bad(400, "Missing meta fields (user_id/plan_id/interval)");
  }

  const amount = Number(vData?.amount ?? 0);
  if (!amount || Number.isNaN(amount)) return bad(400, "Invalid amount");

  // 5) Idempotency: if tx_ref already recorded, do nothing
  const { data: existing, error: existingErr } = await supabaseAdmin
    .from("transactions")
    .select("id")
    .eq("reference", tx_ref)
    .maybeSingle();

  if (existingErr) {
    console.error("DB check error:", existingErr);
    return bad(500, "DB error");
  }

  if (existing?.id) {
    return new Response("Already processed", { status: 200, headers: corsHeaders });
  }

  // 6) Commit: record transaction + subscription update via RPC
  const { error: rpcErr } = await supabaseAdmin.rpc("handle_successful_payment", {
    p_user_id: user_id,
    p_plan_id: plan_id,
    p_amount: amount,
    p_reference: tx_ref,
    p_tx_id: String(tx_id),
    p_interval: interval,
  });

  if (rpcErr) {
    console.error("RPC error:", rpcErr);
    return bad(500, "DB update failed");
  }

  return new Response("OK", { status: 200, headers: corsHeaders });
});
