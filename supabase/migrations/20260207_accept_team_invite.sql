-- Function to accept a team invite
create or replace function public.accept_team_invite(
  invite_token uuid
)
returns json
language plpgsql
security definer
as $$
declare
  invite_record record;
  user_email text;
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  select email into user_email from auth.users where id = current_user_id;

  -- 1. Find the invite
  select * into invite_record
  from public.team_invites
  where token = invite_token
  and status = 'pending'
  and expires_at > now();

  if not found then
    return json_build_object('error', 'Invalid or expired invite token');
  end if;

  -- 2. Verify email match (case-insensitive)
  if lower(invite_record.email::text) != lower(user_email) then
    return json_build_object('error', 'Email mismatch: Please login with ' || invite_record.email);
  end if;

  -- 3. Update invite status
  update public.team_invites
  set status = 'accepted'
  where id = invite_record.id;

  -- 4. Update team_member status and link user_id
  update public.team_members
  set status = 'active',
      user_id = current_user_id,
      updated_at = now()
  where team_id = invite_record.team_id
  and email = invite_record.email; -- Already citext

  return json_build_object('success', true, 'team_id', invite_record.team_id);
end;
$$;
