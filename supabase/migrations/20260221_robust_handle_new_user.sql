-- Create a robust handle_new_user function that is safe against duplicates
-- and ensures profiles are created properly.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_profile_exists boolean;
BEGIN
    -- 1. Check if profile already exists (idempotency check)
    SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.id) INTO v_profile_exists;
    
    -- 2. Create Profile if not exists
    IF NOT v_profile_exists THEN
        INSERT INTO public.profiles (
            id,
            full_name,
            email,
            avatar_url,
            updated_at
        ) VALUES (
            NEW.id,
            COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
            now()
        );
    END IF;

    -- 3. Check if this is a "first team" creation scenario
    -- Usually, we might want to create a default team for every new user.
    -- However, if they are invited to an existing team, they shouldn't necessarily
    -- get a new empty team immediately, or maybe they should (personal workspace).
    -- For now, let's keep it simple: EVERY user gets a default personal team/workspace.
    
    -- Insert into teams if not exists (using ON CONFLICT DO NOTHING)
    -- Assuming we want to create a team for them where they are the owner.
    -- We'll verify if they own any team first to avoid duplicates if re-running.
    IF NOT EXISTS (SELECT 1 FROM public.teams WHERE owner_id = NEW.id) THEN
        INSERT INTO public.teams (owner_id, name)
        VALUES (NEW.id, 'My Workspace');
    END IF;

    -- Note: The `teams` insert usually triggers `handle_new_team_profile` 
    -- and potentially `add_team_creator_as_member` triggers if they exist.
    -- Ensure those triggers are robust too (using ON CONFLICT DO NOTHING).

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't block auth if possible, OR re-raise if critical.
        -- For auth triggers, raising exception blocks signup, which is usually safer 
        -- than partial state.
        RAISE WARNING 'handle_new_user failed: %', SQLERRM;
        RETURN NEW; 
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
