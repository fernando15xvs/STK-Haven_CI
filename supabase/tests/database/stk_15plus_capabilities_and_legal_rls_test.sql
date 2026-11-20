-- P0/P1: isolated pgTAP, never touches production. All fixture writes
-- roll back; only source migrations can create new security structures.
begin;
select plan(33);

select has_table('stk_secure','stk_legal_releases','Private reviewed release ledger exists');
select has_table('stk_secure','stk_legal_receipts','Private UID-scoped legal receipt ledger exists');
select has_table('stk_secure','stk_legal_receipt_audit','Append-only legal acceptance audit exists');
select has_table('stk_secure','stk_nutrition_capability_grants','Separate numeric grant ledger exists');
select has_table('stk_secure','stk_nutrition_capability_audit','Privileged audit ledger exists');
select ok((select relrowsecurity from pg_class where oid =
  'stk_secure.stk_nutrition_capability_grants'::regclass),'Private grants have RLS');
select ok((select relrowsecurity from pg_class where oid =
  'stk_secure.stk_legal_receipts'::regclass),'Private legal receipts have RLS');
select ok(not has_schema_privilege('authenticated','stk_secure','USAGE'),
  'No direct client access to secure schema');
select ok(not has_table_privilege('authenticated',
  'stk_secure.stk_nutrition_capability_grants','SELECT'),
  'Client cannot read arbitrary grants');
select ok(not has_table_privilege('authenticated',
  'stk_secure.stk_legal_receipts','INSERT'),
  'Client cannot forge an authoritative receipt');
select ok(not has_function_privilege('authenticated',
  'public.stk_service_set_nutrition_capability(uuid,text,text,boolean,text,timestamptz)',
  'EXECUTE'),'Clients cannot grant or revoke privileged nutrition');
select ok(not has_function_privilege('anon',
  'public.stk_get_nutrition_capabilities()','EXECUTE'),
  'Unauthenticated users cannot call numeric reader');
select ok(has_function_privilege('authenticated',
  'public.stk_get_nutrition_capabilities()','EXECUTE'),
  'Signed-in users can only query their own capability projection');
select ok(not has_function_privilege('authenticated',
  'public.stk_service_can_use_nutrition_capability(uuid,text)','EXECUTE'),
  'No client RPC that can query a different UID');
select ok(has_function_privilege('authenticated',
  'public.stk_revoke_legal_acceptance()','EXECUTE'),
  'Own legal consent can be revoked without a privileged grant writer');

insert into auth.users(
  id,aud,role,email,encrypted_password,email_confirmed_at,
  created_at,updated_at,raw_app_meta_data,raw_user_meta_data
) values
('fd000000-0000-0000-0000-000000000001',
 'authenticated','authenticated','ci-p15-a@example.com','',
 now(),now(),now(),'{}'::jsonb,'{"adult_verified":true,"dob":"1979-01-01"}'::jsonb),
('fd000000-0000-0000-0000-000000000002',
 'authenticated','authenticated','ci-p15-b@example.com','',
 now(),now(),now(),'{}'::jsonb,'{"adult_verified":true,"dob":"1970-01-01"}'::jsonb);

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"fd000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true);
select is((public.stk_get_nutrition_capabilities()->>'personalizedAdultEnergy')::boolean,
  false,'Forged DOB/metadata cannot grant adult calories');
select is(public.stk_get_current_legal_release(),null::jsonb,
  'No published legal policy exists by default');
select throws_ok(
  $$select public.stk_record_legal_acceptance(
    'v1',repeat('a',64),'v1',repeat('b',64),'18_plus')$$,
  'P0001','Current published legal documents required',
  'Client cannot accept unpublished drafts');

reset role;
set local role service_role;
insert into stk_secure.stk_legal_releases(
  terms_version,terms_sha256,terms_https_url,
  privacy_version,privacy_sha256,privacy_https_url,
  approved_reference,published_at,is_current
) values ('v1',repeat('a',64),'https://example.org/stk-terms',
  'v1',repeat('b',64),'https://example.org/stk-privacy',
  'ci-only-reviewed-policy-reference',now() - interval '1 day',true);

reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"fd000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false,"user_metadata":{"adult_verified":true}}',
  true);
select is((public.stk_get_nutrition_capabilities()->>'personalizedAdultEnergy')::boolean,
  false,'Published policy and editable JWT metadata alone still grant nothing');
select throws_ok(
  $$select public.stk_record_legal_acceptance(
    'v1',repeat('c',64),'v1',repeat('b',64),'18_plus')$$,
  'P0001','Current published legal documents required',
  'Wrong source hash cannot create a current legal receipt');
select lives_ok(
  $$select public.stk_record_legal_acceptance(
    'v1',repeat('a',64),'v1',repeat('b',64),'18_plus')$$,
  'Matching legal texts allow authoritative acceptance event');
select is((public.stk_get_nutrition_capabilities()->>'legalCurrent')::boolean,
  true,'Authoritative legal receipt is scoped to this UID');

reset role;
set local role service_role;
select throws_ok(
  $$select public.stk_service_set_nutrition_capability(
    'fd000000-0000-0000-0000-000000000001',
    'personalizedAdultEnergy','15_17',true,
    'ci review of separate nutrition eligibility',now()+interval '14 days')$$,
  'P0001','Use independent MFA nutrition review workflow',
  'Service role cannot bypass the two-operator grant workflow');
select throws_ok(
  $$select public.stk_service_set_nutrition_capability(
    'fd000000-0000-0000-0000-000000000001',
    'informationalFoodEstimate','18_plus',true,
    'ci review of educational meal estimates',now()+interval '14 days')$$,
  'P0001','Use independent MFA nutrition review workflow',
  'Service role cannot bypass independent clinical and reviewer gates');
select throws_ok(
  $$select public.stk_service_set_nutrition_capability(
    'fd000000-0000-0000-0000-000000000001',
    'personalizedAdultEnergy','18_plus',true,
    'ci-only separate adult review decision',now()+interval '14 days')$$,
  'P0001','Use independent MFA nutrition review workflow',
  'Direct service grant is blocked without two independent MFA reviews');

reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"fd000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true);
select is((public.stk_get_nutrition_capabilities()->>'personalizedAdultEnergy')::boolean,
  false,'Owner has no adult grant from legal acceptance or bare service call');
select set_config('request.jwt.claims',
  '{"sub":"fd000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',
  true);
select is((public.stk_get_nutrition_capabilities()->>'personalizedAdultEnergy')::boolean,
  false,'Account B cannot inherit account A grant');
select set_config('request.jwt.claims',
  '{"sub":"fd000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":true}',
  true);
select is((public.stk_get_nutrition_capabilities()->>'personalizedAdultEnergy')::boolean,
  false,'Anonymous sessions never use an existing numeric grant');
select set_config('request.jwt.claims',
  '{"sub":"fd000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true);
select is(public.stk_revoke_legal_acceptance(),true,
  'User may revoke only their own acceptance and dependent grants');
select is((public.stk_get_nutrition_capabilities()->>'personalizedAdultEnergy')::boolean,
  false,'Withdrawal immediately denies previous numeric access');
select is((public.stk_get_nutrition_capabilities()->>'legalCurrent')::boolean,
  false,'Withdrawn legal receipt is no longer current');
reset role;
set local role service_role;
select ok((select count(*) from stk_secure.stk_nutrition_capability_audit
  where user_id='fd000000-0000-0000-0000-000000000001'
    and decision='legal_withdrawn')=0,'Without a grant no artificial numeric withdrawal audit is emitted');
select ok((select count(*) from stk_secure.stk_legal_receipt_audit
  where user_id='fd000000-0000-0000-0000-000000000001'
    and event='accepted') = 1
  and (select count(*) from stk_secure.stk_legal_receipt_audit
    where user_id='fd000000-0000-0000-0000-000000000001'
      and event='revoked') = 1,
  'Legal audit retains both acceptance and withdrawal events');

select * from finish();
rollback;
