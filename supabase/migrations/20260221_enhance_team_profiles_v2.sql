-- Drop table if exists to ensure clean slate with correct columns
DROP TABLE IF EXISTS public.team_profiles;

-- 1) Create table team_profiles
CREATE TABLE public.team_profiles (
    team_id uuid NOT NULL PRIMARY KEY REFERENCES public.teams(id) ON DELETE CASCADE,
    display_name text NOT NULL DEFAULT 'My Workspace',
    avatar_url text,
    brand_name text,
    brand_color text,
    settings jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by uuid REFERENCES auth.users(id)
);

-- 2) Create/ensure generic set_updated_at() trigger function and attach
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON public.team_profiles;
CREATE TRIGGER set_updated_at
BEFORE UPDATE ON public.team_profiles
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- 3) Create helper functions (security definer)

-- public.get_my_active_team_membership()
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
    LIMIT 1;
    
    RETURN v_member;
END;
$$;

-- public.is_team_owner(p_team_id uuid)
CREATE OR REPLACE FUNCTION public.is_team_owner(p_team_id uuid)
RETURNS boolean
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.team_members
        WHERE team_id = p_team_id
        AND user_id = auth.uid()
        AND role = 'owner'
        AND status = 'active'
    );
END;
$$;

-- public.is_team_admin_or_owner(p_team_id uuid)
CREATE OR REPLACE FUNCTION public.is_team_admin_or_owner(p_team_id uuid)
RETURNS boolean
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.team_members
        WHERE team_id = p_team_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'admin')
        AND status = 'active'
    );
END;
$$;

-- public.is_team_member_active(p_team_id uuid)
CREATE OR REPLACE FUNCTION public.is_team_member_active(p_team_id uuid)
RETURNS boolean
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.team_members
        WHERE team_id = p_team_id
        AND user_id = auth.uid()
        AND status = 'active'
    );
END;
$$;

-- 4) Backfill team_profiles for existing teams
INSERT INTO public.team_profiles (team_id, display_name)
SELECT 
    t.id, 
    COALESCE(
        t.name, 
        p.full_name, 
        p.email, 
        'My Workspace'
    )
FROM public.teams t
LEFT JOIN public.profiles p ON t.owner_id = p.id
ON CONFLICT (team_id) DO NOTHING;

-- 5) Add trigger on public.teams insert to auto-create a team_profiles row
CREATE OR REPLACE FUNCTION public.handle_new_team_profile()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.team_profiles (team_id, display_name)
    VALUES (NEW.id, COALESCE(NEW.name, 'My Workspace'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_team_created_create_profile ON public.teams;
CREATE TRIGGER on_team_created_create_profile
AFTER INSERT ON public.teams
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_team_profile();

-- 6) Enable RLS on team_profiles and add policies
ALTER TABLE public.team_profiles ENABLE ROW LEVEL SECURITY;

-- Select: Any active team member
CREATE POLICY "Team profiles are viewable by active members"
    ON public.team_profiles FOR SELECT
    USING (public.is_team_member_active(team_id));

-- Update: Owner/Admin
CREATE POLICY "Team profiles are updatable by owners and admins"
    ON public.team_profiles FOR UPDATE
    USING (public.is_team_admin_or_owner(team_id));

-- Insert: Owner only (Trigger handles this usually, but allow manual if needed by owner)
CREATE POLICY "Team profiles are insertable by owners"
    ON public.team_profiles FOR INSERT
    WITH CHECK (public.is_team_owner(team_id));

-- Delete: Owner only
CREATE POLICY "Team profiles are deletable by owners"
    ON public.team_profiles FOR DELETE
    USING (public.is_team_owner(team_id));

-- 7) Create RPC public.get_my_workspace_context()
CREATE OR REPLACE FUNCTION public.get_my_workspace_context()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_member public.team_members;
    v_profile public.team_profiles;
    v_result jsonb;
BEGIN
    -- Get active membership
    v_member := public.get_my_active_team_membership();
    
    IF v_member IS NULL THEN
        RETURN jsonb_build_object(
            'has_team', false,
            'team_id', null,
            'role', null,
            'status', null,
            'workspace', null
        );
    END IF;
    
    -- Get team profile
    SELECT * INTO v_profile FROM public.team_profiles WHERE team_id = v_member.team_id;
    
    -- If no profile exists (edge case), return partial info
    IF v_profile IS NULL THEN
         RETURN jsonb_build_object(
            'has_team', true,
            'team_id', v_member.team_id,
            'role', v_member.role,
            'status', v_member.status,
            'workspace', null
        );
    END IF;

    v_result := jsonb_build_object(
        'has_team', true,
        'team_id', v_member.team_id,
        'role', v_member.role,
        'status', v_member.status,
        'workspace', jsonb_build_object(
            'display_name', v_profile.display_name,
            'avatar_url', v_profile.avatar_url,
            'brand_name', v_profile.brand_name,
            'brand_color', v_profile.brand_color,
            'settings', v_profile.settings
        )
    );
    
    RETURN v_result;
END;
$$;
