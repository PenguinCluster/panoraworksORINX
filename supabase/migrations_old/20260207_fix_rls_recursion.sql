-- ==============================================================================
-- FIX: Break Infinite Recursion in RLS with Security Definer Functions
-- ==============================================================================

-- 1. Helper Functions (SECURITY DEFINER to bypass RLS)
-- These functions run with owner privileges, allowing them to read tables 
-- without triggering the recursive RLS checks that caused the stack overflow.

-- Check if a user is the OWNER of a team (checks teams table directly)
create or replace function public.fn_is_team_owner(p_team_id uuid, p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return exists (
    select 1 from public.teams
    where id = p_team_id
    and owner_id = p_user_id
  );
end;
$$;

-- Check if a user is an ACTIVE MEMBER of a team (checks team_members directly)
create or replace function public.fn_is_team_member_active(p_team_id uuid, p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return exists (
    select 1 from public.team_members
    where team_id = p_team_id
    and user_id = p_user_id
    and status = 'active'
  );
end;
$$;

-- Check if a user is OWNER or ADMIN (active)
create or replace function public.fn_is_team_admin_or_owner(p_team_id uuid, p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Check Owner first (fastest)
  if exists (select 1 from public.teams where id = p_team_id and owner_id = p_user_id) then
    return true;
  end if;

  -- Check Admin role in members
  return exists (
    select 1 from public.team_members
    where team_id = p_team_id
    and user_id = p_user_id
    and role = 'admin'
    and status = 'active'
  );
end;
$$;

-- ==============================================================================
-- 2. Refactor team_members Policies
-- ==============================================================================

-- Drop existing policies to start fresh and clean
drop policy if exists "Team members can view members of their team" on public.team_members;
drop policy if exists "Owners and Admins can manage members" on public.team_members;
drop policy if exists "Users can view their own membership" on public.team_members;
-- Add any other potentially conflicting policies found in inspection
drop policy if exists "view_team_members" on public.team_members;
drop policy if exists "manage_team_members" on public.team_members;

-- Policy: SELECT (Read)
-- Allow if: You are the user being queried (view self) OR You are an active member of the team OR You are the owner
create policy "allow_select_team_members"
on public.team_members
for select
using (
  auth.uid() = user_id -- View self
  or
  public.fn_is_team_owner(team_id, auth.uid()) -- View as Owner
  or
  public.fn_is_team_member_active(team_id, auth.uid()) -- View as Member
);

-- Policy: INSERT (Add)
-- Allow if: You are the Owner (or Admin, if allowed to invite).
-- Note: Our `send_team_invite` RPC handles invites, but direct inserts might be used by Owners.
create policy "allow_insert_team_members"
on public.team_members
for insert
with check (
  public.fn_is_team_owner(team_id, auth.uid())
  or
  public.fn_is_team_admin_or_owner(team_id, auth.uid())
);

-- Policy: UPDATE (Edit)
-- Allow if: You are Owner or Admin.
-- Note: Logic to prevent Admin from removing Owner is handled in app/RPC, but RLS allows the update attempt.
create policy "allow_update_team_members"
on public.team_members
for update
using (
  public.fn_is_team_owner(team_id, auth.uid())
  or
  public.fn_is_team_admin_or_owner(team_id, auth.uid())
);

-- Policy: DELETE (Remove)
-- STRICT: Only Owner can delete rows.
-- Note: We prefer soft-delete (status='removed'), so DELETE might not be used often, but good to secure.
create policy "allow_delete_team_members"
on public.team_members
for delete
using (
  public.fn_is_team_owner(team_id, auth.uid())
);

-- ==============================================================================
-- 3. Refactor teams Policies (to be safe)
-- ==============================================================================

-- Drop potentially recursive policies
drop policy if exists "Members can view their team" on public.teams;
drop policy if exists "Team owners can update their team" on public.teams;

-- SELECT: Active members can see the team details
create policy "allow_select_teams"
on public.teams
for select
using (
  owner_id = auth.uid()
  or
  public.fn_is_team_member_active(id, auth.uid())
);

-- UPDATE: Only Owner
create policy "allow_update_teams"
on public.teams
for update
using (
  owner_id = auth.uid()
);

-- INSERT: Authenticated users can create teams
create policy "allow_insert_teams"
on public.teams
for insert
with check (
  auth.role() = 'authenticated'
);
