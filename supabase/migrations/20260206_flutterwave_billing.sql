-- Create plans table
create table public.plans (
  id uuid primary key default gen_random_uuid(),
  name text not null, -- O, R, I, N, X
  price_monthly numeric not null,
  price_annual numeric not null,
  features text[],
  active boolean default true,
  created_at timestamp with time zone default now()
);

-- Seed plans
insert into public.plans (name, price_monthly, price_annual, features) values
('O', 5, 3, ARRAY['Basic features', '1 user', 'Limited support']),
('R', 15, 10, ARRAY['Advanced features', '5 users', 'Priority support']),
('I', 25, 20, ARRAY['Pro features', 'Unlimited users', '24/7 support']),
('N', 50, 45, ARRAY['Enterprise features', 'Custom analytics', 'Dedicated manager']),
('X', 0, 0, ARRAY['Custom solutions', 'Full white-label', 'On-premise option']); -- Custom pricing

-- Create subscriptions table
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid references public.plans(id),
  status text not null default 'inactive', -- active, inactive, past_due, canceled
  current_period_start timestamp with time zone,
  current_period_end timestamp with time zone,
  flutterwave_sub_id text, -- subscription id from flutterwave
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create transactions table
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric not null,
  currency text not null default 'USD',
  status text not null, -- successful, failed, pending
  reference text unique not null, -- flutterwave tx_ref
  flutterwave_tx_id text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamp with time zone default now()
);

-- Enable RLS
alter table public.plans enable row level security;
alter table public.subscriptions enable row level security;
alter table public.transactions enable row level security;

-- Policies
create policy "Public plans are viewable by everyone." on public.plans for select using (true);

create policy "Users can view own subscription." on public.subscriptions for select using (auth.uid() = user_id);

create policy "Users can view own transactions." on public.transactions for select using (auth.uid() = user_id);

-- Function to handle successful payment (can be called by Edge Function with service role)
create or replace function public.handle_successful_payment(
  p_user_id uuid,
  p_plan_id uuid,
  p_amount numeric,
  p_reference text,
  p_tx_id text,
  p_interval text -- 'monthly' or 'yearly'
)
returns void
language plpgsql
security definer
as $$
declare
  v_period_end timestamp with time zone;
begin
  -- Calculate period end based on interval
  if p_interval = 'yearly' then
    v_period_end := now() + interval '1 year';
  else
    v_period_end := now() + interval '1 month';
  end if;

  -- Record transaction
  insert into public.transactions (user_id, amount, status, reference, flutterwave_tx_id)
  values (p_user_id, p_amount, 'successful', p_reference, p_tx_id);

  -- Update or Insert Subscription
  insert into public.subscriptions (user_id, plan_id, status, current_period_start, current_period_end)
  values (p_user_id, p_plan_id, 'active', now(), v_period_end)
  on conflict (id) do nothing; -- Simpler to just update if we enforced 1 sub per user, but for now we insert new.
  
  -- Better logic: Upsert based on user_id if we only allow 1 active sub per user
  -- For MVP, let's assume we update the latest subscription or create one if none exists.
  if exists (select 1 from public.subscriptions where user_id = p_user_id) then
     update public.subscriptions
     set plan_id = p_plan_id,
         status = 'active',
         current_period_start = now(),
         current_period_end = v_period_end,
         updated_at = now()
     where user_id = p_user_id;
  else
     insert into public.subscriptions (user_id, plan_id, status, current_period_start, current_period_end)
     values (p_user_id, p_plan_id, 'active', now(), v_period_end);
  end if;
end;
$$;
