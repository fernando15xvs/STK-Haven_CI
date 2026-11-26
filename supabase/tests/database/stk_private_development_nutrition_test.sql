begin;
select plan(13);
select ok(not has_table_privilege('authenticated','stk_secure.stk_development_nutrition_testers','INSERT'),'No self-enrollment');
select ok(not has_table_privilege('service_role','stk_secure.stk_development_nutrition_testers','INSERT'),'Edge service cannot enroll');
select ok(not has_function_privilege('anon','public.stk_get_development_nutrition_access()','EXECUTE'),'No anonymous reader');
select ok(not has_function_privilege('authenticated','public.stk_service_can_use_development_nutrition(uuid,uuid)','EXECUTE'),'No arbitrary session reader');
insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('dd000000-0000-0000-0000-000000000001','authenticated','authenticated','dev-ci-a@example.com','',now(),now(),now(),'{}','{}'),
('dd000000-0000-0000-0000-000000000002','authenticated','authenticated','dev-ci-b@example.com','',now(),now(),now(),'{}','{"adult_verified":true}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal) values
('de000000-0000-0000-0000-000000000001','dd000000-0000-0000-0000-000000000001',now(),now(),'aal1'),
('de000000-0000-0000-0000-000000000002','dd000000-0000-0000-0000-000000000002',now(),now(),'aal1');
insert into stk_secure.stk_development_nutrition_testers(user_id,reviewed_age_band,expires_at,review_reference) values
('dd000000-0000-0000-0000-000000000001','18_plus',now()+interval '1 day','CI fixture adult review');
select is(public.stk_service_can_use_development_nutrition('dd000000-0000-0000-0000-000000000001','de000000-0000-0000-0000-000000000001'),false,'Default disabled');
update stk_secure.stk_development_nutrition_config set enabled=true;
select is(public.stk_service_can_use_development_nutrition('dd000000-0000-0000-0000-000000000001','de000000-0000-0000-0000-000000000001'),true,'Reviewed adult tester');
select is(public.stk_service_can_use_development_nutrition('dd000000-0000-0000-0000-000000000001','de000000-0000-0000-0000-000000000002'),false,'Wrong session rejected');
select is(public.stk_service_can_use_development_nutrition('dd000000-0000-0000-0000-000000000002','de000000-0000-0000-0000-000000000002'),false,'Unenrolled account denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"dd000000-0000-0000-0000-000000000001","role":"authenticated","session_id":"de000000-0000-0000-0000-000000000001","is_anonymous":false}',true);
select is(public.stk_get_development_nutrition_access(),true,'Owner reads dev grant');
select is((public.stk_get_nutrition_capabilities()->>'legalCurrent')::boolean,false,'No invented legal receipt');
reset role;
update stk_secure.stk_development_nutrition_testers set reviewed_at=now()-interval '2 days',expires_at=now()-interval '1 day';
select is(public.stk_service_can_use_development_nutrition('dd000000-0000-0000-0000-000000000001','de000000-0000-0000-0000-000000000001'),false,'Expired access');
update stk_secure.stk_development_nutrition_testers set reviewed_at=now(),expires_at=now()+interval '1 day',revoked_at=now();
select is(public.stk_service_can_use_development_nutrition('dd000000-0000-0000-0000-000000000001','de000000-0000-0000-0000-000000000001'),false,'Revoked access');
update stk_secure.stk_development_nutrition_testers set revoked_at=null;
insert into stk_secure.stk_legal_releases(terms_version,terms_sha256,terms_https_url,privacy_version,privacy_sha256,privacy_https_url,approved_reference,published_at,is_current) values
('ci-dev-v1',repeat('a',64),'https://example.org/terms','ci-dev-v1',repeat('b',64),'https://example.org/privacy','ci-only legal fixture',now()-interval '1 day',true);
select is(public.stk_service_can_use_development_nutrition('dd000000-0000-0000-0000-000000000001','de000000-0000-0000-0000-000000000001'),false,'Published release shuts off development');
select * from finish();
rollback;
