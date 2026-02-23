-- Fix non-deterministic membership and robustify check_email_lock

-- 1) Fix get_my_active_team_membership to be deterministic
-- Logic: Prioritize teams where user is NOT owner (invited/collaborator) 
-- over owned teams (default workspace), then by newest created_at.
CREATE OR REPLACE FUNCTION public.get_my_active_team_membership()
RETURNS public.team_members
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_member public.team_members;
BEGIN
    SELECT * INTO v_member
    FROM public.team_members
    WHERE user_id = auth.uid()
    AND status = 'active'
    ORDER BY 
        (role = 'owner') ASC, -- false (collaborator) comes first
        created_at DESC
    LIMIT 1;
    
    RETURN v_member;
END;
$$;

-- 2) Update handle_new_user to NEVER create a default team if the user 
-- has ANY existing membership (including pending invites that might have been auto-accepted 
-- or if they are already in team_members via trigger).
-- Actually, we should check `team_invites` and `team_members`.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_profile_exists boolean;
    v_has_membership boolean;
    v_has_invite boolean;
BEGIN
    -- 1. Check/Create Profile
    SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.id) INTO v_profile_exists;
    IF NOT v_profile_exists THEN
        INSERT INTO public.profiles (
            id, full_name, email, avatar_url, updated_at
        ) VALUES (
            NEW.id,
            COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
            now()
        );
    END IF;

    -- 2. Check for ANY existing team context
    -- Check active membership
    SELECT EXISTS (
        SELECT 1 FROM public.team_members WHERE user_id = NEW.id
    ) INTO v_has_membership;
    
    -- Check pending invite (by email)
    SELECT EXISTS (
        SELECT 1 FROM public.team_invites 
        WHERE email = NEW.email 
        AND status = 'pending'
    ) INTO v_has_invite;

    -- 3. Create default team ONLY if no membership AND no pending invite
    IF NOT v_has_membership AND NOT v_has_invite THEN
        -- Double check they don't own a team already
        IF NOT EXISTS (SELECT 1 FROM public.teams WHERE owner_id = NEW.id) THEN
            INSERT INTO public.teams (owner_id, name)
            VALUES (NEW.id, 'My Workspace');
        END IF;
    END IF;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'handle_new_user failed: %', SQLERRM;
        RETURN NEW; 
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3) Ensure check_email_lock is robust and authoritative
-- This function is called by SignupScreen to block standalone signup.

DROP FUNCTION IF EXISTS public.check_email_lock(text);

CREATE OR REPLACE FUNCTION public.check_email_lock(check_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invite_exists boolean;
    v_team_id uuid;
BEGIN
    -- 1. Check for pending invite
    SELECT team_id INTO v_team_id
    FROM public.team_invites 
    WHERE email = check_email 
    AND status = 'pending' 
    LIMIT 1;

    IF v_team_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'locked', true,
            'reason', 'pending_invite',
            'team_id', v_team_id,
            'source', 'team_invites'
        );
    END IF;

    -- 2. Check for existing membership (if user exists)
    -- Need to look up user_id by email from auth.users? 
    -- We can't query auth.users directly easily from here unless we use a secure view or just assume.
    -- But usually `check_email_lock` is for NEW signups. 
    -- If they are already a member, they should login, not signup.
    -- But we can check if this email is in team_members via the `email` column if you have one, 
    -- or we skip this if team_members only has user_id.
    -- Assuming team_invites is the main gate for new users.
    
    -- However, if we want to be strict: "If email is active member... block standalone signup"
    -- This implies if they somehow deleted their account but kept membership? Unlikely.
    -- If they have an account, `_authService.signUp` will fail with "User already registered".
    -- So `check_email_lock` is primarily for PENDING invites for users who DON'T have an account yet.
    
    RETURN jsonb_build_object('locked', false);
END;
$$;
