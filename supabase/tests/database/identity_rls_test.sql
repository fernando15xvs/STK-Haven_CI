begin;

select plan(18);

select has_table(
  'public',
  'stk_user_profiles',
  'identity profile table exists'
);

select has_table(
  'public',
  'stk_user_capabilities',
  'identity capability table exists'
);

select col_is_pk(
  'public',
  'stk_user_profiles',
  'user_id',
  'profile is keyed by auth user'
);

select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_user_profiles'::regclass
  ),
  'RLS is enabled on profiles'
);

select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_user_capabilities'::regclass
  ),
  'RLS is enabled on capabilities'
);

select ok(
  exists(
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'stk_user_profiles'
       and policyname = 'STK users can read own profile'
  ),
  'own-profile select policy exists'
);

select ok(
  exists(
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'stk_user_capabilities'
       and policyname = 'STK users can read own capabilities'
  ),
  'own-capabilities select policy exists'
);

select ok(
  exists(
    select 1
      from pg_proc
     where pronamespace = 'public'::regnamespace
       and proname = 'stk_sync_own_profile'
       and prosecdef = false
  ),
  'profile sync function uses invoker security'
);

select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name = 'stk_user_profiles'
       and grantee = 'anon'
  ),
  'anon has no direct profile table grants'
);

select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name = 'stk_user_capabilities'
       and grantee = 'anon'
  ),
  'anon has no direct capability table grants'
);

insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data
)
values
(
  '11111111-1111-1111-1111-111111111111',
  'authenticated',
  'authenticated',
  'athlete-one@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
),
(
  '22222222-2222-2222-2222-222222222222',
  'authenticated',
  'authenticated',
  'athlete-two@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
);

insert into public.stk_user_profiles (user_id, display_name)
values
  ('11111111-1111-1111-1111-111111111111', 'One'),
  ('22222222-2222-2222-2222-222222222222', 'Two');

insert into public.stk_user_capabilities (user_id, capability)
values
  ('11111111-1111-1111-1111-111111111111', 'athlete'),
  ('22222222-2222-2222-2222-222222222222', 'athlete');

set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_user_profiles),
  1,
  'permanent user sees only own profile'
);

select is(
  (select count(*)::integer from public.stk_user_capabilities),
  1,
  'permanent user sees only own capabilities'
);

select lives_ok(
  $$select public.stk_sync_own_profile('Updated One', array['athlete','coach']::text[])$$,
  'permanent user can sync own allowed capabilities'
);

select is(
  (
    select count(*)::integer
      from public.stk_user_capabilities
     where user_id = '11111111-1111-1111-1111-111111111111'
  ),
  2,
  'sync stores athlete and coach for own account'
);

select throws_ok(
  $$select public.stk_sync_own_profile(null, array['admin']::text[])$$,
  'P0001',
  'Unsupported STK capability: admin',
  'unsupported capability is rejected'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","is_anonymous":true}',
  true
);

select is(
  (select count(*)::integer from public.stk_user_profiles),
  0,
  'anonymous JWT cannot read profile rows'
);

select is(
  (select count(*)::integer from public.stk_user_capabilities),
  0,
  'anonymous JWT cannot read capability rows'
);

select throws_ok(
  $$select public.stk_sync_own_profile(null, array['athlete']::text[])$$,
  'P0001',
  'Permanent authenticated account required',
  'anonymous session cannot sync application profile'
);

select * from finish();

rollback;
