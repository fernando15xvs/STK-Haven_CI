begin;
select plan(31);
select has_table('public','stk_coach_pro_reminder_opt_ins','opt-in table');
select has_function('public','stk_get_coach_pro_reminder_opt_in',array['uuid'],'read RPC');
select has_function('public','stk_set_coach_pro_reminder_opt_in',array['uuid','boolean','integer','integer'],'write RPC');
select ok((select relrowsecurity from pg_class where oid='public.stk_coach_pro_reminder_opt_ins'::regclass),'RLS enabled');
select ok(not has_table_privilege('authenticated','public.stk_coach_pro_reminder_opt_ins','SELECT'),'no direct read');
select ok(not has_function_privilege('anon','public.stk_get_coach_pro_reminder_opt_in(uuid)','EXECUTE'),'anonymous blocked');
insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('e4000000-0000-0000-0000-000000000001','authenticated','authenticated','reminder-coach-a@example.com','',now(),now(),now(),'{}','{}'),
('e4000000-0000-0000-0000-000000000002','authenticated','authenticated','reminder-coach-b@example.com','',now(),now(),now(),'{}','{}'),
('e5000000-0000-0000-0000-000000000001','authenticated','authenticated','reminder-client@example.com','',now(),now(),now(),'{}','{}'),
('e5000000-0000-0000-0000-000000000002','authenticated','authenticated','reminder-stranger@example.com','',now(),now(),now(),'{}','{}');
insert into public.stk_user_capabilities(user_id,capability) values
('e4000000-0000-0000-0000-000000000001','coach'),
('e4000000-0000-0000-0000-000000000002','coach'),
('e5000000-0000-0000-0000-000000000001','athlete');
insert into public.stk_subscription_entitlements(user_id,product,status,tier,client_limit,starts_at,current_period_end,source) values
('e4000000-0000-0000-0000-000000000001','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap'),
('e4000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions) values
('e6000000-0000-0000-0000-000000000001','e4000000-0000-0000-0000-000000000001','e5000000-0000-0000-0000-000000000001','active','{"view_checkins":true,"assign_tasks":true}'::jsonb),
('e6000000-0000-0000-0000-000000000002','e4000000-0000-0000-0000-000000000002','e5000000-0000-0000-0000-000000000001','active','{"view_checkins":true,"assign_tasks":true}'::jsonb);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_get_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001')->>'enabled','false','off by default');
select throws_ok($$select public.stk_set_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001',true,19,null)$$,'P0001','Accepted check-in cadence changed; refresh','cannot enable without accepted cadence');
select set_config('request.jwt.claims','{"sub":"e4000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_propose_coach_pro_checkin_cadence('e6000000-0000-0000-0000-000000000001',array[1,4]::smallint[],null),1,'coach proposes');
select throws_ok($$select public.stk_set_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001',true,19,1)$$,'P0001','Client relationship required','coach cannot enable');
select set_config('request.jwt.claims','{"sub":"e5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_get_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001')->>'enabled','false','proposal not opt-in');
select is(public.stk_respond_coach_pro_checkin_cadence('e6000000-0000-0000-0000-000000000001',1,true),2,'client accepts cadence');
select is(public.stk_get_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001')->>'enabled','false','cadence acceptance not reminder consent');
select throws_ok($$select public.stk_set_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001',true,23,2)$$,'P0001','Invalid reminder hour','hour bounded');
select throws_ok($$select public.stk_set_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001',true,19,1)$$,'P0001','Accepted check-in cadence changed; refresh','stale revision denied');
select ok(public.stk_set_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001',true,19,2),'explicit client enable');
select is(public.stk_get_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001')->>'enabled','true','enabled only after consent');
select is(public.stk_get_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001')->'weekdays','[1, 4]'::jsonb,'only accepted weekdays');
select set_config('request.jwt.claims','{"sub":"e5000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001')$$,'P0001','Client relationship required','stranger cannot read');
select set_config('request.jwt.claims','{"sub":"e4000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_propose_coach_pro_checkin_cadence('e6000000-0000-0000-0000-000000000002',array[2]::smallint[],null),1,'second coach proposal');
select set_config('request.jwt.claims','{"sub":"e5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_respond_coach_pro_checkin_cadence('e6000000-0000-0000-0000-000000000002',1,true),2,'second cadence accepted');
select ok(public.stk_set_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000002',true,18,2),'switch coach reminder');
select is(public.stk_get_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001')->>'enabled','false','previous coach reminder off');
reset role;
select is((select count(*)::integer from public.stk_coach_pro_reminder_opt_ins where client_user_id='e5000000-0000-0000-0000-000000000001' and enabled),1,'at most one active reminder');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_set_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000002',false,19,null),false,'client can opt out');
reset role;
select is((select count(*)::integer from public.stk_coach_pro_reminder_opt_ins where client_user_id='e5000000-0000-0000-0000-000000000001' and enabled),0,'opt-out persists');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select ok(public.stk_set_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001',true,20,2),'explicit re-optin works');
select set_config('request.jwt.claims','{"sub":"e4000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_propose_coach_pro_checkin_cadence('e6000000-0000-0000-0000-000000000001',array[3]::smallint[],2),3,'new proposal revokes acceptance');
select set_config('request.jwt.claims','{"sub":"e5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_get_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001')->>'enabled','false','revised cadence disables effective reminder');
select is(public.stk_set_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001',false,19,null),false,'disable succeeds after proposal revision');
reset role;
update public.stk_coach_client_relationships set status='revoked' where id='e6000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e5000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_get_coach_pro_reminder_opt_in('e6000000-0000-0000-0000-000000000001')->>'enabled','false','revoked relation hides effective reminder');
select * from finish();
rollback;
