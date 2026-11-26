begin;
select plan(27);
select ok((select relrowsecurity from pg_class where oid='stk_secure.stk_coach_measurement_shares'::regclass),'measurement share RLS');
select ok(not has_table_privilege('authenticated','stk_secure.stk_coach_measurement_shares','SELECT'),'no direct measurements read');
select ok(not has_function_privilege('anon','public.stk_get_coach_measurements(uuid)','EXECUTE'),'anonymous cannot read measurements');
select ok(not has_function_privilege('authenticated','stk_secure.stk_grant_coach_development_trial(uuid,integer,integer,text)','EXECUTE'),'client cannot grant itself trial');
insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('a5000000-0000-0000-0000-000000000001','authenticated','authenticated','qa-coach-a@example.com','',now(),now(),now(),'{}','{}'),
('a5000000-0000-0000-0000-000000000002','authenticated','authenticated','qa-coach-b@example.com','',now(),now(),now(),'{}','{}'),
('b5000000-0000-0000-0000-000000000001','authenticated','authenticated','qa-client@example.com','',now(),now(),now(),'{}','{}');
insert into public.stk_user_profiles(user_id,display_name) values
('a5000000-0000-0000-0000-000000000001','Coach A'),('a5000000-0000-0000-0000-000000000002','Coach B'),('b5000000-0000-0000-0000-000000000001','Client');
insert into public.stk_user_capabilities(user_id,capability) values
('a5000000-0000-0000-0000-000000000001','coach'),('a5000000-0000-0000-0000-000000000002','coach'),('b5000000-0000-0000-0000-000000000001','athlete');
select is(stk_secure.stk_grant_coach_development_trial('a5000000-0000-0000-0000-000000000001',7,2,'pgTap-coach-qa-a'),true,'administrator grants bounded trial');
select is(stk_secure.stk_grant_coach_development_trial('a5000000-0000-0000-0000-000000000002',7,2,'pgTap-coach-qa-b'),true,'second coach trial');
select throws_ok($$select stk_secure.stk_grant_coach_development_trial('a5000000-0000-0000-0000-000000000001',31,2,'pgTap-coach-qa-long')$$,'P0001','Invalid development trial bounds','no unbounded trial');
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions) values
('c5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000001','active','{"view_measurements":true,"view_checkins":true,"assign_tasks":true,"comment":true}'),
('c5000000-0000-0000-0000-000000000002','a5000000-0000-0000-0000-000000000002','b5000000-0000-0000-0000-000000000001','active','{"view_measurements":true,"view_checkins":true,"assign_tasks":true,"comment":true}');
insert into public.stk_coach_tasks(relationship_id,coach_user_id,client_user_id,title) values
('c5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000001','A'),
('c5000000-0000-0000-0000-000000000002','a5000000-0000-0000-0000-000000000002','b5000000-0000-0000-0000-000000000001','B');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select lives_ok($$select public.stk_share_coach_measurements('c5000000-0000-0000-0000-000000000001',now(),'{"waistCm":80}')$$,'client shares selected measurement only');
select throws_ok($$select public.stk_share_coach_measurements('c5000000-0000-0000-0000-000000000001',now(),'{"note":"private"}')$$,'P0001','Invalid measurement snapshot','reject extra private fields');
select lives_ok($$select public.stk_create_coach_checkin('c5000000-0000-0000-0000-000000000001',4,3,'A only')$$,'client creates checkin A');
select lives_ok($$select public.stk_create_coach_checkin('c5000000-0000-0000-0000-000000000002',2,3,'B only')$$,'client creates checkin B');
select is((select count(*) from public.stk_list_coach_checkins('b5000000-0000-0000-0000-000000000001')),2::bigint,'client retains own full history');
reset role; set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is((public.stk_get_coach_measurements('c5000000-0000-0000-0000-000000000001')->'values'->>'waistCm'),'80','coach A reads explicit shared field');
select throws_ok($$select public.stk_get_coach_measurements('c5000000-0000-0000-0000-000000000002')$$,'P0001','Measurement permission required','coach cannot read other relationship');
select throws_ok($$select public.stk_share_coach_measurements('c5000000-0000-0000-0000-000000000001',now(),'{"waistCm":81}')$$,'P0001','Measurement permission required','coach cannot write measurements');
select is((select count(*) from public.stk_list_coach_checkins('b5000000-0000-0000-0000-000000000001')),1::bigint,'A sees only A checkins');
select is(public.stk_get_task_adherence('b5000000-0000-0000-0000-000000000001',1)->>'due_count','1','A adherence excludes B');
select throws_ok($select public.stk_get_coach_relationship_task_adherence('c5000000-0000-0000-0000-000000000002',1)$,'P0001','Task assignment permission required','coach cannot read other relationship adherence');
reset role; set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a5000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_get_coach_measurements('c5000000-0000-0000-0000-000000000002'),null::jsonb,'B cannot see A snapshot even with permission');
reset role;
update public.stk_coach_client_relationships set permissions=permissions||'{"view_measurements":false}'::jsonb where id='c5000000-0000-0000-0000-000000000001';
select is((select count(*) from stk_secure.stk_coach_measurement_shares),0::bigint,'revocation purges snapshot');
update public.stk_coach_client_relationships set permissions=permissions||'{"view_measurements":true}'::jsonb where id='c5000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_get_coach_measurements('c5000000-0000-0000-0000-000000000001'),null::jsonb,'regrant never restores old snapshot');
reset role;
select ok(not has_function_privilege('authenticated','stk_secure.stk_revoke_coach_development_trial(uuid,text)','EXECUTE'),'client cannot cancel another trial');
select is(stk_secure.stk_revoke_coach_development_trial('a5000000-0000-0000-0000-000000000001','pgTap-coach-qa-revoke-a'),true,'administrator cancels private trial');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($select public.stk_get_coach_measurements('c5000000-0000-0000-0000-000000000001')$,'P0001','Coach Pro entitlement required','expired entitlement denies measurements');
select is(public.stk_get_own_subscription_entitlement('coach_pro')->>'access_active','false','trial revoked immediately on server');
reset role; set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is((select count(*) from public.stk_list_coach_checkins('b5000000-0000-0000-0000-000000000001')),2::bigint,'client still owns historical checkins');
select is(public.stk_get_coach_relationship_task_adherence('c5000000-0000-0000-0000-000000000002',1)->>'due_count','1','client sees only selected relationship adherence');
reset role;
select * from finish();
rollback;
