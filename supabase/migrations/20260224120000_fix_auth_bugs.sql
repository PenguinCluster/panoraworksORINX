-- Fix BUG 2: Safe deletion helper
CREATE OR REPLACE FUNCTION admin_cleanup_user(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    team_rec RECORD;
    member_count INT;
BEGIN
    -- Loop through teams owned by this user
    FOR team_rec IN SELECT id, name FROM public.teams WHERE owner_id = target_user_id LOOP
        -- Check if there are other active members (excluding the owner)
        SELECT COUNT(*) INTO member_count
        FROM public.team_members
        WHERE team_id = team_rec.id
          AND user_id != target_user_id
          AND status = 'active';

        IF member_count > 0 THEN
            RAISE EXCEPTION 'User owns team "%" (%) with % active members. Please transfer ownership or remove members first.', 
                team_rec.name, team_rec.id, member_count;
        ELSE
            -- Safe to delete the team (and cascade to members/invites)
            DELETE FROM public.teams WHERE id = team_rec.id;
            RAISE NOTICE 'Deleted owned team "%" (%)', team_rec.name, team_rec.id;
        END IF;
    END LOOP;
END;
$$;

-- Fix Task 4: Deterministic Team Membership Selection
-- Drop first to allow return type change if needed
DROP FUNCTION IF EXISTS get_my_active_team_membership();

CREATE OR REPLACE FUNCTION get_my_active_team_membership()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
    membership RECORD;
BEGIN
    -- Explicitly select fields to avoid ambiguity
    SELECT 
        tm.team_id, 
        tm.role, 
        tm.status, 
        tm.created_at
    INTO membership
    FROM public.team_members tm
    WHERE tm.user_id = auth.uid()
      AND tm.status = 'active'
    ORDER BY 
        (tm.role = 'owner') ASC, -- Prioritize invited teams (non-owners)
        tm.created_at DESC       -- Newest first
    LIMIT 1;

    IF membership IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT json_build_object(
        'team_id', membership.team_id,
        'role', membership.role,
        'status', membership.status,
        'workspace', (
            SELECT json_build_object(
                'display_name', tp.display_name,
                'avatar_url', tp.avatar_url,
                'brand_name', tp.brand_name,
                'brand_color', tp.brand_color,
                'settings', tp.settings
            )
            FROM public.team_profiles tp
            WHERE tp.team_id = membership.team_id
        )
    ) INTO result;

    RETURN result;
END;
$$;

-- Update get_my_workspace_context to use the deterministic logic
DROP FUNCTION IF EXISTS get_my_workspace_context();

CREATE OR REPLACE FUNCTION get_my_workspace_context()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    membership json;
BEGIN
    membership := get_my_active_team_membership();
    
    IF membership IS NULL THEN
        RETURN json_build_object('has_team', false);
    ELSE
        RETURN json_build_object(
            'has_team', true,
            'team_id', membership->>'team_id',
            'role', membership->>'role',
            'status', membership->>'status',
            'workspace', membership->'workspace'
        );
    END IF;
END;
$$;
