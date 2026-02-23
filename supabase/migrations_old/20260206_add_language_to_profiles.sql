-- Add language column to profiles table
alter table profiles 
add column language text default 'English';
