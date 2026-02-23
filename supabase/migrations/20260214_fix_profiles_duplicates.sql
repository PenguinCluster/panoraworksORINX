-- Identify duplicates
SELECT id, COUNT(*)
FROM public.profiles
GROUP BY id
HAVING COUNT(*) > 1;

-- Identify duplicates by username (if unique constraint was missing)
SELECT username, COUNT(*)
FROM public.profiles
GROUP BY username
HAVING COUNT(*) > 1;

-- If duplicates exist on ID (which shouldn't happen with PK, but maybe RLS view weirdness or something else)
-- We can't really have duplicates on PK 'id' in a real Postgres table.
-- The error "JSON object requested, multiple (or no) rows returned" often happens if:
-- 1. RLS policies allow seeing multiple rows for the same query (unlikely for ID lookup)
-- 2. The query is matching multiple things.
-- 3. There is a join involved? No, simple select.

-- Wait, if 'id' is PK, duplicates are impossible physically.
-- BUT if the user has multiple rows in 'profiles' that somehow match?
-- Ah, maybe the RLS policy is weird?
-- "Users can view own profile" using ((auth.uid() = id));
-- "Public profiles are viewable by everyone" using (true);

-- If both policies exist and are permissive (OR), then for my own profile:
-- 1. I match "Users can view own profile"
-- 2. I match "Public profiles are viewable by everyone"
-- Does this return duplicate rows? No, Postgres RLS combines them.

-- However, if there are multiple rows in the TABLE with the same ID? Impossible due to PK.
-- Maybe 'profiles' is a VIEW? No, it's a table in the schema.

-- The error `PostgrestException code 406: "JSON object requested, multiple (or no) rows returned. Results contain 2 rows..."`
-- This EXPLICITLY says the query returned 2 rows.
-- If I query `select * from profiles where id = 'my-uuid'`, and I get 2 rows...
-- That means the `id` column is NOT unique?
-- Let's check the schema again.
-- `CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);`
-- `alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";`
-- So ID is PK. It MUST be unique.

-- HYPOTHESIS: The client is sending a query that matches multiple rows?
-- `.eq('id', userId)`
-- If userId is correct, it matches 1 row.

-- WAIT. Is it possible the trigger `handle_new_user` created a profile, AND the user code created a profile?
-- `insert into public.profiles ... on conflict (id) do nothing;`
-- That handles duplicates.

-- Let's look at the error again. "Results contain 2 rows".
-- Could it be that `userId` variable is somehow null or empty?
-- If `userId` is empty string? `.eq('id', '')` -> 0 rows.
-- If `userId` is not being filtered correctly?

-- ANOTHER POSSIBILITY: The Supabase Flutter SDK `maybeSingle()` expects 0 or 1 row.
-- If it gets 2, it throws 406.
-- How can `select * from profiles where id = X` return 2 rows?
-- Only if `id` is NOT unique.

-- Let's assume for a moment that somehow there ARE duplicates or the query is wrong.
-- I added `.limit(1)` in the Flutter code. This forces 1 row.
-- But we should verify data integrity.

-- SQL to remove duplicates (keeping latest updated):
WITH duplicates AS (
  SELECT id,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC) as rn
  FROM public.profiles
)
DELETE FROM public.profiles
WHERE id IN (
  SELECT id FROM duplicates WHERE rn > 1
);

-- Ensure PK exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_pkey') THEN
        ALTER TABLE public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
    END IF;
END $$;
