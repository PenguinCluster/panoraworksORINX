-- Create connected_accounts table
create table public.connected_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  status text not null default 'disconnected',
  tokens jsonb, -- Encrypted or hidden from client via RLS
  metadata jsonb default '{}'::jsonb, -- To store things like Discord channel ID
  expires_at timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  unique(user_id, provider)
);

-- Enable RLS
alter table public.connected_accounts enable row level security;

-- Policies
-- Users can see their own connection status but NOT the tokens
create policy "Users can view their own connected accounts status"
  on public.connected_accounts
  for select
  using (auth.uid() = user_id);

-- Only service_role can access tokens (implicitly, but we can be explicit if we want to restrict select columns)
-- However, standard RLS doesn't easily hide columns per role in a single policy.
-- We'll use a view for the client to read safe data, or just trust that we won't select the tokens column in the client.
-- Better yet: We can use a column-level security approach or just not grant select on the tokens column to the 'authenticated' role.

grant select (id, user_id, provider, status, metadata, expires_at, created_at, updated_at) 
  on public.connected_accounts 
  to authenticated;

-- Users can update their own metadata (e.g. Discord channel ID)
create policy "Users can update their own connection metadata"
  on public.connected_accounts
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Function to handle token updates (to be called by Edge Functions or Triggers)
create or replace function public.update_connected_account(
  p_user_id uuid,
  p_provider text,
  p_status text,
  p_tokens jsonb,
  p_expires_at timestamp with time zone default null
)
returns void
language plpgsql
security definer
as $$
begin
  insert into public.connected_accounts (user_id, provider, status, tokens, expires_at, updated_at)
  values (p_user_id, p_provider, p_status, p_tokens, p_expires_at, now())
  on conflict (user_id, p_provider)
  do update set
    status = excluded.status,
    tokens = excluded.tokens,
    expires_at = excluded.expires_at,
    updated_at = now();
end;
$$;
