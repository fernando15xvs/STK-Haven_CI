begin;
select plan(12);
select has_table('public','stk_coach_checkins','check-in table exists');
select has_table('public','stk_coach_checkin_comments','check-in comments table exists');
select ok((select relrowsecurity from pg_class where oid='public.stk_coach_checkins'::regclass),'check-ins use RLS');
select ok(not exists(select 1 from information_schema.role_table_grants where table_schema='public' and table_name='stk_coach_checkins' and grantee='authenticated' and privilege_type='INSERT'),'direct insert is denied');

insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('a2000000-0000-0000-0000-000000000001','authenticated','authenticated','ci-coach@example.com','',now(),now(),now(),'{}','{}'),
('b2000000-0000-0000-0000-000000000001','authenticated','authenticated','ci-client@example.com','',now(),now(),now(),'{}','{}'),
('a2000000-0000-0000-0000-000000000002','authenticated','authenticated','ci-stranger@example.com','',now(),now(),now(),'{}','{}');
insert into public.stk_user_profiles(user_id,display_name) values
('a2000000-0000-0000-0000-000000000001','Coach'),('b2000000-0000-0000-0000-000000000001','Client'),('a2000000-0000-0000-0000-000000000002','Stranger');
insert into public.stk_user_capabilities(user_id,capability) values
('a2000000-0000-0000-0000-000000000001','coach'),('b2000000-0000-0000-0000-000000000001','athlete'),('a2000000-0000-0000-0000-000000000002','coach');
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions) values
('c2000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','active','{"view_checkins":true,"comment":true}');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b2000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select lives_ok($$select public.stk_create_coach_checkin('c2000000-0000-0000-0000-000000000001',4,3,'Bien')$$,'client can create consented check-in');
select is((select count(*)::int from public.stk_coach_checkins),1,'client reads own check-in');
select throws_ok($$select public.stk_create_coach_checkin('c2000000-0000-0000-0000-000000000001',9,3,'bad')$$,'P0001','Check-in score out of range','invalid score rejected');

reset role; set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a2000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is((select count(*)::int from public.stk_coach_checkins),1,'permitted coach reads check-in');
select lives_ok($$select public.stk_add_coach_checkin_comment((select id from public.stk_coach_checkins limit 1),'Gracias')$$,'permitted coach comments');

reset role; set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a2000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select is((select count(*)::int from public.stk_coach_checkins),0,'stranger cannot read check-in');
select throws_ok($$select public.stk_list_coach_checkins('b2000000-0000-0000-0000-000000000001')$$,'P0001','Check-in permission required','stranger RPC denied');

reset role;
update public.stk_coach_client_relationships set status='revoked',revoked_at=now(),updated_at=now() where id='c2000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a2000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is((select count(*)::int from public.stk_coach_checkins),0,'revoked coach loses check-in access');
reset role; set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b2000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is((select count(*)::int from public.stk_coach_checkins),1,'client retains check-in after revocation');
select * from finish();
rollback;
