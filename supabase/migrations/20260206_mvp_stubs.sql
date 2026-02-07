-- Create tables for Content Hub
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text,
  media_urls text[],
  platforms text[],
  status text not null default 'draft', -- draft, scheduled, published
  scheduled_at timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create table for Live Alerts
create table public.alert_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  condition text not null,
  destinations jsonb default '[]'::jsonb, -- e.g. [{"type": "discord", "enabled": true}]
  is_active boolean default true,
  created_at timestamp with time zone default now()
);

-- Create table for Keyword Monitoring
create table public.monitored_keywords (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  keyword text not null,
  tags text[],
  status text default 'active',
  created_at timestamp with time zone default now(),
  unique(user_id, keyword)
);

-- Enable RLS
alter table public.posts enable row level security;
alter table public.alert_rules enable row level security;
alter table public.monitored_keywords enable row level security;

-- Policies
create policy "Users can manage their own posts" on public.posts
  for all using (auth.uid() = user_id);

create policy "Users can manage their own alert rules" on public.alert_rules
  for all using (auth.uid() = user_id);

create policy "Users can manage their own monitored keywords" on public.monitored_keywords
  for all using (auth.uid() = user_id);

-- Storage bucket for media
insert into storage.buckets (id, name, public) values ('media', 'media', true);

create policy "Users can upload media" on storage.objects
  for insert with check (bucket_id = 'media' and auth.role() = 'authenticated');

create policy "Anyone can view media" on storage.objects
  for select using (bucket_id = 'media');
