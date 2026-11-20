-- Independent operator approvals; isolated Supabase CI transactions only.
-- No real users, document hashes, grants, or operator assignments are written.
begin;
select plan(29);

select has_table('stk_secure','stk_nutrition_review_operators',
  'Privileged operator roster exists');
select has_table('stk_secure','stk_nutrition_review_requests',
  'Review tickets exist separately from end-user legal declarations');
select has_table('stk_secure','stk_nutrition_operator_audit',
  'Operator actions are separately audited');
select ok((select relrowsecurity from pg_class
  where oid='stk_secure.stk_nutrition_review_operators'::regclass),
  'Operator allowlist has RLS');
select ok((select relrowsecurity from pg_class
  where oid='stk_secure.stk_nutrition_review_requests'::regclass),
  'Review tickets have RLS');
select ok(not has_schema_privilege('authenticated','stk_secure','USAGE'),
  'Client cannot access private operator schema');
select ok(not has_table_privilege('authenticated',
  'stk_secure.stk_nutrition_review_operators','INSERT'),
  'Client cannot enroll itself as reviewer');
select ok(not has_table_privilege('authenticated',
  'stk_secure.stk_nutrition_review_requests','UPDATE'),
  'Client cannot forge a second signature in a table');
select ok(not has_function_privilege('anon',
  'public.stk_operator_request_nutrition_review(uuid,text,text,text,timestamptz)',
  'EXECUTE'),'Anonymous role has no operator API');
select ok(not has_function_privilege('anon',
  'public.stk_operator_approve_nutrition_review(uuid)',
  'EXECUTE'),'Anonymous role cannot approve review');

insert into auth.users (
  id,aud,role,email,encrypted_password,email_confirmed_at,
  created_at,updated_at,raw_app_meta_data,raw_user_meta_data
) values
('fe000000-0000-0000-0000-000000000001',
 'authenticated','authenticated','ci-stk-p-subject@example.com','',
 now(),now(),now(),'{}'::jsonb,'{"adult_verified":true}'::jsonb),
('fe000000-0000-0000-0000-000000000002',
 'authenticated','authenticated','ci-stk-p-reviewer-a@example.com','',
 now(),now(),now(),'{}'::jsonb,'{}'::jsonb),
('fe000000-0000-0000-0000-000000000003',
 'authenticated','authenticated','ci-stk-p-reviewer-b@example.com','',
 now(),now(),now(),'{}'::jsonb,'{}'::jsonb),
('fe000000-0000-0000-0000-000000000004',
 'authenticated','authenticated','ci-stk-p-outsider@example.com','',
 now(),now(),now(),'{}'::jsonb,'{"is_stk_admin":true}'::jsonb);

-- The MFA JWT must also reference a live, same-user Supabase Auth session.
-- Session IDs here are isolated synthetic CI fixtures, not production tokens.
insert into auth.sessions(id,user_id,created_at,updated_at,aal) values
('fa000000-0000-0000-0000-000000000002',
 'fe000000-0000-0000-0000-000000000002',now(),now(),'aal2'),
('fa000000-0000-0000-0000-000000000003',
 'fe000000-0000-0000-0000-000000000003',now(),now(),'aal2');

reset role;
set local role service_role;
insert into stk_secure.stk_legal_releases(
  terms_version,terms_sha256,terms_https_url,privacy_version,privacy_sha256,
  privacy_https_url,approved_reference,published_at,is_current
) values('ci-legal-v1',repeat('a',64),'https://example.org/terms',
  'ci-privacy-v1',repeat('b',64),'https://example.org/privacy',
  'ci-only legal and clinical release test',now()-interval '1 day',true);
insert into stk_secure.stk_nutrition_review_operators(user_id,approval_reference)
values
('fe000000-0000-0000-0000-000000000002','ci-only operator authorization A'),
('fe000000-0000-0000-0000-000000000003','ci-only operator authorization B');

reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"fe000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false,"aal":"aal1"}',
  true);
select lives_ok(
  $$select public.stk_record_legal_acceptance(
    'ci-legal-v1',repeat('a',64),'ci-privacy-v1',repeat('b',64),'18_plus')$$,
  'Subject can accept current published policy without gaining calories');
select is((public.stk_get_nutrition_capabilities()->>'personalizedAdultEnergy')::boolean,
  false,'Accepted terms and forged metadata do not grant adult access');

select set_config('request.jwt.claims',
  '{"sub":"fe000000-0000-0000-0000-000000000004","role":"authenticated","is_anonymous":false,"aal":"aal2","user_metadata":{"is_stk_admin":true}}',
  true);
select throws_ok(
  $$select public.stk_operator_request_nutrition_review(
    'fe000000-0000-0000-0000-000000000001',
    'personalizedAdultEnergy','18_plus','ci-only review case no PII',now()+interval '14 days')$$,
  'P0001','Authorized MFA reviewer required',
  'Forged editable metadata cannot enroll an operator');

select set_config('request.jwt.claims',
  '{"sub":"fe000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false,"aal":"aal1"}',
  true);
select throws_ok(
  $$select public.stk_operator_request_nutrition_review(
    'fe000000-0000-0000-0000-000000000001',
    'personalizedAdultEnergy','18_plus','ci-only review case no PII',now()+interval '14 days')$$,
  'P0001','Authorized MFA reviewer required',
  'Enrolled operator without MFA cannot request access');

select set_config('request.jwt.claims',
  '{"sub":"fe000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false,"aal":"aal2"}',
  true);
select throws_ok(
  $$select public.stk_operator_request_nutrition_review(
    'fe000000-0000-0000-0000-000000000001',
    'personalizedAdultEnergy','18_plus','ci-only missing session denied',now()+interval '14 days')$$,
  'P0001','Authorized MFA reviewer required',
  'MFA JWT with no matching live session is rejected');
select set_config('request.jwt.claims',
  '{"sub":"fe000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false,"aal":"aal2","session_id":"fa000000-0000-0000-0000-000000000002"}',
  true);
select throws_ok(
  $$select public.stk_operator_request_nutrition_review(
    'fe000000-0000-0000-0000-000000000002',
    'personalizedAdultEnergy','18_plus','ci-only self approval blocked',now()+interval '14 days')$$,
  'P0001','Invalid proposed nutrition review',
  'Operator cannot request a grant for its own UID');
select throws_ok(
  $$select public.stk_operator_request_nutrition_review(
    'fe000000-0000-0000-0000-000000000001',
    'informationalFoodEstimate','18_plus','ci-only clinical gate blocked',now()+interval '14 days')$$,
  'P0001','Clinical approval is not enabled',
  'Independent meal estimates remain clinically disabled');

create temporary table _stk_operator_review_case as
select public.stk_operator_request_nutrition_review(
  'fe000000-0000-0000-0000-000000000001',
  'personalizedAdultEnergy','18_plus',
  'ci-only manual review without personal evidence',
  now()+interval '14 days'
) as id;
select is((select count(*)::integer from _stk_operator_review_case),1,
  'First enrolled MFA reviewer can propose only a pending case');

select throws_ok(
  $$select public.stk_operator_approve_nutrition_review(
    (select id from _stk_operator_review_case))$$,
  'P0001','Independent current review required',
  'The proposing operator cannot approve its own request');

select set_config('request.jwt.claims',
  '{"sub":"fe000000-0000-0000-0000-000000000003","role":"authenticated","is_anonymous":false,"aal":"aal1"}',
  true);
select throws_ok(
  $$select public.stk_operator_approve_nutrition_review(
    (select id from _stk_operator_review_case))$$,
  'P0001','Authorized MFA reviewer required',
  'Second operator also requires MFA');

select set_config('request.jwt.claims',
  '{"sub":"fe000000-0000-0000-0000-000000000003","role":"authenticated","is_anonymous":false,"aal":"aal2","session_id":"fa000000-0000-0000-0000-000000000003"}',
  true);
select lives_ok(
  $$select public.stk_operator_approve_nutrition_review(
    (select id from _stk_operator_review_case))$$,
  'Second distinct MFA operator atomically approves the case');
select throws_ok(
  $$select public.stk_operator_approve_nutrition_review(
    (select id from _stk_operator_review_case))$$,
  'P0001','Independent current review required',
  'An already consumed review cannot be replayed');

select set_config('request.jwt.claims',
  '{"sub":"fe000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false,"aal":"aal1"}',
  true);
select is((public.stk_get_nutrition_capabilities()->>'personalizedAdultEnergy')::boolean,
  true,'A subject sees its own grant only after dual operator review');

reset role;
set local role service_role;
select throws_ok(
  $$select public.stk_service_set_nutrition_capability(
    'fe000000-0000-0000-0000-000000000001',
    'personalizedAdultEnergy','18_plus',true,
    'ci-only attempt to bypass review',now()+interval '14 days')$$,
  'P0001','Use independent MFA nutrition review workflow',
  'The legacy service-only path cannot mint additional grants');

reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"fe000000-0000-0000-0000-000000000003","role":"authenticated","is_anonymous":false,"aal":"aal2","session_id":"fa000000-0000-0000-0000-000000000003"}',
  true);
select lives_ok(
  $$select public.stk_operator_revoke_nutrition_capability(
    'fe000000-0000-0000-0000-000000000001',
    'personalizedAdultEnergy','ci-only emergency operator revocation')$$,
  'A current MFA operator can promptly revoke without a second approver');

select set_config('request.jwt.claims',
  '{"sub":"fe000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false,"aal":"aal1"}',
  true);
select is((public.stk_get_nutrition_capabilities()->>'personalizedAdultEnergy')::boolean,
  false,'Server revocation hides previously authorized numeric access');

reset role;
set local role service_role;
select is((select count(*)::integer from stk_secure.stk_nutrition_operator_audit
  where event = 'approved'),1,'Independent reviewer identity is auditable');
select is((select count(*)::integer from stk_secure.stk_nutrition_operator_audit
  where event = 'revoked'),1,'Operator revocation is auditable');
select is((select count(*)::integer from stk_secure.stk_nutrition_capability_audit
  where decision = 'grant'),1,'Exactly one grant event was minted');

select * from finish();
rollback;
