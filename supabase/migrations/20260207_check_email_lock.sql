-- Function to check if an email is locked to a team
create or replace function public.check_email_lock(check_email text)
returns json
language plpgsql
security definer
as $$
declare
  member_record record;
  invite_record record;
begin
  -- Check team_members
  select * into member_record
  from public.team_members
  where email = check_email::citext
  and status in ('pending', 'active')
  limit 1;

  if found then
    return json_build_object(
      'locked', true,
      'team_id', member_record.team_id,
      'status', member_record.status,
      'source', 'member'
    );
  end if;

  -- Check team_invites
  select * into invite_record
  from public.team_invites
  where email = check_email::citext
  and status = 'pending'
  limit 1;

  if found then
    return json_build_object(
      'locked', true,
      'team_id', invite_record.team_id,
      'status', invite_record.status,
      'source', 'invite'
    );
  end if;

  return json_build_object(
    'locked', false
  );
end;
$$;
