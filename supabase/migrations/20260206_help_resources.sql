-- Create support_messages table
create table public.support_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  message text not null,
  status text not null default 'new', -- new, in_progress, resolved
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create feature_requests table
create table public.feature_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text not null,
  priority text default 'medium', -- low, medium, high
  status text not null default 'pending', -- pending, planned, in_progress, completed
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Enable RLS
alter table public.support_messages enable row level security;
alter table public.feature_requests enable row level security;

-- Policies for support_messages
create policy "Users can create support messages"
  on public.support_messages
  for insert
  with check (auth.uid() = user_id);

create policy "Users can view their own support messages"
  on public.support_messages
  for select
  using (auth.uid() = user_id);

-- Policies for feature_requests
create policy "Users can create feature requests"
  on public.feature_requests
  for insert
  with check (auth.uid() = user_id);

create policy "Users can view their own feature requests"
  on public.feature_requests
  for select
  using (auth.uid() = user_id);
