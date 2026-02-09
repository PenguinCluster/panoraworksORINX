-- Enable citext extension for case-insensitive emails
create extension if not exists citext;

-- Create enum types
do $$ begin
    create type public.team_role as enum ('owner', 'admin', 'manager');
exception
    when duplicate_object then null;
end $$;

do $$ begin
    create type public.member_status as enum ('pending', 'active', 'removed');
exception
    when duplicate_object then null;
end $$;

do $$ begin
    create type public.invite_status as enum ('pending', 'accepted', 'expired', 'revoked');
exception
    when duplicate_object then null;
end $$;

-- Drop previous table if it exists (from previous MVP step) to ensure clean slate for new schema
drop table if exists public.team_invites;

-- Create teams table
create table if not exists public.teams (
    id uuid default gen_random_uuid() primary key,
    owner_id uuid references auth.users(id) not null,
    name text not null,
    created_at timestamp with time zone default now()
);

-- Enable RLS on teams
alter table public.teams enable row level security;

-- Create team_members table
create table if not exists public.team_members (
    id uuid default gen_random_uuid() primary key,
    team_id uuid references public.teams(id) on delete cascade not null,
    user_id uuid references auth.users(id), -- Nullable until accepted/registered
    email citext not null,
    role public.team_role not null default 'manager',
    status public.member_status not null default 'pending',
    invited_by uuid references auth.users(id),
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone default now()
);

-- Enable RLS on team_members
alter table public.team_members enable row level security;

-- Create team_invites table
create table if not exists public.team_invites (
    id uuid default gen_random_uuid() primary key,
    team_id uuid references public.teams(id) on delete cascade not null,
    email citext not null,
    role public.team_role not null,
    is_admin_toggle boolean default false,
    token uuid default gen_random_uuid() not null,
    status public.invite_status not null default 'pending',
    expires_at timestamp with time zone default (now() + interval '7 days'),
    invited_by uuid references auth.users(id),
    created_at timestamp with time zone default now()
);

-- Enable RLS on team_invites
alter table public.team_invites enable row level security;

-- Constraints

-- 1. Unique (team_id, email) where status is pending or active (Prevent duplicate active membership in same team)
create unique index if not exists team_members_team_email_idx 
on public.team_members (team_id, email) 
where status in ('pending', 'active');

-- 2. Global "email lock": Unique(email) where status is pending or active across ALL teams
-- This prevents a user/email from being in multiple teams simultaneously.
create unique index if not exists team_members_global_email_lock_idx 
on public.team_members (email) 
where status in ('pending', 'active');


-- RLS Policies

-- Teams Policies
create policy "Owners can view their teams"
    on public.teams for select
    using (auth.uid() = owner_id);

create policy "Owners can update their teams"
    on public.teams for update
    using (auth.uid() = owner_id);

create policy "Members can view their team"
    on public.teams for select
    using (
        exists (
            select 1 from public.team_members
            where team_members.team_id = teams.id
            and team_members.user_id = auth.uid()
            and team_members.status = 'active'
        )
    );

-- Team Members Policies
create policy "Team members can view members of their team"
    on public.team_members for select
    using (
        exists (
            select 1 from public.team_members as tm
            where tm.team_id = team_members.team_id
            and tm.user_id = auth.uid()
            and tm.status = 'active'
        )
        or 
        auth.uid() = user_id -- Allow viewing self even if not active? (e.g. pending)
    );

create policy "Owners and Admins can manage members"
    on public.team_members for all
    using (
        exists (
            select 1 from public.teams
            where teams.id = team_members.team_id
            and teams.owner_id = auth.uid()
        )
        or
        exists (
            select 1 from public.team_members as tm
            where tm.team_id = team_members.team_id
            and tm.user_id = auth.uid()
            and tm.role in ('owner', 'admin')
            and tm.status = 'active'
        )
    );

-- Team Invites Policies
create policy "Owners and Admins can view and manage invites"
    on public.team_invites for all
    using (
        exists (
            select 1 from public.teams
            where teams.id = team_invites.team_id
            and teams.owner_id = auth.uid()
        )
        or
        exists (
            select 1 from public.team_members
            where team_members.team_id = team_invites.team_id
            and team_members.user_id = auth.uid()
            and team_members.role in ('owner', 'admin')
            and team_members.status = 'active'
        )
    );

-- Trigger to automatically create a team for new users (Optional but good for MVP self-serve)
-- Or we assume the user creates one manually. For now, we'll leave it to manual or API creation.
-- But we need to ensure the TeamSection logic works. 
-- If the user doesn't have a team, we might need to create one on the fly or have a "Create Team" button.
-- For this task, we just deliver the SQL migration.
