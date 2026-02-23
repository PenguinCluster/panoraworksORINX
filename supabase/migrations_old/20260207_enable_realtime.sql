-- Enable realtime for tables if not already enabled
begin;
  -- Add tables to realtime publication
  alter publication supabase_realtime add table public.profiles;
  alter publication supabase_realtime add table public.team_members;
  alter publication supabase_realtime add table public.transactions;
  alter publication supabase_realtime add table public.subscriptions;
commit;
