-- Inspect current RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename IN ('team_members','teams','team_invites') 
ORDER BY tablename, policyname;
