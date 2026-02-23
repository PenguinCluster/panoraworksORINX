-- Add 'member' to team_role enum
ALTER TYPE public.team_role ADD VALUE IF NOT EXISTS 'member';

-- Create team_profiles table
CREATE TABLE IF NOT EXISTS public.team_profiles (
    team_id uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE PRIMARY KEY,
    workspace_name text NOT NULL,
    avatar_url text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.team_profiles ENABLE ROW LEVEL SECURITY;

-- Policies for team_profiles

-- Viewable by any active team member
CREATE POLICY "Team profiles are viewable by team members"
    ON public.team_profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.team_members
            WHERE team_members.team_id = team_profiles.team_id
            AND team_members.user_id = auth.uid()
            AND team_members.status = 'active'
        )
    );

-- Updatable by owner and admin
CREATE POLICY "Team profiles are updatable by team admins and owners"
    ON public.team_profiles FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.team_members
            WHERE team_members.team_id = team_profiles.team_id
            AND team_members.user_id = auth.uid()
            AND team_members.status = 'active'
            AND team_members.role IN ('owner', 'admin')
        )
    );

-- Insert policy for initial creation (usually by owner when creating team)
CREATE POLICY "Team profiles are insertable by team members"
    ON public.team_profiles FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.team_members
            WHERE team_members.team_id = team_profiles.team_id
            AND team_members.user_id = auth.uid()
            -- logic: if you are creating a team, you are the owner, but team_members might be inserted after or before?
            -- Usually team creation transaction handles this.
            -- Allowing any authenticated user to insert if they can verify they are part of the team.
        )
    );

-- Backfill existing teams into team_profiles
INSERT INTO public.team_profiles (team_id, workspace_name)
SELECT id, name FROM public.teams
ON CONFLICT (team_id) DO NOTHING;
