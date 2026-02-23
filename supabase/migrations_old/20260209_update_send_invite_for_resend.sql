create or replace function public.send_team_invite(
  invite_email text,
  invite_team_id uuid,
  invite_role public.team_role,
  invite_is_admin_toggle boolean
)
returns json
language plpgsql
security definer
as $$
declare
  existing_member record;
  invite_token uuid;
  new_invite_id uuid;
  inviter_id uuid;
begin
  inviter_id := auth.uid();

  -- 1. Check if inviter is owner or admin of the team
  if not exists (
    select 1 from public.teams where id = invite_team_id and owner_id = inviter_id
  ) and not exists (
    select 1 from public.team_members 
    where team_id = invite_team_id 
    and user_id = inviter_id 
    and role in ('owner', 'admin') 
    and status = 'active'
  ) then
    return json_build_object('error', 'Permission denied');
  end if;

  -- 2. Check if user is already a member (active)
  select * into existing_member 
  from public.team_members 
  where team_id = invite_team_id 
  and email = invite_email::citext 
  and status = 'active';

  if found then
    return json_build_object('error', 'User is already an active member');
  end if;

  -- 3. Check if user is locked to another team (active or pending elsewhere)
  if exists (
    select 1 from public.team_members
    where email = invite_email::citext
    and status in ('pending', 'active')
    and team_id != invite_team_id
  ) then
    return json_build_object('error', 'User is already a member of another team');
  end if;

  -- 4. Expire old pending invites for this user on this team (Resend Logic)
  update public.team_invites
  set status = 'revoked'
  where team_id = invite_team_id
  and email = invite_email::citext
  and status = 'pending';

  -- 5. Create New Invite
  invite_token := gen_random_uuid();
  
  insert into public.team_invites (
    team_id, email, role, is_admin_toggle, token, status, expires_at, invited_by
  )
  values (
    invite_team_id,
    invite_email::citext,
    invite_role,
    invite_is_admin_toggle,
    invite_token,
    'pending',
    now() + interval '7 days',
    inviter_id
  )
  returning id into new_invite_id;

  -- 6. Upsert pending team_member row
  insert into public.team_members (
    team_id, email, role, status, invited_by
  )
  values (
    invite_team_id,
    invite_email::citext,
    invite_role,
    'pending',
    inviter_id
  )
  on conflict (email) where status in ('pending', 'active') 
  do update set 
    role = excluded.role,
    invited_by = excluded.invited_by,
    updated_at = now();

  return json_build_object(
    'success', true,
    'invite_id', new_invite_id,
    'token', invite_token
  );
end;
$$;
