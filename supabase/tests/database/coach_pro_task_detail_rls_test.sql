begin;
select plan(34);
insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
)
values
('51000000-0000-0000-0000-000000000001','authenticated','authenticated','dashboard-coach@example.com','',now(),now(),now(),'{}','{}'),
('51000000-0000-0000-0000-000000000002','authenticated','authenticated','dashboard-no-plan@example.com','',now(),now(),now(),'{}','{}'),
('52000000-0000-0000-0000-000000000001','authenticated','authenticated','dashboard-client-a@example.com','',now(),now(),now(),'{}','{}'),
('52000000-0000-0000-0000-000000000002','authenticated','authenticated','dashboard-client-b@example.com','',now(),now(),now(),'{}','{}'),
('52000000-0000-0000-0000-000000000003','authenticated','authenticated','dashboard-unrelated@example.com','',now(),now(),now(),'{}','{}');

insert into public.stk_user_profiles(user_id, display_name) values
('51000000-0000-0000-0000-000000000001','Dashboard Coach'),
('51000000-0000-0000-0000-000000000002','Coach No Plan'),
('52000000-0000-0000-0000-000000000001','Ana Alpha'),
('52000000-0000-0000-0000-000000000002','Bruno Beta'),
('52000000-0000-0000-0000-000000000003','Carlos Unrelated');

insert into public.stk_user_capabilities(user_id, capability) values
('51000000-0000-0000-0000-000000000001','coach'),
('51000000-0000-0000-0000-000000000002','coach'),
('52000000-0000-0000-0000-000000000001','athlete'),
('52000000-0000-0000-0000-000000000002','athlete'),
('52000000-0000-0000-0000-000000000003','athlete');

insert into public.stk_subscription_entitlements(
  user_id, product, status, tier, client_limit,
  starts_at, current_period_end, source
) values (
  '51000000-0000-0000-0000-000000000001',
  'coach_pro','active','test',10,
  now() - interval '1 day', now() + interval '30 days','pgTap'
);

insert into public.stk_coach_client_relationships(
  id, coach_user_id, client_user_id, status, permissions
) values
(
  '53000000-0000-0000-0000-000000000001',
  '51000000-0000-0000-0000-000000000001',
  '52000000-0000-0000-0000-000000000001',
  'active',
  '{"view_progress":true,"view_checkins":true,"assign_tasks":true}'::jsonb
),
(
  '53000000-0000-0000-0000-000000000002',
  '51000000-0000-0000-0000-000000000001',
  '52000000-0000-0000-0000-000000000002',
  'active',
  '{}'::jsonb
);

insert into public.stk_client_progress_snapshots(
  client_user_id, workouts_7d, workouts_30d, training_minutes_7d,
  completed_working_sets_7d, volume_7d, average_rir_7d,
  last_workout_at, generated_at
) values
(
  '52000000-0000-0000-0000-000000000001',
  4, 15, 240, 52, 12000, 2.2, now() - interval '1 day', now()
),
(
  '52000000-0000-0000-0000-000000000002',
  6, 20, 300, 60, 14000, 1.8, now() - interval '1 day', now()
),
(
  '52000000-0000-0000-0000-000000000003',
  7, 22, 360, 70, 16000, 2.0, now() - interval '1 day', now()
);

insert into public.stk_coach_checkins(
  id, relationship_id, coach_user_id, client_user_id,
  energy, recovery, note, created_at
) values (
  '54000000-0000-0000-0000-000000000001',
  '53000000-0000-0000-0000-000000000001',
  '51000000-0000-0000-0000-000000000001',
  '52000000-0000-0000-0000-000000000001',
  4, 4, 'ok', now() - interval '2 hours'
);

insert into public.stk_coach_tasks(
  id, relationship_id, coach_user_id, client_user_id, title, category,
  task_type, target_minutes, recurrence_type, weekdays, starts_on,
  coach_instructions, status
) values (
  '55000000-0000-0000-0000-000000000001',
  '53000000-0000-0000-0000-000000000001',
  '51000000-0000-0000-0000-000000000001',
  '52000000-0000-0000-0000-000000000001',
  'Mobility','Recovery','checklist',10,'once','{}',current_date,'','active'
);


select has_function('public','stk_get_coach_pro_task_page',array['uuid','uuid','integer','integer'],'task page RPC exists');
select ok(not has_function_privilege('anon','public.stk_get_coach_pro_task_page(uuid,uuid,integer,integer)','EXECUTE'),'anon execute denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Coach Pro entitlement required','coach without plan rejected');
reset role;
insert into public.stk_subscription_entitlements(user_id,product,status,tier,client_limit,starts_at,current_period_end,source)
values ('51000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions)
values ('53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001','active','{"assign_tasks":true}');
update public.stk_coach_tasks set recurrence_type='daily',starts_on=current_date-40,coach_instructions='Shared instructions' where id='55000000-0000-0000-0000-000000000001';
insert into public.stk_coach_tasks(id,relationship_id,coach_user_id,client_user_id,title)
values ('55000000-0000-0000-0000-000000000002','53000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001','Other own task'),('55000000-0000-0000-0000-000000000003','53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001','Other coach task');
insert into public.stk_coach_task_occurrences(id,task_id,client_user_id,occurrence_date,status,minutes_spent,completed_at)
select ('59000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'55000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001',current_date-n,
  case when n=1 then 'skipped' else 'completed' end,case when n=1 then 0 else 15 end,
  case when n=1 then null else now()-make_interval(days=>n) end
from generate_series(1,27) n;
insert into public.stk_coach_task_occurrences(id,task_id,client_user_id,occurrence_date,status)
values ('59000000-0000-0000-0000-000000000100','55000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001',current_date,'completed'),
 ('59000000-0000-0000-0000-000000000101','55000000-0000-0000-0000-000000000003','52000000-0000-0000-0000-000000000001',current_date,'completed'),
 ('59000000-0000-0000-0000-000000000102','55000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000003',current_date,'completed');
create temp table original_occurrences as select * from public.stk_coach_task_occurrences;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(jsonb_array_length(public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'items'),25,'default page bounded');
select is((public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->>'total_count')::int,27,'count excludes other task, coach and inconsistent client');
select is(public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'task'->>'id','55000000-0000-0000-0000-000000000001','task metadata is targeted');
select is(public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'task'->>'coach_instructions','Shared instructions','assigned instructions preserved');
select is(public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'items'->0->>'status','skipped','explicit skip preserved');
select is((public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'items'->0->>'minutes_spent')::int,0,'zero minutes is not invented completion');
select ok(public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'items'->0->'completed_at'='null'::jsonb,'skip completion timestamp stays null');
select is(public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'items'->1->>'status','completed','completed status preserved');
select is((public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'items'->1->>'minutes_spent')::int,15,'recorded minutes preserved');
select is(public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,25)->'items'->0->>'id','59000000-0000-0000-0000-000000000026','date ordering across pages');
select is(jsonb_array_length(public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,25)->'items'),2,'last page only remaining records');
select is(jsonb_array_length(public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,50)->'items'),0,'empty later page');
select is((public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,50)->>'total_count')::int,27,'empty page preserves total');
select ok(not (public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0) ? 'comments') and not (public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0) ? 'adherence'),'no comment or inferred adherence payload');
select is((public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000002',25,0)->>'total_count')::int,1,'different task stays isolated');
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000003','55000000-0000-0000-0000-000000000003',25,0)$$,'P0001','Assigned task access unavailable','other coach same client rejected');
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000003','55000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Assigned task access unavailable','wrong relationship rejected');
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000009',25,0)$$,'P0001','Assigned task access unavailable','unknown task rejected');
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',0,0)$$,'P0001','Coach Pro page limit must be between 1 and 100','bounds 0 0');
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',101,0)$$,'P0001','Coach Pro page limit must be between 1 and 100','bounds 101 0');
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,-1)$$,'P0001','Coach Pro page offset is invalid','bounds 25 -1');
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,10001)$$,'P0001','Coach Pro page offset is invalid','bounds 25 10001');
reset role;
update public.stk_coach_tasks set status='archived',archived_at=now() where id='55000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'task'->>'status','archived','archived status preserved');
select is((public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->>'total_count')::int,27,'archive retains history');
reset role;
update public.stk_coach_client_relationships set permissions='{"assign_programs":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,25)$$,'P0001','Assigned task access unavailable','permission revocation blocks next page');
reset role;
update public.stk_coach_client_relationships set status='paused',permissions='{"assign_tasks":true}',revoked_at=null where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Assigned task access unavailable','paused blocks detail');
reset role;
update public.stk_coach_client_relationships set status='revoked',permissions='{"assign_tasks":true}',revoked_at=now() where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Assigned task access unavailable','revoked blocks detail');
reset role;
update public.stk_subscription_entitlements set status='expired' where user_id='51000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Coach Pro entitlement required','expired plan blocks history');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":true}',true);
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000003','55000000-0000-0000-0000-000000000003',25,0)$$,'P0001','Permanent authenticated account required','anonymous blocked');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"52000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_task_page('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Coach capability required','non-coach cannot use Pro detail');
reset role;
select results_eq($$select * from public.stk_coach_task_occurrences order by id$$,$$select * from original_occurrences order by id$$,'reads and access changes preserve entire finalized history');
select * from finish();
rollback;
