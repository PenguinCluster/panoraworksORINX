create or replace function public.remove_team_member(
  target_member_id uuid
)
returns json
language plpgsql
security definer
as $$
declare
  requester_id uuid;
  target_record record;
  requester_role public.team_role;
begin
  requester_id := auth.uid();

  -- Get target member details
  select * into target_record
  from public.team_members
  where id = target_member_id;

  if not found then
    return json_build_object('error', 'Member not found');
  end if;

  -- Get requester's role in that team
  select role into requester_role
  from public.team_members
  where team_id = target_record.team_id
  and user_id = requester_id
  and status = 'active';

  -- Check Permissions
  -- Rule: Only Owner can remove Admin/Manager.
  if requester_role != 'owner' then
     return json_build_object('error', 'Only the Team Owner can remove members.');
  end if;

  -- Rule: Admin cannot remove Owner (Implicit since requester must be owner)
  -- But check if target is owner
  if target_record.role = 'owner' then
    return json_build_object('error', 'Cannot remove the Team Owner.');
  end if;

  -- Execute Removal
  update public.team_members
  set status = 'removed', updated_at = now()
  where id = target_member_id;

  -- Revoke any pending invites for this email on this team
  update public.team_invites
  set status = 'revoked'
  where team_id = target_record.team_id
  and email = target_record.email
  and status = 'pending';

  return json_build_object('success', true);
end;
$$;
