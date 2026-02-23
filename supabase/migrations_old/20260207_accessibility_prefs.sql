-- Add accessibility_prefs column to profiles table
alter table public.profiles 
add column if not exists accessibility_prefs jsonb default '{}'::jsonb;
