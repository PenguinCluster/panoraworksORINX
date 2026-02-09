-- ==============================================================================
-- 1. Ensure Owner is always a Team Member (Seed Trigger)
-- ==============================================================================

-- Function to handle new user signup: Create Profile -> Create Team -> Add to Team Members
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_team_id uuid;
begin
  -- 1. Create Profile (if not exists)
  insert into public.profiles (id, email, full_name, avatar_url)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing;

  -- 2. Create Default Team
  insert into public.teams (owner_id, name)
  values (new.id, 'My Team')
  returning id into new_team_id;

  -- 3. Add User as Owner of that Team
  insert into public.team_members (team_id, user_id, role, status)
  values (new_team_id, new.id, 'owner', 'active');

  return new;
end;
$$;

-- Trigger on auth.users
-- Drop existing if any (to update logic)
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute procedure public.handle_new_user();

-- ==============================================================================
-- 2. Backfill for existing users who have no team
-- ==============================================================================
do $$
declare
  user_rec record;
  new_team_id uuid;
begin
  for user_rec in select id from auth.users loop
    -- Check if they have a team where they are owner
    if not exists (select 1 from public.teams where owner_id = user_rec.id) then
      
      -- Create Team
      insert into public.teams (owner_id, name)
      values (user_rec.id, 'My Team')
      returning id into new_team_id;

      -- Add Member
      insert into public.team_members (team_id, user_id, role, status)
      values (new_team_id, user_rec.id, 'owner', 'active');
      
    else
      -- They have a team, check if they are in team_members
      -- If they own a team but are not in team_members, fix it
      for new_team_id in select id from public.teams where owner_id = user_rec.id loop
        if not exists (select 1 from public.team_members where team_id = new_team_id and user_id = user_rec.id) then
           insert into public.team_members (team_id, user_id, role, status)
           values (new_team_id, user_rec.id, 'owner', 'active');
        end if;
      end loop;
    end if;
  end loop;
end;
$$;
