-- 1) Add password_initialized column to profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS password_initialized boolean NOT NULL DEFAULT false;

-- 2) Backfill: Assume existing users have initialized passwords
-- (Optional: You might want to leave this false for everyone if you can't be sure, 
-- or assume true if they have signed in before. 
-- A safer bet for existing active users is TRUE.)
UPDATE public.profiles 
SET password_initialized = true 
WHERE id IN (
    SELECT id FROM auth.users 
    WHERE confirmed_at IS NOT NULL
);

-- 3) Create helper to mark password as set
CREATE OR REPLACE FUNCTION public.mark_password_initialized()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.profiles
    SET password_initialized = true, updated_at = now()
    WHERE id = auth.uid();
END;
$$;
