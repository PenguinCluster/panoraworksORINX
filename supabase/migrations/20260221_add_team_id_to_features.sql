-- Migration to add team_id to feature tables and migrate existing data

-- 1. connected_accounts
ALTER TABLE public.connected_accounts 
ADD COLUMN IF NOT EXISTS team_id uuid REFERENCES public.teams(id) ON DELETE CASCADE;

-- Backfill: For now, map to the user's first owned team, or NULL if none.
-- (In a real production migration, you might want to force a specific mapping or default team)
UPDATE public.connected_accounts ca
SET team_id = (
    SELECT t.id FROM public.teams t 
    WHERE t.owner_id = ca.user_id 
    LIMIT 1
)
WHERE team_id IS NULL;

-- 2. posts
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS team_id uuid REFERENCES public.teams(id) ON DELETE CASCADE;

UPDATE public.posts p
SET team_id = (
    SELECT t.id FROM public.teams t 
    WHERE t.owner_id = p.user_id 
    LIMIT 1
)
WHERE team_id IS NULL;

-- 3. monitored_keywords
ALTER TABLE public.monitored_keywords 
ADD COLUMN IF NOT EXISTS team_id uuid REFERENCES public.teams(id) ON DELETE CASCADE;

UPDATE public.monitored_keywords mk
SET team_id = (
    SELECT t.id FROM public.teams t 
    WHERE t.owner_id = mk.user_id 
    LIMIT 1
)
WHERE team_id IS NULL;

-- 4. alert_rules
ALTER TABLE public.alert_rules 
ADD COLUMN IF NOT EXISTS team_id uuid REFERENCES public.teams(id) ON DELETE CASCADE;

UPDATE public.alert_rules ar
SET team_id = (
    SELECT t.id FROM public.teams t 
    WHERE t.owner_id = ar.user_id 
    LIMIT 1
)
WHERE team_id IS NULL;

-- 5. subscriptions
ALTER TABLE public.subscriptions 
ADD COLUMN IF NOT EXISTS team_id uuid REFERENCES public.teams(id) ON DELETE CASCADE;

UPDATE public.subscriptions s
SET team_id = (
    SELECT t.id FROM public.teams t 
    WHERE t.owner_id = s.user_id 
    LIMIT 1
)
WHERE team_id IS NULL;

-- 6. transactions
ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS team_id uuid REFERENCES public.teams(id) ON DELETE CASCADE;

UPDATE public.transactions tr
SET team_id = (
    SELECT t.id FROM public.teams t 
    WHERE t.owner_id = tr.user_id 
    LIMIT 1
)
WHERE team_id IS NULL;

-- 7. Update RLS Policies to use team_id
-- We need to ensure that users can see rows where they are a team member.

-- Helper function for RLS (if not already exists from previous steps)
CREATE OR REPLACE FUNCTION public.is_team_member(p_team_id uuid)
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

-- Apply generic team RLS to tables
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY['connected_accounts', 'posts', 'monitored_keywords', 'alert_rules', 'subscriptions', 'transactions'])
    LOOP
        -- Drop existing user-based policies (optional, but cleaner to replace them)
        -- EXECUTE format('DROP POLICY IF EXISTS "Users can view own %I" ON public.%I', t, t);
        -- EXECUTE format('DROP POLICY IF EXISTS "Users can insert own %I" ON public.%I', t, t);
        -- EXECUTE format('DROP POLICY IF EXISTS "Users can update own %I" ON public.%I', t, t);
        -- EXECUTE format('DROP POLICY IF EXISTS "Users can delete own %I" ON public.%I', t, t);

        -- Create new Team-based Select Policy
        EXECUTE format('
            CREATE POLICY "Team members can view %I"
            ON public.%I FOR SELECT
            USING ( team_id IS NOT NULL AND public.is_team_member(team_id) )', t, t);

        -- Create new Team-based Insert Policy
        EXECUTE format('
            CREATE POLICY "Team members can insert %I"
            ON public.%I FOR INSERT
            WITH CHECK ( team_id IS NOT NULL AND public.is_team_member(team_id) )', t, t);

        -- Create new Team-based Update Policy
        EXECUTE format('
            CREATE POLICY "Team members can update %I"
            ON public.%I FOR UPDATE
            USING ( team_id IS NOT NULL AND public.is_team_member(team_id) )', t, t);

        -- Create new Team-based Delete Policy
        EXECUTE format('
            CREATE POLICY "Team members can delete %I"
            ON public.%I FOR DELETE
            USING ( team_id IS NOT NULL AND public.is_team_member(team_id) )', t, t);
            
    END LOOP;
END;
$$;
