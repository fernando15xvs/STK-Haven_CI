-- No change to Supabase production: all writes here roll back in CI.
-- Regression against the EXISTING adult authorization RPC, not a new grant.
begin;
select plan(18);

select has_table('public', 'stk_nutrition_adult_verifications',
  'Existing private adult capability table is present');
select ok((select relrowsecurity from pg_class
           where oid = 'public.stk_nutrition_adult_verifications'::regclass),
  'Adult capability ledger enables RLS');
select ok(not has_table_privilege('anon',
  'public.stk_nutrition_adult_verifications', 'SELECT'),
  'Anon cannot read other identities capability data');
select ok(not has_table_privilege('authenticated',
  'public.stk_nutrition_adult_verifications', 'SELECT'),
  'Authenticated role cannot read private grants');
select ok(not has_table_privilege('authenticated',
  'public.stk_nutrition_adult_verifications', 'INSERT'),
  'Client cannot create its own grant');
select ok(not has_table_privilege('authenticated',
  'public.stk_nutrition_adult_verifications', 'DELETE'),
  'Client cannot delete grant history');
select ok(not has_function_privilege('authenticated',
  'public.stk_set_adult_nutrition_verification(uuid,boolean,text)', 'EXECUTE'),
  'No authenticated RPC to self-grant adult energy');
select ok(not has_function_privilege('anon',
  'public.stk_set_adult_nutrition_verification(uuid,boolean,text)', 'EXECUTE'),
  'Anonymous client cannot write privileged access');
select ok(has_function_privilege('service_role',
  'public.stk_set_adult_nutrition_verification(uuid,boolean,text)', 'EXECUTE'),
  'Trusted backend can revoke a grant');
select ok(not has_function_privilege('anon',
  'public.stk_has_adult_nutrition_access()', 'EXECUTE'),
  'Anonymous role cannot call adult reader');
select ok(has_function_privilege('authenticated',
  'public.stk_has_adult_nutrition_access()', 'EXECUTE'),
  'Authenticated reader exposes a boolean, not private rows');

insert into auth.users(
  id,aud,role,email,encrypted_password,email_confirmed_at,
  created_at,updated_at,raw_app_meta_data,raw_user_meta_data
) values
('fc000000-0000-0000-0000-000000000001',
 'authenticated','authenticated','ci-capability-a@example.com','',
 now(),now(),now(),'{}'::jsonb,'{"dob":"1980-01-01","adult_verified":true}'::jsonb),
('fc000000-0000-0000-0000-000000000002',
 'authenticated','authenticated','ci-capability-b@example.com','',
 now(),now(),now(),'{}'::jsonb,'{"dob":"2009-01-01","adult_verified":true}'::jsonb);

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"fc000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false,"user_metadata":{"adult_verified":true,"dob":"1980-01-01"}}',
  true);
select is(public.stk_has_adult_nutrition_access(), false,
  'Forged user metadata and declared birthday grant nothing');

reset role;
set local role service_role;
select lives_ok($$select public.stk_set_adult_nutrition_verification(
  'fc000000-0000-0000-0000-000000000001', true, 'ci_only_backend_review'
)$$, 'Server-only operation can record a test decision');

reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"fc000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true);
select is(public.stk_has_adult_nutrition_access(), true,
  'Trusted backend grant is visible to its owner');

select set_config('request.jwt.claims',
  '{"sub":"fc000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false,"user_metadata":{"adult_verified":true}}',
  true);
select is(public.stk_has_adult_nutrition_access(), false,
  'Account B cannot inherit the grant for account A');

select set_config('request.jwt.claims',
  '{"sub":"fc000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":true}',
  true);
select is(public.stk_has_adult_nutrition_access(), false,
  'Anonymous JWT is denied even with an existing adult grant');

reset role;
set local role service_role;
select lives_ok($$select public.stk_set_adult_nutrition_verification(
  'fc000000-0000-0000-0000-000000000001', false, 'ci_revocation'
)$$, 'Backend can revoke immediately');

reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"fc000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true);
select is(public.stk_has_adult_nutrition_access(), false,
  'Revocation disables previous access without any client cache');

select * from finish();
rollback;
