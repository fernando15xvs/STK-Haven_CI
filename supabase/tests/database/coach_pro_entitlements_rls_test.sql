begin;

select plan(26);

select has_table(
  'public',
  'stk_subscription_entitlements',
  'subscription entitlement table exists'
);

select has_table(
  'public',
  'stk_entitlement_audit_events',
  'entitlement audit table exists'
);

select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_subscription_entitlements'::regclass
  ),
  'RLS is enabled on subscription entitlements'
);

select ok(
  not exists (
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name = 'stk_subscription_entitlements'
       and grantee = 'authenticated'
  ),
  'authenticated has no direct table privileges on entitlements'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.stk_set_subscription_entitlement(uuid,text,text,text,integer,timestamptz,timestamptz,timestamptz,text,text)',
    'EXECUTE'
  ),
  'authenticated cannot call server entitlement writer'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.stk_set_subscription_entitlement(uuid,text,text,text,integer,timestamptz,timestamptz,timestamptz,text,text)',
    'EXECUTE'
  ),
  'service role can call server entitlement writer'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
)
values
(
  '41414141-4141-4141-4141-414141414141',
  'authenticated','authenticated','coach-pro@example.com','',now(),now(),now(),
  '{}'::jsonb,'{}'::jsonb
),
(
  '42424242-4242-4242-4242-424242424242',
  'authenticated','authenticated','client-pro-a@example.com','',now(),now(),now(),
  '{}'::jsonb,'{}'::jsonb
),
(
  '43434343-4343-4343-4343-434343434343',
  'authenticated','authenticated','client-pro-b@example.com','',now(),now(),now(),
  '{}'::jsonb,'{}'::jsonb
);

insert into public.stk_user_profiles (user_id, display_name)
values
  ('41414141-4141-4141-4141-414141414141', 'Coach Pro'),
  ('42424242-4242-4242-4242-424242424242', 'Client Pro A'),
  ('43434343-4343-4343-4343-434343434343', 'Client Pro B');

insert into public.stk_user_capabilities (user_id, capability)
values
  ('41414141-4141-4141-4141-414141414141', 'coach'),
  ('42424242-4242-4242-4242-424242424242', 'athlete'),
  ('43434343-4343-4343-4343-434343434343', 'athlete');

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"41414141-4141-4141-4141-414141414141","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  public.stk_get_own_subscription_entitlement('coach_pro') ->> 'exists',
  'false',
  'coach role alone has no commercial entitlement'
);

select is(
  public.stk_get_own_subscription_entitlement('coach_pro') ->> 'access_active',
  'false',
  'coach role alone does not unlock Coach Pro'
);

select throws_ok(
  $$select public.stk_create_coach_invitation(
      '{"assign_programs":true}'::jsonb,
      168
    )$$,
  'P0001',
  'Coach Pro entitlement required',
  'coach capability cannot bypass missing Coach Pro entitlement'
);

reset role;

insert into public.stk_subscription_entitlements (
  user_id, product, status, tier, client_limit,
  starts_at, current_period_end, source
)
values (
  '41414141-4141-4141-4141-414141414141',
  'coach_pro',
  'active',
  'test',
  1,
  now() - interval '1 day',
  now() + interval '30 days',
  'pgTap'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"41414141-4141-4141-4141-414141414141","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  public.stk_get_own_subscription_entitlement('coach_pro') ->> 'access_active',
  'true',
  'server entitlement activates Coach Pro'
);

select is(
  public.stk_get_own_subscription_entitlement('coach_pro') ->> 'client_limit',
  '1',
  'server snapshot exposes configured client limit'
);

select lives_ok(
  $$create temporary table _coach_pro_invite_a as
    select public.stk_create_coach_invitation(
      '{"assign_programs":true}'::jsonb,
      168
    ) as code$$,
  'entitled coach can create first invitation'
);

select lives_ok(
  $$create temporary table _coach_pro_invite_b as
    select public.stk_create_coach_invitation(
      '{"assign_programs":true}'::jsonb,
      168
    ) as code$$,
  'entitled coach can create second pending invitation before capacity is used'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"42424242-4242-4242-4242-424242424242","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $$create temporary table _coach_pro_relationship as
    select public.stk_accept_coach_invitation(
      (select code from _coach_pro_invite_a limit 1)
    ) as relationship_id$$,
  'first client can accept while coach has capacity'
);

select is(
  (
    select count(*)::integer
      from public.stk_coach_client_relationships
     where coach_user_id = '41414141-4141-4141-4141-414141414141'
       and status = 'active'
  ),
  1,
  'active relationship consumes one client slot'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"43434343-4343-4343-4343-434343434343","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select public.stk_accept_coach_invitation(
      (select code from _coach_pro_invite_b limit 1)
    )$$,
  'P0001',
  'Coach Pro client limit reached',
  'second client cannot activate beyond server client limit'
);

reset role;

update public.stk_subscription_entitlements
   set status = 'expired',
       current_period_end = now() - interval '1 minute',
       updated_at = now()
 where user_id = '41414141-4141-4141-4141-414141414141'
   and product = 'coach_pro';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"41414141-4141-4141-4141-414141414141","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  public.stk_get_own_subscription_entitlement('coach_pro') ->> 'access_active',
  'false',
  'expired server entitlement removes Coach Pro access'
);

select is(
  (
    select count(*)::integer
      from public.stk_user_capabilities
     where user_id = '41414141-4141-4141-4141-414141414141'
       and capability = 'coach'
  ),
  1,
  'coach role remains present after entitlement expires'
);

select throws_ok(
  $$select public.stk_create_coach_invitation(
      '{"assign_programs":true}'::jsonb,
      168
    )$$,
  'P0001',
  'Coach Pro entitlement required',
  'expired coach cannot create new invitations'
);

select throws_ok(
  $$select public.stk_assign_program(
      '42424242-4242-4242-4242-424242424242',
      '{
        "name":"Blocked plan",
        "duration_weeks":4,
        "training_weekdays":[1],
        "routines":[{
          "name":"Day A",
          "exercises":[{
            "name":"Squat",
            "target_sets":3,
            "target_reps_min":8,
            "target_reps_max":10,
            "rest_seconds":120
          }]
        }]
      }'::jsonb
    )$$,
  'P0001',
  'Coach Pro entitlement required',
  'expired coach cannot assign a new program even with client permission'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"42424242-4242-4242-4242-424242424242","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $$select public.stk_set_coach_permissions(
      (select relationship_id from _coach_pro_relationship limit 1),
      '{"view_progress":true}'::jsonb
    )$$,
  'client can still change permissions after coach entitlement expires'
);

select lives_ok(
  $$select public.stk_revoke_coach_relationship(
      (select relationship_id from _coach_pro_relationship limit 1)
    )$$,
  'client can revoke relationship after coach entitlement expires'
);

select is(
  (
    select status
      from public.stk_coach_client_relationships
     where id = (
       select relationship_id
         from _coach_pro_relationship
        limit 1
     )
  ),
  'revoked',
  'revocation preserves client control independent of coach billing'
);

reset role;
set local role service_role;

select is(
  public.stk_set_subscription_entitlement(
    '41414141-4141-4141-4141-414141414141',
    'coach_pro',
    'active',
    'test',
    2,
    now(),
    now() + interval '30 days',
    null,
    'test_backend',
    'evt-r4-001'
  ),
  true,
  'service-role entitlement event applies once'
);

select is(
  public.stk_set_subscription_entitlement(
    '41414141-4141-4141-4141-414141414141',
    'coach_pro',
    'expired',
    'test',
    2,
    now(),
    now() - interval '1 minute',
    null,
    'test_backend',
    'evt-r4-001'
  ),
  false,
  'duplicate event key is idempotently ignored'
);

reset role;

select is(
  (
    select status
      from public.stk_subscription_entitlements
     where user_id = '41414141-4141-4141-4141-414141414141'
       and product = 'coach_pro'
  ),
  'active',
  'duplicate stale event did not overwrite entitlement state'
);

select * from finish();

rollback;
