begin;
select plan(28);

select has_table('public','stk_coach_pro_checkin_cadences','cadence store exists');
select has_function('public','stk_propose_coach_pro_checkin_cadence',
  array['uuid','smallint[]','integer'],'coach proposal RPC exists');
select has_function('public','stk_respond_coach_pro_checkin_cadence',
  array['uuid','integer','boolean'],'client response RPC exists');
select has_function('public','stk_get_coach_pro_checkin_cadence',
  array['uuid'],'authorized read RPC exists');
select ok(not has_table_privilege('authenticated','public.stk_coach_pro_checkin_cadences','SELECT'),
  'no direct table reads');
select ok(not has_function_privilege('anon','public.stk_get_coach_pro_checkin_cadence(uuid)','EXECUTE'),
  'anonymous cannot invoke read RPC');

insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,
 created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('e1000000-0000-0000-0000-000000000001','authenticated','authenticated','cadence-coach-a@example.com','',now(),now(),now(),'{}','{}'),
('e1000000-0000-0000-0000-000000000002','authenticated','authenticated','cadence-coach-b@example.com','',now(),now(),now(),'{}','{}'),
('e2000000-0000-0000-0000-000000000001','authenticated','authenticated','cadence-client@example.com','',now(),now(),now(),'{}','{}');
insert into public.stk_user_capabilities(user_id,capability) values
('e1000000-0000-0000-0000-000000000001','coach'),
('e1000000-0000-0000-0000-000000000002','coach'),
('e2000000-0000-0000-0000-000000000001','athlete');
insert into public.stk_subscription_entitlements(
 user_id,product,status,tier,client_limit,starts_at,current_period_end,source)
 values
('e1000000-0000-0000-0000-000000000001','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap'),
('e1000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');
insert into public.stk_coach_client_relationships(
 id,coach_user_id,client_user_id,status,permissions) values
('e3000000-0000-0000-0000-000000000001',
 'e1000000-0000-0000-0000-000000000001',
 'e2000000-0000-0000-0000-000000000001',
 'active','{"view_checkins":true,"assign_tasks":true}');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_get_coach_pro_checkin_cadence('e3000000-0000-0000-0000-000000000001'),
  null::jsonb,'absence is null, not an invented schedule');
select throws_ok($$select public.stk_propose_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001',array[1,1]::smallint[],null)$$,
 'P0001','Invalid check-in weekdays','reject duplicate days');
select throws_ok($$select public.stk_propose_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001',array[1,2,3,4]::smallint[],null)$$,
 'P0001','Invalid check-in weekdays','reject excessive frequency');
select is(public.stk_propose_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001',array[1,3]::smallint[],null),
 1,'coach creates a proposed cadence');
select is(public.stk_get_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001')->>'status',
 'proposed','proposal is not automatically accepted');
select is(public.stk_get_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001')->'weekdays','[1, 3]'::jsonb,
 'weekdays are exact and scoped');
select throws_ok($$select public.stk_propose_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001',array[2]::smallint[],null)$$,
 'P0001','Check-in cadence changed; refresh','no blind rewrite of proposal');

select set_config('request.jwt.claims','{"sub":"e1000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001')$$,
 'P0001','Active check-in scheduling permission required',
 'unrelated coach cannot read proposed days');
select throws_ok($$select public.stk_propose_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001',array[2]::smallint[],null)$$,
 'P0001','Active check-in scheduling permission required',
 'unrelated coach cannot overwrite cadence');

select set_config('request.jwt.claims','{"sub":"e2000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_get_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001')->>'status',
 'proposed','client sees own proposal');
select throws_ok($$select public.stk_respond_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001',2,true)$$,
 'P0001','Check-in cadence changed; refresh',
 'stale revision cannot accept');
select is(public.stk_respond_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001',1,true),
 2,'client explicitly accepts');
select is(public.stk_get_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001')->>'status',
 'accepted','acceptance is visible');
select throws_ok($$select public.stk_respond_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001',2,true)$$,
 'P0001','Check-in cadence is not awaiting a response','cannot accept twice');
select is(public.stk_respond_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001',2,false),
 3,'client can opt out immediately');
select is(public.stk_get_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001')->>'status',
 'declined','opt-out is persisted');
select throws_ok($$select public.stk_propose_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001',array[2]::smallint[],3)$$,
 'P0001','Coach capability required','athlete cannot propose new cadence');

reset role;
update public.stk_coach_client_relationships set permissions='{"view_checkins":true}'::jsonb
 where id='e3000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001')$$,
 'P0001','Active check-in scheduling permission required',
 'revoking assignment consent hides cadence');
reset role;
update public.stk_coach_client_relationships
 set permissions='{"view_checkins":true,"assign_tasks":true}'::jsonb
 where id='e3000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_propose_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001',array[2,5]::smallint[],3),
 4,'new proposal invalidates previous acceptance');
select is(public.stk_get_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001')->>'status',
 'proposed','revised cadence needs fresh acceptance');
reset role;
update public.stk_coach_client_relationships set status='paused'
 where id='e3000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e2000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001')$$,
 'P0001','Active check-in scheduling permission required','paused client loses access');
reset role;
update public.stk_coach_client_relationships set status='active'
 where id='e3000000-0000-0000-0000-000000000001';
update public.stk_subscription_entitlements set status='expired'
 where user_id='e1000000-0000-0000-0000-000000000001' and product='coach_pro';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_checkin_cadence(
 'e3000000-0000-0000-0000-000000000001')$$,
 'P0001','Coach Pro entitlement required','expired coach subscription blocks access');
select * from finish();
rollback;
