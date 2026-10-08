begin;
select plan(22);
select has_function('public','stk_list_coach_pro_task_schedule',
 array['uuid','date','integer','integer','integer'],'agenda RPC exists');
select ok(not has_function_privilege('anon',
 'public.stk_list_coach_pro_task_schedule(uuid,date,integer,integer,integer)',
 'EXECUTE'),'anon cannot invoke agenda');
select ok(has_function_privilege('authenticated',
 'public.stk_list_coach_pro_task_schedule(uuid,date,integer,integer,integer)',
 'EXECUTE'),'authenticated may invoke guarded RPC');

insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,
 created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('f1000000-0000-0000-0000-000000000001','authenticated','authenticated','agenda-coach@example.com','',now(),now(),now(),'{}','{}'),
('f1000000-0000-0000-0000-000000000002','authenticated','authenticated','agenda-other-coach@example.com','',now(),now(),now(),'{}','{}'),
('f2000000-0000-0000-0000-000000000001','authenticated','authenticated','agenda-client@example.com','',now(),now(),now(),'{}','{}');
insert into public.stk_user_capabilities(user_id,capability) values
('f1000000-0000-0000-0000-000000000001','coach'),
('f1000000-0000-0000-0000-000000000002','coach'),
('f2000000-0000-0000-0000-000000000001','athlete');
insert into public.stk_subscription_entitlements(
 user_id,product,status,tier,client_limit,starts_at,current_period_end,source)
 values
('f1000000-0000-0000-0000-000000000001','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap'),
('f1000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');
insert into public.stk_coach_client_relationships(
 id,coach_user_id,client_user_id,status,permissions) values
('f3000000-0000-0000-0000-000000000001',
 'f1000000-0000-0000-0000-000000000001',
 'f2000000-0000-0000-0000-000000000001',
 'active','{"assign_tasks":true}'::jsonb);
create temporary table _task_agenda_test(task_id uuid, weekly_id uuid);
grant select,insert,update on _task_agenda_test to authenticated;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is((public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001')->>'total_count')::integer,0,
 'empty agenda has zero results');
select throws_ok($$select public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001',current_date,15,25,0)$$,
 'P0001','Invalid task schedule page','reject unbounded future windows');
select throws_ok($$select public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001',current_date,7,0,0)$$,
 'P0001','Invalid task schedule page','reject unbounded page size');
select throws_ok($$select public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001',current_date+91,7,25,0)$$,
 'P0001','Invalid task schedule page','reject distant future dates');

insert into _task_agenda_test(task_id) values (
 public.stk_assign_coach_task(
 'f2000000-0000-0000-0000-000000000001',
 jsonb_build_object(
  'title','Revisión diaria voluntaria','recurrence_type','daily',
  'starts_on',current_date::text,'ends_on',(current_date+3)::text
 )));
select ok((select task_id is not null from _task_agenda_test),
 'existing task assignment RPC creates daily recurring task');
select is((public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001',current_date,7,25,0)->>'total_count')::integer,4,
 'four virtual due days are derived from recurrence');
select is(pg_catalog.jsonb_array_length(
 public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001',current_date,7,2,0)->'items'),2,
 'agenda supports bounded pagination');
select is(pg_catalog.jsonb_array_length(
 public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001',current_date,7,25,25)->'items'),0,
 'out-of-range offset is empty');
select ok((select bool_and(entry->'status'='null'::jsonb)
 from pg_catalog.jsonb_array_elements(public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001',current_date,7,25,0)->'items') entry),
 'missing occurrences remain null, never auto-skipped');
select is((select count(*)::integer from public.stk_coach_task_occurrences
 where task_id=(select task_id from _task_agenda_test)),0,
 'reading agenda creates no occurrence rows');

insert into _task_agenda_test(weekly_id) values(
 public.stk_assign_coach_task(
 'f2000000-0000-0000-0000-000000000001',
 jsonb_build_object(
  'title','Resumen semanal','recurrence_type','weekly',
  'weekdays',jsonb_build_array(extract(isodow from current_date)::integer),
  'starts_on',current_date::text,'ends_on',(current_date+6)::text
 )));
select is((public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001',current_date,7,25,0)->>'total_count')::integer,5,
 'weekly task contributes its scheduled weekday once');

select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001')$$,
 'P0001','Active task assignment permission required',
 'other entitled coach cannot read another relationship');
select set_config('request.jwt.claims','{"sub":"f2000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001')$$,
 'P0001','Coach capability required','client cannot invoke coach-only agenda');
select lives_ok($$select public.stk_set_coach_task_status(
 (select task_id from _task_agenda_test where task_id is not null),
 current_date,'completed',10)$$,'client alone records actual completion');

select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is((select entry->>'status' from pg_catalog.jsonb_array_elements(
 public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001',current_date,7,25,0)->'items') entry
 where entry->>'task_id'=(select task_id::text from _task_agenda_test
  where task_id is not null)
 and entry->>'due_on'=current_date::text),
 'completed','agenda displays genuine completion only');
select is((public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001',current_date,7,25,0)->>'total_count')::integer,5,
 'reading completed entries does not change due counts');

reset role;
update public.stk_coach_client_relationships set permissions='{}'::jsonb
 where id='f3000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001')$$,
 'P0001','Active task assignment permission required',
 'revoked task consent immediately hides the agenda');
reset role;
update public.stk_coach_client_relationships
 set permissions='{"assign_tasks":true}'::jsonb,status='paused'
 where id='f3000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001')$$,
 'P0001','Active task assignment permission required',
 'paused relationship hides the agenda');
reset role;
update public.stk_coach_client_relationships set status='active'
 where id='f3000000-0000-0000-0000-000000000001';
update public.stk_subscription_entitlements set status='expired'
 where user_id='f1000000-0000-0000-0000-000000000001' and product='coach_pro';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_task_schedule(
 'f3000000-0000-0000-0000-000000000001')$$,
 'P0001','Coach Pro entitlement required',
 'expired subscription cannot query task agenda');
select * from finish();
rollback;
