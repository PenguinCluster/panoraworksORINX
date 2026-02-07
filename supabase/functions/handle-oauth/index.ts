import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7"

serve(async (req) => {
  const { provider, user_id, access_token, refresh_token, expires_in } = await req.json()

  // Create a Supabase client with the service role key to bypass RLS and access 'tokens' column
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  const expires_at = new Date(Date.now() + (expires_in * 1000)).toISOString()

  // Update connected_accounts table via the RPC function we created in migration
  const { error } = await supabaseAdmin.rpc('update_connected_account', {
    p_user_id: user_id,
    p_provider: provider,
    p_status: 'connected',
    p_tokens: { access_token, refresh_token },
    p_expires_at: expires_at
  })

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 400,
    })
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { "Content-Type": "application/json" },
    status: 200,
  })
})
