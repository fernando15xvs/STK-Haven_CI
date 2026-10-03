begin;
select plan(27);
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


update public.stk_coach_client_relationships set permissions='{"view_workouts":true}' where id='53000000-0000-0000-0000-000000000001';
insert into public.stk_client_workout_summaries(client_user_id,workout_id,started_at,routine_name,average_rir)
select '52000000-0000-0000-0000-000000000001',lpad(n::text,3,'0'),now(),'Shared workout',null from generate_series(1,27) n;
insert into public.stk_client_workout_summaries(client_user_id,workout_id,started_at,routine_name)
values ('52000000-0000-0000-0000-000000000002','other',now(),'Other client');
create temp table original_workouts as select * from public.stk_client_workout_summaries;
select ok(not has_function_privilege('anon','public.stk_list_coach_pro_client_workouts(uuid,integer,integer)','EXECUTE'),'anon execute denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(jsonb_array_length(public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)->'items'),25,'bounded page with workout permission only');
select is((public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)->>'total_count')::int,27,'client isolation in count');
select is(public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)->'items'->0->>'workout_id','001','stable ordering for tied timestamps');
select ok(public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)->'items'->0->'average_rir'='null'::jsonb,'missing RIR remains null');
select ok(not (public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)->'items'->0 ? 'notes') and not (public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)->'items'->0 ? 'sets') and not (public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0) ? 'progress'),'no notes sets or progress payload');
select is(jsonb_array_length(public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,25)->'items'),2,'last page bounded');
select is(public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,25)->'items'->0->>'workout_id','026','next page stable order');
select is(jsonb_array_length(public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,50)->'items'),0,'empty later page');
select is((public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,50)->>'total_count')::int,27,'empty page retains total');
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',0,0)$$,'P0001','Coach Pro page limit must be between 1 and 100','bounds 0,0');
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',101,0)$$,'P0001','Coach Pro page limit must be between 1 and 100','bounds 101,0');
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,-1)$$,'P0001','Coach Pro page offset is invalid','bounds 25,-1');
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,10001)$$,'P0001','Coach Pro page offset is invalid','bounds 25,10001');
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000002',25,0)$$,'P0001','Shared workouts access unavailable','unpermitted client');
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000009',25,0)$$,'P0001','Shared workouts access unavailable','unknown relationship');
reset role;
update public.stk_coach_client_relationships set permissions='{"view_progress":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,25)$$,'P0001','Shared workouts access unavailable','progress does not replace revoked workouts');
reset role;
update public.stk_coach_client_relationships set permissions='{"view_workouts":true}',status='paused',revoked_at=null where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Shared workouts access unavailable','paused denied');
reset role;
update public.stk_coach_client_relationships set permissions='{"view_workouts":true}',status='revoked',revoked_at=now() where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Shared workouts access unavailable','revoked denied');
reset role;
update public.stk_coach_client_relationships set status='active',revoked_at=null where id='53000000-0000-0000-0000-000000000001';
update public.stk_subscription_entitlements set status='expired';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Coach Pro entitlement required','expired denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":true}',true);
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Permanent authenticated account required','anonymous denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"52000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Coach capability required','client cannot use professional RPC');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Coach Pro entitlement required','no plan denied');
reset role;
insert into public.stk_subscription_entitlements(user_id,product,status,tier,client_limit,starts_at,current_period_end,source)
values ('51000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions)
values ('53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001','active','{"view_progress":true}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Shared workouts access unavailable','other coach cannot use first relationship');
select throws_ok($$select public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000003',25,0)$$,'P0001','Shared workouts access unavailable','another coach cannot borrow workouts permission');
reset role;
update public.stk_coach_client_relationships set permissions='{"view_workouts":true}' where id='53000000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select is((public.stk_list_coach_pro_client_workouts('53000000-0000-0000-0000-000000000003',25,0)->>'total_count')::int,27,'same client share requires own independent consent');
reset role;
select results_eq($$select * from public.stk_client_workout_summaries order by client_user_id,workout_id$$,$$select * from original_workouts order by client_user_id,workout_id$$,'reads and access changes never alter shared snapshot');
select * from finish();
rollback;

