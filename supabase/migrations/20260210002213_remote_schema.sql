create extension if not exists "hypopg" with schema "extensions";

create extension if not exists "index_advisor" with schema "extensions";

drop extension if exists "pg_net";

create extension if not exists "citext" with schema "public";

create type "public"."invite_status" as enum ('pending', 'accepted', 'expired', 'revoked');

create type "public"."member_status" as enum ('pending', 'active', 'removed');

create type "public"."team_role" as enum ('owner', 'admin', 'manager');


  create table "public"."alert_rules" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "name" text not null,
    "condition" text not null,
    "destinations" jsonb default '[]'::jsonb,
    "is_active" boolean default true,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."alert_rules" enable row level security;


  create table "public"."billing_profiles" (
    "user_id" uuid not null,
    "full_name" text not null,
    "address_line1" text not null,
    "address_line2" text,
    "city" text not null,
    "state" text,
    "country" text not null,
    "postal_code" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."billing_profiles" enable row level security;


  create table "public"."connected_accounts" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "provider" text not null,
    "status" text not null default 'disconnected'::text,
    "tokens" jsonb,
    "metadata" jsonb default '{}'::jsonb,
    "expires_at" timestamp with time zone,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );


alter table "public"."connected_accounts" enable row level security;


  create table "public"."feature_requests" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "title" text not null,
    "description" text not null,
    "priority" text default 'medium'::text,
    "status" text not null default 'pending'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );


alter table "public"."feature_requests" enable row level security;


  create table "public"."monitored_keywords" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "keyword" text not null,
    "tags" text[],
    "status" text default 'active'::text,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."monitored_keywords" enable row level security;


  create table "public"."plans" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "price_monthly" numeric not null,
    "price_annual" numeric not null,
    "features" text[],
    "active" boolean default true,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."plans" enable row level security;


  create table "public"."posts" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "content" text,
    "media_urls" text[],
    "platforms" text[],
    "status" text not null default 'draft'::text,
    "scheduled_at" timestamp with time zone,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );


alter table "public"."posts" enable row level security;


  create table "public"."profiles" (
    "id" uuid not null,
    "updated_at" timestamp with time zone,
    "username" text,
    "full_name" text,
    "avatar_url" text,
    "website" text,
    "language" text default 'English'::text,
    "accessibility_prefs" jsonb default '{}'::jsonb
      );


alter table "public"."profiles" enable row level security;


  create table "public"."subscriptions" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "plan_id" uuid,
    "status" text not null default 'inactive'::text,
    "current_period_start" timestamp with time zone,
    "current_period_end" timestamp with time zone,
    "flutterwave_sub_id" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );


alter table "public"."subscriptions" enable row level security;


  create table "public"."support_messages" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "subject" text not null,
    "message" text not null,
    "status" text not null default 'new'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );


alter table "public"."support_messages" enable row level security;


  create table "public"."team_invites" (
    "id" uuid not null default gen_random_uuid(),
    "team_id" uuid not null,
    "email" public.citext not null,
    "role" public.team_role not null,
    "is_admin_toggle" boolean default false,
    "token" uuid not null default gen_random_uuid(),
    "status" public.invite_status not null default 'pending'::public.invite_status,
    "expires_at" timestamp with time zone default (now() + '7 days'::interval),
    "invited_by" uuid,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."team_invites" enable row level security;


  create table "public"."team_members" (
    "id" uuid not null default gen_random_uuid(),
    "team_id" uuid not null,
    "user_id" uuid,
    "email" public.citext not null,
    "role" public.team_role not null default 'manager'::public.team_role,
    "status" public.member_status not null default 'pending'::public.member_status,
    "invited_by" uuid,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );


alter table "public"."team_members" enable row level security;


  create table "public"."teams" (
    "id" uuid not null default gen_random_uuid(),
    "owner_id" uuid not null,
    "name" text not null,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."teams" enable row level security;


  create table "public"."transactions" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "amount" numeric not null,
    "currency" text not null default 'USD'::text,
    "status" text not null,
    "reference" text not null,
    "flutterwave_tx_id" text,
    "metadata" jsonb default '{}'::jsonb,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."transactions" enable row level security;

CREATE UNIQUE INDEX alert_rules_pkey ON public.alert_rules USING btree (id);

CREATE UNIQUE INDEX billing_profiles_pkey ON public.billing_profiles USING btree (user_id);

CREATE UNIQUE INDEX connected_accounts_pkey ON public.connected_accounts USING btree (id);

CREATE UNIQUE INDEX connected_accounts_user_id_provider_key ON public.connected_accounts USING btree (user_id, provider);

CREATE UNIQUE INDEX feature_requests_pkey ON public.feature_requests USING btree (id);

CREATE UNIQUE INDEX monitored_keywords_pkey ON public.monitored_keywords USING btree (id);

CREATE UNIQUE INDEX monitored_keywords_user_id_keyword_key ON public.monitored_keywords USING btree (user_id, keyword);

CREATE UNIQUE INDEX plans_pkey ON public.plans USING btree (id);

CREATE UNIQUE INDEX posts_pkey ON public.posts USING btree (id);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

CREATE UNIQUE INDEX profiles_username_key ON public.profiles USING btree (username);

CREATE UNIQUE INDEX subscriptions_pkey ON public.subscriptions USING btree (id);

CREATE UNIQUE INDEX subscriptions_user_unique ON public.subscriptions USING btree (user_id);

CREATE UNIQUE INDEX support_messages_pkey ON public.support_messages USING btree (id);

CREATE UNIQUE INDEX team_invites_pkey ON public.team_invites USING btree (id);

CREATE UNIQUE INDEX team_members_global_email_lock_idx ON public.team_members USING btree (email) WHERE (status = ANY (ARRAY['pending'::public.member_status, 'active'::public.member_status]));

CREATE UNIQUE INDEX team_members_pkey ON public.team_members USING btree (id);

CREATE UNIQUE INDEX team_members_team_email_idx ON public.team_members USING btree (team_id, email) WHERE (status = ANY (ARRAY['pending'::public.member_status, 'active'::public.member_status]));

CREATE UNIQUE INDEX teams_pkey ON public.teams USING btree (id);

CREATE UNIQUE INDEX transactions_pkey ON public.transactions USING btree (id);

CREATE UNIQUE INDEX transactions_reference_key ON public.transactions USING btree (reference);

alter table "public"."alert_rules" add constraint "alert_rules_pkey" PRIMARY KEY using index "alert_rules_pkey";

alter table "public"."billing_profiles" add constraint "billing_profiles_pkey" PRIMARY KEY using index "billing_profiles_pkey";

alter table "public"."connected_accounts" add constraint "connected_accounts_pkey" PRIMARY KEY using index "connected_accounts_pkey";

alter table "public"."feature_requests" add constraint "feature_requests_pkey" PRIMARY KEY using index "feature_requests_pkey";

alter table "public"."monitored_keywords" add constraint "monitored_keywords_pkey" PRIMARY KEY using index "monitored_keywords_pkey";

alter table "public"."plans" add constraint "plans_pkey" PRIMARY KEY using index "plans_pkey";

alter table "public"."posts" add constraint "posts_pkey" PRIMARY KEY using index "posts_pkey";

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."subscriptions" add constraint "subscriptions_pkey" PRIMARY KEY using index "subscriptions_pkey";

alter table "public"."support_messages" add constraint "support_messages_pkey" PRIMARY KEY using index "support_messages_pkey";

alter table "public"."team_invites" add constraint "team_invites_pkey" PRIMARY KEY using index "team_invites_pkey";

alter table "public"."team_members" add constraint "team_members_pkey" PRIMARY KEY using index "team_members_pkey";

alter table "public"."teams" add constraint "teams_pkey" PRIMARY KEY using index "teams_pkey";

alter table "public"."transactions" add constraint "transactions_pkey" PRIMARY KEY using index "transactions_pkey";

alter table "public"."alert_rules" add constraint "alert_rules_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."alert_rules" validate constraint "alert_rules_user_id_fkey";

alter table "public"."billing_profiles" add constraint "billing_profiles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."billing_profiles" validate constraint "billing_profiles_user_id_fkey";

alter table "public"."connected_accounts" add constraint "connected_accounts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."connected_accounts" validate constraint "connected_accounts_user_id_fkey";

alter table "public"."connected_accounts" add constraint "connected_accounts_user_id_provider_key" UNIQUE using index "connected_accounts_user_id_provider_key";

alter table "public"."feature_requests" add constraint "feature_requests_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."feature_requests" validate constraint "feature_requests_user_id_fkey";

alter table "public"."monitored_keywords" add constraint "monitored_keywords_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."monitored_keywords" validate constraint "monitored_keywords_user_id_fkey";

alter table "public"."monitored_keywords" add constraint "monitored_keywords_user_id_keyword_key" UNIQUE using index "monitored_keywords_user_id_keyword_key";

alter table "public"."posts" add constraint "posts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."posts" validate constraint "posts_user_id_fkey";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."profiles" add constraint "profiles_username_key" UNIQUE using index "profiles_username_key";

alter table "public"."profiles" add constraint "username_length" CHECK ((char_length(username) >= 3)) not valid;

alter table "public"."profiles" validate constraint "username_length";

alter table "public"."subscriptions" add constraint "subscriptions_plan_id_fkey" FOREIGN KEY (plan_id) REFERENCES public.plans(id) not valid;

alter table "public"."subscriptions" validate constraint "subscriptions_plan_id_fkey";

alter table "public"."subscriptions" add constraint "subscriptions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."subscriptions" validate constraint "subscriptions_user_id_fkey";

alter table "public"."subscriptions" add constraint "subscriptions_user_unique" UNIQUE using index "subscriptions_user_unique";

alter table "public"."support_messages" add constraint "support_messages_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."support_messages" validate constraint "support_messages_user_id_fkey";

alter table "public"."team_invites" add constraint "team_invites_invited_by_fkey" FOREIGN KEY (invited_by) REFERENCES auth.users(id) not valid;

alter table "public"."team_invites" validate constraint "team_invites_invited_by_fkey";

alter table "public"."team_invites" add constraint "team_invites_team_id_fkey" FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE not valid;

alter table "public"."team_invites" validate constraint "team_invites_team_id_fkey";

alter table "public"."team_members" add constraint "team_members_invited_by_fkey" FOREIGN KEY (invited_by) REFERENCES auth.users(id) not valid;

alter table "public"."team_members" validate constraint "team_members_invited_by_fkey";

alter table "public"."team_members" add constraint "team_members_team_id_fkey" FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE not valid;

alter table "public"."team_members" validate constraint "team_members_team_id_fkey";

alter table "public"."team_members" add constraint "team_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."team_members" validate constraint "team_members_user_id_fkey";

alter table "public"."teams" add constraint "teams_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) not valid;

alter table "public"."teams" validate constraint "teams_owner_id_fkey";

alter table "public"."transactions" add constraint "transactions_reference_key" UNIQUE using index "transactions_reference_key";

alter table "public"."transactions" add constraint "transactions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."transactions" validate constraint "transactions_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.accept_team_invite(invite_token uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  invite_record record;
  user_email text;
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  select email into user_email from auth.users where id = current_user_id;

  -- 1. Find the invite
  select * into invite_record
  from public.team_invites
  where token = invite_token
  and status = 'pending'
  and expires_at > now();

  if not found then
    return json_build_object('error', 'Invalid or expired invite token');
  end if;

  -- 2. Verify email match (case-insensitive)
  if lower(invite_record.email::text) != lower(user_email) then
    return json_build_object('error', 'Email mismatch: Please login with ' || invite_record.email);
  end if;

  -- 3. Update invite status
  update public.team_invites
  set status = 'accepted'
  where id = invite_record.id;

  -- 4. Update team_member status and link user_id
  update public.team_members
  set status = 'active',
      user_id = current_user_id,
      updated_at = now()
  where team_id = invite_record.team_id
  and email = invite_record.email; -- Already citext

  return json_build_object('success', true, 'team_id', invite_record.team_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.check_email_lock(check_email text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  member_record record;
  invite_record record;
begin
  -- Check team_members
  select * into member_record
  from public.team_members
  where email = check_email::citext
  and status in ('pending', 'active')
  limit 1;

  if found then
    return json_build_object(
      'locked', true,
      'team_id', member_record.team_id,
      'status', member_record.status,
      'source', 'member'
    );
  end if;

  -- Check team_invites
  select * into invite_record
  from public.team_invites
  where email = check_email::citext
  and status = 'pending'
  limit 1;

  if found then
    return json_build_object(
      'locked', true,
      'team_id', invite_record.team_id,
      'status', invite_record.status,
      'source', 'invite'
    );
  end if;

  return json_build_object(
    'locked', false
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_team_admin_or_owner(p_team_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Check Owner first (fastest)
  if exists (select 1 from public.teams where id = p_team_id and owner_id = p_user_id) then
    return true;
  end if;

  -- Check Admin role in members
  return exists (
    select 1 from public.team_members
    where team_id = p_team_id
    and user_id = p_user_id
    and role = 'admin'
    and status = 'active'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_team_member_active(p_team_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  return exists (
    select 1 from public.team_members
    where team_id = p_team_id
    and user_id = p_user_id
    and status = 'active'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_team_owner(p_team_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  return exists (
    select 1 from public.teams
    where id = p_team_id
    and owner_id = p_user_id
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  new_team_id uuid;
begin
  -- 1. Create Profile (if not exists)
  insert into public.profiles (id, email, full_name, avatar_url)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing;

  -- 2. Create Default Team
  insert into public.teams (owner_id, name)
  values (new.id, 'My Team')
  returning id into new_team_id;

  -- 3. Add User as Owner of that Team
  insert into public.team_members (team_id, user_id, email, role, status)
  values (new_team_id, new.id, new.email, 'owner', 'active');

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_successful_payment(p_user_id uuid, p_plan_id uuid, p_amount numeric, p_reference text, p_tx_id text, p_interval text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_period_end timestamp with time zone;
begin
  -- Calculate period end based on interval
  if p_interval = 'yearly' then
    v_period_end := now() + interval '1 year';
  else
    v_period_end := now() + interval '1 month';
  end if;

  -- Record transaction
  insert into public.transactions (user_id, amount, status, reference, flutterwave_tx_id)
  values (p_user_id, p_amount, 'successful', p_reference, p_tx_id);

  -- Update or Insert Subscription
  insert into public.subscriptions (user_id, plan_id, status, current_period_start, current_period_end)
  values (p_user_id, p_plan_id, 'active', now(), v_period_end)
  on conflict (id) do nothing; -- Simpler to just update if we enforced 1 sub per user, but for now we insert new.
  
  -- Better logic: Upsert based on user_id if we only allow 1 active sub per user
  -- For MVP, let's assume we update the latest subscription or create one if none exists.
  if exists (select 1 from public.subscriptions where user_id = p_user_id) then
     update public.subscriptions
     set plan_id = p_plan_id,
         status = 'active',
         current_period_start = now(),
         current_period_end = v_period_end,
         updated_at = now()
     where user_id = p_user_id;
  else
     insert into public.subscriptions (user_id, plan_id, status, current_period_start, current_period_end)
     values (p_user_id, p_plan_id, 'active', now(), v_period_end);
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.remove_team_member(target_member_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  requester_id uuid;
  target_record record;
  requester_role public.team_role;
begin
  requester_id := auth.uid();

  -- Get target member details
  select * into target_record
  from public.team_members
  where id = target_member_id;

  if not found then
    return json_build_object('error', 'Member not found');
  end if;

  -- Get requester's role in that team
  select role into requester_role
  from public.team_members
  where team_id = target_record.team_id
  and user_id = requester_id
  and status = 'active';

  -- Check Permissions
  -- Rule: Only Owner can remove Admin/Manager.
  if requester_role != 'owner' then
     return json_build_object('error', 'Only the Team Owner can remove members.');
  end if;

  -- Rule: Admin cannot remove Owner (Implicit since requester must be owner)
  -- But check if target is owner
  if target_record.role = 'owner' then
    return json_build_object('error', 'Cannot remove the Team Owner.');
  end if;

  -- Execute Removal
  update public.team_members
  set status = 'removed', updated_at = now()
  where id = target_member_id;

  -- Revoke any pending invites for this email on this team
  update public.team_invites
  set status = 'revoked'
  where team_id = target_record.team_id
  and email = target_record.email
  and status = 'pending';

  return json_build_object('success', true);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.send_team_invite(invite_email text, invite_team_id uuid, invite_role public.team_role, invite_is_admin_toggle boolean)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  existing_member record;
  invite_token uuid;
  new_invite_id uuid;
  inviter_id uuid;
begin
  inviter_id := auth.uid();

  -- 1. Check if inviter is owner or admin of the team
  if not exists (
    select 1 from public.teams where id = invite_team_id and owner_id = inviter_id
  ) and not exists (
    select 1 from public.team_members 
    where team_id = invite_team_id 
    and user_id = inviter_id 
    and role in ('owner', 'admin') 
    and status = 'active'
  ) then
    return json_build_object('error', 'Permission denied');
  end if;

  -- 2. Check if user is already a member (pending or active)
  select * into existing_member 
  from public.team_members 
  where team_id = invite_team_id 
  and email = invite_email::citext 
  and status in ('pending', 'active');

  if found then
    return json_build_object('error', 'User is already a member or has a pending invite');
  end if;

  -- 3. Check if user is locked to another team
  if exists (
    select 1 from public.team_members
    where email = invite_email::citext
    and status in ('pending', 'active')
    and team_id != invite_team_id
  ) then
    return json_build_object('error', 'User is already a member of another team');
  end if;

  -- 4. Create/Upsert Invite
  invite_token := gen_random_uuid();
  
  insert into public.team_invites (
    team_id, email, role, is_admin_toggle, token, status, expires_at, invited_by
  )
  values (
    invite_team_id,
    invite_email::citext,
    invite_role,
    invite_is_admin_toggle,
    invite_token,
    'pending',
    now() + interval '7 days',
    inviter_id
  )
  returning id into new_invite_id;

  -- 5. Create pending team_member row
  insert into public.team_members (
    team_id, email, role, status, invited_by
  )
  values (
    invite_team_id,
    invite_email::citext,
    invite_role,
    'pending',
    inviter_id
  )
  on conflict (email) where status in ('pending', 'active') 
  do nothing; -- Should be handled by previous checks but safety net

  return json_build_object(
    'success', true,
    'invite_id', new_invite_id,
    'token', invite_token
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.update_connected_account(p_user_id uuid, p_provider text, p_status text, p_tokens jsonb, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  insert into public.connected_accounts (user_id, provider, status, tokens, expires_at, updated_at)
  values (p_user_id, p_provider, p_status, p_tokens, p_expires_at, now())
  on conflict (user_id, p_provider)
  do update set
    status = excluded.status,
    tokens = excluded.tokens,
    expires_at = excluded.expires_at,
    updated_at = now();
end;
$function$
;

grant delete on table "public"."alert_rules" to "anon";

grant insert on table "public"."alert_rules" to "anon";

grant references on table "public"."alert_rules" to "anon";

grant select on table "public"."alert_rules" to "anon";

grant trigger on table "public"."alert_rules" to "anon";

grant truncate on table "public"."alert_rules" to "anon";

grant update on table "public"."alert_rules" to "anon";

grant delete on table "public"."alert_rules" to "authenticated";

grant insert on table "public"."alert_rules" to "authenticated";

grant references on table "public"."alert_rules" to "authenticated";

grant select on table "public"."alert_rules" to "authenticated";

grant trigger on table "public"."alert_rules" to "authenticated";

grant truncate on table "public"."alert_rules" to "authenticated";

grant update on table "public"."alert_rules" to "authenticated";

grant delete on table "public"."alert_rules" to "service_role";

grant insert on table "public"."alert_rules" to "service_role";

grant references on table "public"."alert_rules" to "service_role";

grant select on table "public"."alert_rules" to "service_role";

grant trigger on table "public"."alert_rules" to "service_role";

grant truncate on table "public"."alert_rules" to "service_role";

grant update on table "public"."alert_rules" to "service_role";

grant delete on table "public"."billing_profiles" to "anon";

grant insert on table "public"."billing_profiles" to "anon";

grant references on table "public"."billing_profiles" to "anon";

grant select on table "public"."billing_profiles" to "anon";

grant trigger on table "public"."billing_profiles" to "anon";

grant truncate on table "public"."billing_profiles" to "anon";

grant update on table "public"."billing_profiles" to "anon";

grant delete on table "public"."billing_profiles" to "authenticated";

grant insert on table "public"."billing_profiles" to "authenticated";

grant references on table "public"."billing_profiles" to "authenticated";

grant select on table "public"."billing_profiles" to "authenticated";

grant trigger on table "public"."billing_profiles" to "authenticated";

grant truncate on table "public"."billing_profiles" to "authenticated";

grant update on table "public"."billing_profiles" to "authenticated";

grant delete on table "public"."billing_profiles" to "service_role";

grant insert on table "public"."billing_profiles" to "service_role";

grant references on table "public"."billing_profiles" to "service_role";

grant select on table "public"."billing_profiles" to "service_role";

grant trigger on table "public"."billing_profiles" to "service_role";

grant truncate on table "public"."billing_profiles" to "service_role";

grant update on table "public"."billing_profiles" to "service_role";

grant delete on table "public"."connected_accounts" to "anon";

grant insert on table "public"."connected_accounts" to "anon";

grant references on table "public"."connected_accounts" to "anon";

grant select on table "public"."connected_accounts" to "anon";

grant trigger on table "public"."connected_accounts" to "anon";

grant truncate on table "public"."connected_accounts" to "anon";

grant update on table "public"."connected_accounts" to "anon";

grant delete on table "public"."connected_accounts" to "authenticated";

grant insert on table "public"."connected_accounts" to "authenticated";

grant references on table "public"."connected_accounts" to "authenticated";

grant select on table "public"."connected_accounts" to "authenticated";

grant trigger on table "public"."connected_accounts" to "authenticated";

grant truncate on table "public"."connected_accounts" to "authenticated";

grant update on table "public"."connected_accounts" to "authenticated";

grant delete on table "public"."connected_accounts" to "service_role";

grant insert on table "public"."connected_accounts" to "service_role";

grant references on table "public"."connected_accounts" to "service_role";

grant select on table "public"."connected_accounts" to "service_role";

grant trigger on table "public"."connected_accounts" to "service_role";

grant truncate on table "public"."connected_accounts" to "service_role";

grant update on table "public"."connected_accounts" to "service_role";

grant delete on table "public"."feature_requests" to "anon";

grant insert on table "public"."feature_requests" to "anon";

grant references on table "public"."feature_requests" to "anon";

grant select on table "public"."feature_requests" to "anon";

grant trigger on table "public"."feature_requests" to "anon";

grant truncate on table "public"."feature_requests" to "anon";

grant update on table "public"."feature_requests" to "anon";

grant delete on table "public"."feature_requests" to "authenticated";

grant insert on table "public"."feature_requests" to "authenticated";

grant references on table "public"."feature_requests" to "authenticated";

grant select on table "public"."feature_requests" to "authenticated";

grant trigger on table "public"."feature_requests" to "authenticated";

grant truncate on table "public"."feature_requests" to "authenticated";

grant update on table "public"."feature_requests" to "authenticated";

grant delete on table "public"."feature_requests" to "service_role";

grant insert on table "public"."feature_requests" to "service_role";

grant references on table "public"."feature_requests" to "service_role";

grant select on table "public"."feature_requests" to "service_role";

grant trigger on table "public"."feature_requests" to "service_role";

grant truncate on table "public"."feature_requests" to "service_role";

grant update on table "public"."feature_requests" to "service_role";

grant delete on table "public"."monitored_keywords" to "anon";

grant insert on table "public"."monitored_keywords" to "anon";

grant references on table "public"."monitored_keywords" to "anon";

grant select on table "public"."monitored_keywords" to "anon";

grant trigger on table "public"."monitored_keywords" to "anon";

grant truncate on table "public"."monitored_keywords" to "anon";

grant update on table "public"."monitored_keywords" to "anon";

grant delete on table "public"."monitored_keywords" to "authenticated";

grant insert on table "public"."monitored_keywords" to "authenticated";

grant references on table "public"."monitored_keywords" to "authenticated";

grant select on table "public"."monitored_keywords" to "authenticated";

grant trigger on table "public"."monitored_keywords" to "authenticated";

grant truncate on table "public"."monitored_keywords" to "authenticated";

grant update on table "public"."monitored_keywords" to "authenticated";

grant delete on table "public"."monitored_keywords" to "service_role";

grant insert on table "public"."monitored_keywords" to "service_role";

grant references on table "public"."monitored_keywords" to "service_role";

grant select on table "public"."monitored_keywords" to "service_role";

grant trigger on table "public"."monitored_keywords" to "service_role";

grant truncate on table "public"."monitored_keywords" to "service_role";

grant update on table "public"."monitored_keywords" to "service_role";

grant delete on table "public"."plans" to "anon";

grant insert on table "public"."plans" to "anon";

grant references on table "public"."plans" to "anon";

grant select on table "public"."plans" to "anon";

grant trigger on table "public"."plans" to "anon";

grant truncate on table "public"."plans" to "anon";

grant update on table "public"."plans" to "anon";

grant delete on table "public"."plans" to "authenticated";

grant insert on table "public"."plans" to "authenticated";

grant references on table "public"."plans" to "authenticated";

grant select on table "public"."plans" to "authenticated";

grant trigger on table "public"."plans" to "authenticated";

grant truncate on table "public"."plans" to "authenticated";

grant update on table "public"."plans" to "authenticated";

grant delete on table "public"."plans" to "service_role";

grant insert on table "public"."plans" to "service_role";

grant references on table "public"."plans" to "service_role";

grant select on table "public"."plans" to "service_role";

grant trigger on table "public"."plans" to "service_role";

grant truncate on table "public"."plans" to "service_role";

grant update on table "public"."plans" to "service_role";

grant delete on table "public"."posts" to "anon";

grant insert on table "public"."posts" to "anon";

grant references on table "public"."posts" to "anon";

grant select on table "public"."posts" to "anon";

grant trigger on table "public"."posts" to "anon";

grant truncate on table "public"."posts" to "anon";

grant update on table "public"."posts" to "anon";

grant delete on table "public"."posts" to "authenticated";

grant insert on table "public"."posts" to "authenticated";

grant references on table "public"."posts" to "authenticated";

grant select on table "public"."posts" to "authenticated";

grant trigger on table "public"."posts" to "authenticated";

grant truncate on table "public"."posts" to "authenticated";

grant update on table "public"."posts" to "authenticated";

grant delete on table "public"."posts" to "service_role";

grant insert on table "public"."posts" to "service_role";

grant references on table "public"."posts" to "service_role";

grant select on table "public"."posts" to "service_role";

grant trigger on table "public"."posts" to "service_role";

grant truncate on table "public"."posts" to "service_role";

grant update on table "public"."posts" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

grant delete on table "public"."subscriptions" to "anon";

grant insert on table "public"."subscriptions" to "anon";

grant references on table "public"."subscriptions" to "anon";

grant select on table "public"."subscriptions" to "anon";

grant trigger on table "public"."subscriptions" to "anon";

grant truncate on table "public"."subscriptions" to "anon";

grant update on table "public"."subscriptions" to "anon";

grant delete on table "public"."subscriptions" to "authenticated";

grant insert on table "public"."subscriptions" to "authenticated";

grant references on table "public"."subscriptions" to "authenticated";

grant select on table "public"."subscriptions" to "authenticated";

grant trigger on table "public"."subscriptions" to "authenticated";

grant truncate on table "public"."subscriptions" to "authenticated";

grant update on table "public"."subscriptions" to "authenticated";

grant delete on table "public"."subscriptions" to "service_role";

grant insert on table "public"."subscriptions" to "service_role";

grant references on table "public"."subscriptions" to "service_role";

grant select on table "public"."subscriptions" to "service_role";

grant trigger on table "public"."subscriptions" to "service_role";

grant truncate on table "public"."subscriptions" to "service_role";

grant update on table "public"."subscriptions" to "service_role";

grant delete on table "public"."support_messages" to "anon";

grant insert on table "public"."support_messages" to "anon";

grant references on table "public"."support_messages" to "anon";

grant select on table "public"."support_messages" to "anon";

grant trigger on table "public"."support_messages" to "anon";

grant truncate on table "public"."support_messages" to "anon";

grant update on table "public"."support_messages" to "anon";

grant delete on table "public"."support_messages" to "authenticated";

grant insert on table "public"."support_messages" to "authenticated";

grant references on table "public"."support_messages" to "authenticated";

grant select on table "public"."support_messages" to "authenticated";

grant trigger on table "public"."support_messages" to "authenticated";

grant truncate on table "public"."support_messages" to "authenticated";

grant update on table "public"."support_messages" to "authenticated";

grant delete on table "public"."support_messages" to "service_role";

grant insert on table "public"."support_messages" to "service_role";

grant references on table "public"."support_messages" to "service_role";

grant select on table "public"."support_messages" to "service_role";

grant trigger on table "public"."support_messages" to "service_role";

grant truncate on table "public"."support_messages" to "service_role";

grant update on table "public"."support_messages" to "service_role";

grant delete on table "public"."team_invites" to "anon";

grant insert on table "public"."team_invites" to "anon";

grant references on table "public"."team_invites" to "anon";

grant select on table "public"."team_invites" to "anon";

grant trigger on table "public"."team_invites" to "anon";

grant truncate on table "public"."team_invites" to "anon";

grant update on table "public"."team_invites" to "anon";

grant delete on table "public"."team_invites" to "authenticated";

grant insert on table "public"."team_invites" to "authenticated";

grant references on table "public"."team_invites" to "authenticated";

grant select on table "public"."team_invites" to "authenticated";

grant trigger on table "public"."team_invites" to "authenticated";

grant truncate on table "public"."team_invites" to "authenticated";

grant update on table "public"."team_invites" to "authenticated";

grant delete on table "public"."team_invites" to "service_role";

grant insert on table "public"."team_invites" to "service_role";

grant references on table "public"."team_invites" to "service_role";

grant select on table "public"."team_invites" to "service_role";

grant trigger on table "public"."team_invites" to "service_role";

grant truncate on table "public"."team_invites" to "service_role";

grant update on table "public"."team_invites" to "service_role";

grant delete on table "public"."team_members" to "anon";

grant insert on table "public"."team_members" to "anon";

grant references on table "public"."team_members" to "anon";

grant select on table "public"."team_members" to "anon";

grant trigger on table "public"."team_members" to "anon";

grant truncate on table "public"."team_members" to "anon";

grant update on table "public"."team_members" to "anon";

grant delete on table "public"."team_members" to "authenticated";

grant insert on table "public"."team_members" to "authenticated";

grant references on table "public"."team_members" to "authenticated";

grant select on table "public"."team_members" to "authenticated";

grant trigger on table "public"."team_members" to "authenticated";

grant truncate on table "public"."team_members" to "authenticated";

grant update on table "public"."team_members" to "authenticated";

grant delete on table "public"."team_members" to "service_role";

grant insert on table "public"."team_members" to "service_role";

grant references on table "public"."team_members" to "service_role";

grant select on table "public"."team_members" to "service_role";

grant trigger on table "public"."team_members" to "service_role";

grant truncate on table "public"."team_members" to "service_role";

grant update on table "public"."team_members" to "service_role";

grant delete on table "public"."teams" to "anon";

grant insert on table "public"."teams" to "anon";

grant references on table "public"."teams" to "anon";

grant select on table "public"."teams" to "anon";

grant trigger on table "public"."teams" to "anon";

grant truncate on table "public"."teams" to "anon";

grant update on table "public"."teams" to "anon";

grant delete on table "public"."teams" to "authenticated";

grant insert on table "public"."teams" to "authenticated";

grant references on table "public"."teams" to "authenticated";

grant select on table "public"."teams" to "authenticated";

grant trigger on table "public"."teams" to "authenticated";

grant truncate on table "public"."teams" to "authenticated";

grant update on table "public"."teams" to "authenticated";

grant delete on table "public"."teams" to "service_role";

grant insert on table "public"."teams" to "service_role";

grant references on table "public"."teams" to "service_role";

grant select on table "public"."teams" to "service_role";

grant trigger on table "public"."teams" to "service_role";

grant truncate on table "public"."teams" to "service_role";

grant update on table "public"."teams" to "service_role";

grant delete on table "public"."transactions" to "anon";

grant insert on table "public"."transactions" to "anon";

grant references on table "public"."transactions" to "anon";

grant select on table "public"."transactions" to "anon";

grant trigger on table "public"."transactions" to "anon";

grant truncate on table "public"."transactions" to "anon";

grant update on table "public"."transactions" to "anon";

grant delete on table "public"."transactions" to "authenticated";

grant insert on table "public"."transactions" to "authenticated";

grant references on table "public"."transactions" to "authenticated";

grant select on table "public"."transactions" to "authenticated";

grant trigger on table "public"."transactions" to "authenticated";

grant truncate on table "public"."transactions" to "authenticated";

grant update on table "public"."transactions" to "authenticated";

grant delete on table "public"."transactions" to "service_role";

grant insert on table "public"."transactions" to "service_role";

grant references on table "public"."transactions" to "service_role";

grant select on table "public"."transactions" to "service_role";

grant trigger on table "public"."transactions" to "service_role";

grant truncate on table "public"."transactions" to "service_role";

grant update on table "public"."transactions" to "service_role";


  create policy "Users can manage their own alert rules"
  on "public"."alert_rules"
  as permissive
  for all
  to public
using ((auth.uid() = user_id));



  create policy "Users can read own billing profile"
  on "public"."billing_profiles"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "Users can update own billing profile"
  on "public"."billing_profiles"
  as permissive
  for update
  to public
using ((auth.uid() = user_id));



  create policy "Users can upsert own billing profile"
  on "public"."billing_profiles"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "Users can update their own connection metadata"
  on "public"."connected_accounts"
  as permissive
  for update
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Users can view their own connected accounts status"
  on "public"."connected_accounts"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "Users can create feature requests"
  on "public"."feature_requests"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "Users can view their own feature requests"
  on "public"."feature_requests"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "Users can manage their own monitored keywords"
  on "public"."monitored_keywords"
  as permissive
  for all
  to public
using ((auth.uid() = user_id));



  create policy "Public plans are viewable by everyone."
  on "public"."plans"
  as permissive
  for select
  to public
using (true);



  create policy "Users can manage their own posts"
  on "public"."posts"
  as permissive
  for all
  to public
using ((auth.uid() = user_id));



  create policy "Public profiles are viewable by everyone."
  on "public"."profiles"
  as permissive
  for select
  to public
using (true);



  create policy "Users can insert their own profile."
  on "public"."profiles"
  as permissive
  for insert
  to public
with check ((auth.uid() = id));



  create policy "Users can update own profile."
  on "public"."profiles"
  as permissive
  for update
  to public
using ((auth.uid() = id));



  create policy "Users can view own subscription."
  on "public"."subscriptions"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "Users can create support messages"
  on "public"."support_messages"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "Users can view their own support messages"
  on "public"."support_messages"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "Owners and Admins can view and manage invites"
  on "public"."team_invites"
  as permissive
  for all
  to public
using (((EXISTS ( SELECT 1
   FROM public.teams
  WHERE ((teams.id = team_invites.team_id) AND (teams.owner_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM public.team_members
  WHERE ((team_members.team_id = team_invites.team_id) AND (team_members.user_id = auth.uid()) AND (team_members.role = ANY (ARRAY['owner'::public.team_role, 'admin'::public.team_role])) AND (team_members.status = 'active'::public.member_status))))));



  create policy "allow_delete_team_members"
  on "public"."team_members"
  as permissive
  for delete
  to public
using (public.fn_is_team_owner(team_id, auth.uid()));



  create policy "allow_insert_team_members"
  on "public"."team_members"
  as permissive
  for insert
  to public
with check ((public.fn_is_team_owner(team_id, auth.uid()) OR public.fn_is_team_admin_or_owner(team_id, auth.uid())));



  create policy "allow_select_team_members"
  on "public"."team_members"
  as permissive
  for select
  to public
using (((auth.uid() = user_id) OR public.fn_is_team_owner(team_id, auth.uid()) OR public.fn_is_team_member_active(team_id, auth.uid())));



  create policy "allow_update_team_members"
  on "public"."team_members"
  as permissive
  for update
  to public
using ((public.fn_is_team_owner(team_id, auth.uid()) OR public.fn_is_team_admin_or_owner(team_id, auth.uid())));



  create policy "Owners can update their teams"
  on "public"."teams"
  as permissive
  for update
  to public
using ((auth.uid() = owner_id));



  create policy "Owners can view their teams"
  on "public"."teams"
  as permissive
  for select
  to public
using ((auth.uid() = owner_id));



  create policy "allow_insert_teams"
  on "public"."teams"
  as permissive
  for insert
  to public
with check ((auth.role() = 'authenticated'::text));



  create policy "allow_select_teams"
  on "public"."teams"
  as permissive
  for select
  to public
using (((owner_id = auth.uid()) OR public.fn_is_team_member_active(id, auth.uid())));



  create policy "allow_update_teams"
  on "public"."teams"
  as permissive
  for update
  to public
using ((owner_id = auth.uid()));



  create policy "Users can view own transactions."
  on "public"."transactions"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));


CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


  create policy "Anyone can upload an avatar"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'avatars'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Anyone can view media"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'media'::text));



  create policy "Avatar images are publicly accessible"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'avatars'::text));



  create policy "Users can delete their own avatar"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'avatars'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));



  create policy "Users can update their own avatar"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'avatars'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));



  create policy "Users can upload media"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'media'::text) AND (auth.role() = 'authenticated'::text)));


CREATE TRIGGER objects_delete_delete_prefix AFTER DELETE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();

CREATE TRIGGER objects_insert_create_prefix BEFORE INSERT ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.objects_insert_prefix_trigger();

CREATE TRIGGER objects_update_create_prefix BEFORE UPDATE ON storage.objects FOR EACH ROW WHEN (((new.name <> old.name) OR (new.bucket_id <> old.bucket_id))) EXECUTE FUNCTION storage.objects_update_prefix_trigger();

CREATE TRIGGER prefixes_create_hierarchy BEFORE INSERT ON storage.prefixes FOR EACH ROW WHEN ((pg_trigger_depth() < 1)) EXECUTE FUNCTION storage.prefixes_insert_trigger();

CREATE TRIGGER prefixes_delete_hierarchy AFTER DELETE ON storage.prefixes FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();


