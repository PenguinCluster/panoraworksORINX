-- Create billing_profiles table
create table public.billing_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  address_line1 text not null,
  address_line2 text,
  city text not null,
  state text,
  country text not null,
  postal_code text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Enable RLS
alter table public.billing_profiles enable row level security;

-- Policies for billing_profiles
create policy "Users can view their own billing profile"
  on public.billing_profiles
  for select
  using (auth.uid() = user_id);

create policy "Users can insert their own billing profile"
  on public.billing_profiles
  for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own billing profile"
  on public.billing_profiles
  for update
  using (auth.uid() = user_id);
