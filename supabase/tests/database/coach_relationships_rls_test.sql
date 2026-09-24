begin;

select plan(32);

select has_table(
  'public',
  'stk_coach_invitations',
  'coach invitation table exists'
);

select has_table(
  'public',
  'stk_coach_client_relationships',
  'coach/client relationship table exists'
);

select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_coach_invitations'::regclass
  ),
  'RLS is enabled on coach invitations'
);

select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_coach_client_relationships'::regclass
  ),
  'RLS is enabled on coach relationships'
);

select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name = 'stk_coach_client_relationships'
       and grantee = 'authenticated'
       and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ),
  'authenticated cannot mutate relationships directly'
);

select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name = 'stk_coach_invitations'
       and grantee = 'authenticated'
       and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ),
  'authenticated cannot mutate invitations directly'
);

select is(
  public.stk_valid_coach_permissions('{"admin":true}'::jsonb),
  false,
  'unsupported permission keys are rejected'
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
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  'authenticated',
  'authenticated',
  'coach-a@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
),
(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
  'authenticated',
  'authenticated',
  'client-a@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
),
(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
  'authenticated',
  'authenticated',
  'client-b@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
),
(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
  'authenticated',
  'authenticated',
  'coach-b@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
);

insert into public.stk_user_profiles (user_id, display_name)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'Coach A'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'Client A'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'Client B'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'Coach B');

insert into public.stk_user_capabilities (user_id, capability)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'coach'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'athlete'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'athlete'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'athlete'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'coach');

create temporary table _stk_invite_test (
  code text,
  relationship_id uuid
);
grant select, insert, update on table _stk_invite_test to authenticated;

set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $$insert into _stk_invite_test(code)
    select public.stk_create_coach_invitation(
      '{"view_workouts":true,"assign_programs":true}'::jsonb,
      24
    )$$,
  'coach can create an expiring invitation'
);

select is(
  (select length(code)::integer from _stk_invite_test limit 1),
  16,
  'raw invitation code has expected shareable length'
);

select is(
  (select count(*)::integer from public.stk_coach_invitations),
  1,
  'coach sees own pending invitation'
);

select is(
  public.stk_coach_can_access(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'view_workouts'
  ),
  false,
  'capability alone grants no client access before consent'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select public.stk_create_coach_invitation('{}'::jsonb, 24)$$,
  'P0001',
  'Coach capability required',
  'non-coach cannot create invitations'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (
    select count(*)::integer
      from public.stk_preview_coach_invitation(
        (select code from _stk_invite_test limit 1)
      )
  ),
  1,
  'client can preview a valid invitation before accepting'
);

select is(
  (
    select coach_user_id
      from public.stk_preview_coach_invitation(
        (select code from _stk_invite_test limit 1)
      )
  ),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'::uuid,
  'preview identifies the inviting coach without exposing unrelated users'
);

select lives_ok(
  $$update _stk_invite_test
       set relationship_id = public.stk_accept_coach_invitation(code)$$,
  'client can explicitly accept invitation'
);

select is(
  (select count(*)::integer from public.stk_coach_client_relationships),
  1,
  'client sees accepted relationship'
);

select is(
  (
    select counterpart_display_name
      from public.stk_list_my_coach_relationships()
     limit 1
  ),
  'Coach A',
  'client relationship list exposes only linked coach display name'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_coach_client_relationships),
  0,
  'unrelated client cannot read relationship'
);

select is(
  (
    select count(*)::integer
      from public.stk_list_my_coach_relationships()
  ),
  0,
  'unrelated client relationship RPC returns no linked users'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_coach_client_relationships),
  0,
  'unrelated coach cannot read relationship'
);

select is(
  public.stk_coach_can_access(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'view_workouts'
  ),
  false,
  'unrelated coach helper also denies access'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_coach_client_relationships),
  1,
  'linked coach can read own relationship'
);

select is(
  (
    select counterpart_display_name
      from public.stk_list_my_coach_relationships()
     limit 1
  ),
  'Client A',
  'coach relationship list exposes only linked client display name'
);

select is(
  public.stk_coach_can_access(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'view_workouts'
  ),
  true,
  'active relationship plus explicit permission grants access'
);

select is(
  public.stk_coach_can_access(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'view_measurements'
  ),
  false,
  'non-granted permission remains denied'
);

select is(
  public.stk_coach_can_access(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'unknown_permission'
  ),
  false,
  'unknown permission always fails closed'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $$select public.stk_set_coach_permissions(
      (select relationship_id from _stk_invite_test limit 1),
      '{"view_measurements":true}'::jsonb
    )$$,
  'client can replace coach permissions on active relationship'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  public.stk_coach_can_access(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'view_measurements'
  ),
  true,
  'coach access reflects client-updated permissions'
);

select is(
  public.stk_coach_can_access(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'view_workouts'
  ),
  false,
  'replacing permissions removes previously granted access'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $$select public.stk_revoke_coach_relationship(
      (select relationship_id from _stk_invite_test limit 1)
    )$$,
  'client can revoke coach access'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  public.stk_coach_can_access(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'view_measurements'
  ),
  false,
  'revocation immediately disables access helper'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated","is_anonymous":true}',
  true
);

select throws_ok(
  $$select public.stk_preview_coach_invitation('DOESNOTMATTER')$$,
  'P0001',
  'Permanent authenticated account required',
  'anonymous session cannot use coach invitation flow'
);

select * from finish();

rollback;
