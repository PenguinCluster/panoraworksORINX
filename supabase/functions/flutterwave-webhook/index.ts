import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7"

const FLUTTERWAVE_SECRET_KEY = Deno.env.get('FLUTTERWAVE_SECRET_KEY') ?? '';
const FLUTTERWAVE_HASH = Deno.env.get('FLUTTERWAVE_HASH') ?? ''; // Secret hash for verification

serve(async (req) => {
  // Webhook verification (optional but recommended)
  // const signature = req.headers.get("verif-hash");
  // if (!signature || signature !== FLUTTERWAVE_HASH) {
  //   return new Response("Unauthorized", { status: 401 });
  // }

  const event = await req.json();

  if (event.event === 'charge.completed' && event.data.status === 'successful') {
    const { tx_ref, amount, id } = event.data;
    const { user_id, plan_id, interval } = event.data.meta; // Ensure meta is passed back

    // Initialize Supabase Admin Client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Call database function to record payment and update subscription
    const { error } = await supabaseAdmin.rpc('handle_successful_payment', {
      p_user_id: user_id,
      p_plan_id: plan_id,
      p_amount: amount,
      p_reference: tx_ref,
      p_tx_id: id.toString(),
      p_interval: interval
    });

    if (error) {
      console.error('Error updating DB:', error);
      return new Response("DB Error", { status: 500 });
    }
  }

  return new Response("Webhook Received", { status: 200 });
})
