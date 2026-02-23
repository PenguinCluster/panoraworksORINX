-- Create team_invites table
create table public.team_invites (
  id uuid default gen_random_uuid() primary key,
  owner_id uuid references auth.users(id) on delete cascade not null,
  email text not null,
  role text not null default 'member',
  status text not null default 'pending',
  created_at timestamp with time zone default now()
);

-- Enable RLS
alter table public.team_invites enable row level security;

-- Policies
create policy "Users can view invites they created"
  on public.team_invites for select
  using (auth.uid() = owner_id);

create policy "Users can insert invites for their own team"
  on public.team_invites for insert
  with check (auth.uid() = owner_id);

create policy "Users can delete invites they created"
  on public.team_invites for delete
  using (auth.uid() = owner_id);
