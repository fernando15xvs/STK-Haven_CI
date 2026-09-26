begin;
select plan(12);

select has_table(
  'public',
  'stk_web_push_subscriptions',
  'Web Push subscription table exists'
);

select ok(
  (select relrowsecurity
     from pg_class
    where oid='public.stk_web_push_subscriptions'::regclass),
  'Web Push subscriptions use RLS'
);

select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema='public'
       and table_name='stk_web_push_subscriptions'
       and grantee='authenticated'
  ),
  'authenticated has no direct table privileges'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.stk_upsert_web_push_subscription(text,text,text,text)',
    'EXECUTE'
  ),
  'authenticated can call subscription RPC'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.stk_disable_web_push_subscription(text)',
    'EXECUTE'
  ),
  'authenticated can disable own subscription through RPC'
);

insert into auth.users(
  id,aud,role,email,encrypted_password,email_confirmed_at,
  created_at,updated_at,raw_app_meta_data,raw_user_meta_data
) values (
  'c5000000-0000-0000-0000-000000000001',
  'authenticated','authenticated','push-owner@example.com','',
  now(),now(),now(),'{}'::jsonb,'{}'::jsonb
),(
  'c5000000-0000-0000-0000-000000000002',
  'authenticated','authenticated','push-other@example.com','',
  now(),now(),now(),'{}'::jsonb,'{}'::jsonb
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"c5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $$select public.stk_upsert_web_push_subscription(
    'https://push.example.test/owner/1234567890',
    'BN-test-p256dh-value-12345678901234567890',
    'auth-key-1234567890',
    'pgTAP'
  )$$,
  'owner can register a subscription'
);

select is(
  public.stk_has_web_push_subscription(),
  true,
  'owner sees active subscription status'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"c5000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  public.stk_has_web_push_subscription(),
  false,
  'another user cannot see owner subscription status'
);

select is(
  public.stk_disable_web_push_subscription(
    'https://push.example.test/owner/1234567890'
  ),
  false,
  'another user cannot disable owner subscription'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"c5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  public.stk_disable_web_push_subscription(
    'https://push.example.test/owner/1234567890'
  ),
  true,
  'owner can disable own subscription'
);

select is(
  public.stk_has_web_push_subscription(),
  false,
  'disabled subscription is no longer active'
);

reset role;
select is(
  (
    select count(*)::int
      from public.stk_web_push_subscriptions
     where user_id='c5000000-0000-0000-0000-000000000001'
  ),
  1,
  'disabled subscription remains available for backend cleanup/audit'
);

select * from finish();
rollback;
