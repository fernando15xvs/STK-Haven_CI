begin;
select plan(33);
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


update public.stk_coach_client_relationships set permissions='{"assign_programs":true}' where id='53000000-0000-0000-0000-000000000001';
insert into public.stk_subscription_entitlements(user_id,product,status,tier,client_limit,starts_at,current_period_end,source)
values ('51000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions)
values ('53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001','active','{"assign_programs":true}');
insert into public.stk_assigned_programs(id,relationship_id,coach_user_id,client_user_id,name,version,notes)
values ('56000000-0000-0000-0000-000000000001','53000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001','Plan A',2,'Excluded notes'),
 ('56000000-0000-0000-0000-000000000002','53000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001','Plan B',1,''),('56000000-0000-0000-0000-000000000003','53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001','Other coach',1,'');
insert into public.stk_assigned_program_routines(id,assignment_id,position,name,notes)
select ('57000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'56000000-0000-0000-0000-000000000001',n-1,'Routine '||n,'Excluded routine notes'
from generate_series(1,27) n;
insert into public.stk_assigned_program_routines(id,assignment_id,position,name)
values ('57000000-0000-0000-0000-000000000100','56000000-0000-0000-0000-000000000002',0,'Other program routine');
insert into public.stk_assigned_program_exercises(id,routine_id,position,exercise_name,target_sets,target_reps_min,target_reps_max,rest_seconds)
select ('58000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'57000000-0000-0000-0000-000000000001',n-1,'Exercise '||n,3,8,12,90
from generate_series(1,27) n;
select has_function('public','stk_get_coach_pro_program_page',array['uuid','uuid','integer','uuid','integer','integer'],'program page RPC exists');
select ok(not has_function_privilege('anon','public.stk_get_coach_pro_program_page(uuid,uuid,integer,uuid,integer,integer)','EXECUTE'),'anon execute revoked');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(jsonb_array_length(public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,0)->'items'),25,'routine page bounded');
select is((public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,0)->>'total_count')::int,27,'routine total');
select is(public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,25)->'items'->0->>'id','57000000-0000-0000-0000-000000000026','routine offset ordering');
select is(jsonb_array_length(public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,25)->'items'),2,'routine final page');
select is(jsonb_array_length(public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,50)->'items'),0,'routine empty page');
select is((public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,50)->>'total_count')::int,27,'empty page keeps authoritative total');
select ok(not (public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,0) ? 'notes') and not (public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,0)->'items'->0 ? 'notes') and not (public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,0)->'items'->0 ? 'exercises'),'summary excludes notes and nested exercises');
select is((public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,0)->>'version')::int,2,'selected version retained');
select is(jsonb_array_length(public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,'57000000-0000-0000-0000-000000000001',25,0)->'items'),25,'exercise page bounded');
select is((public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,'57000000-0000-0000-0000-000000000001',25,0)->>'total_count')::int,27,'exercise total');
select is(public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,'57000000-0000-0000-0000-000000000001',25,25)->'items'->0->>'name','Exercise 26','exercise offset ordering');
select is((public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,'57000000-0000-0000-0000-000000000001',25,0)->'items'->0->>'target_sets')::int,3,'exercise prescription preserved');
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000003','56000000-0000-0000-0000-000000000003',1,null,25,0)$$,'P0001','Assigned program access unavailable','other coach same client rejected');
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000002',1,'57000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Assigned program access unavailable','routine belongs to different program rejected');
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,'57000000-0000-0000-0000-000000000100',25,0)$$,'P0001','Assigned program access unavailable','other routine in own relationship rejected');
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000099',2,null,25,0)$$,'P0001','Assigned program access unavailable','unknown assignment rejected');
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000003','56000000-0000-0000-0000-000000000001',2,null,25,0)$$,'P0001','Assigned program access unavailable','wrong relationship rejected');
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',1,null,25,0)$$,'P0001','Assigned program version changed; reload','stale version rejected');
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',null,null,25,0)$$,'P0001','Assigned program version changed; reload','missing version rejected');
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,0,0)$$,'P0001','Coach Pro page limit must be between 1 and 100','bounds 0 0');
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,101,0)$$,'P0001','Coach Pro page limit must be between 1 and 100','bounds 101 0');
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,-1)$$,'P0001','Coach Pro page offset is invalid','bounds 25 -1');
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,10001)$$,'P0001','Coach Pro page offset is invalid','bounds 25 10001');
reset role;
update public.stk_assigned_programs set version=3,status='archived' where id='56000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',2,null,25,25)$$,'P0001','Assigned program version changed; reload','version change between pages detected');
select is(public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',3,null,25,0)->>'status','archived','archived version remains readable with access');
reset role;
update public.stk_coach_client_relationships set permissions='{"assign_tasks":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',3,null,25,0)$$,'P0001','Assigned program access unavailable','other permission cannot grant program read');
reset role;
update public.stk_coach_client_relationships set status='paused',permissions='{"assign_programs":true}',revoked_at=null where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',3,'57000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Assigned program access unavailable','paused blocks exercise page');
reset role;
update public.stk_coach_client_relationships set status='revoked',permissions='{"assign_programs":true}',revoked_at=now() where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',3,'57000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Assigned program access unavailable','revoked blocks exercise page');
reset role;
update public.stk_subscription_entitlements set status='expired' where user_id='51000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',3,null,25,0)$$,'P0001','Coach Pro entitlement required','expired plan blocked');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":true}',true);
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000003','56000000-0000-0000-0000-000000000003',1,null,25,0)$$,'P0001','Permanent authenticated account required','anonymous blocked');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"52000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_program_page('53000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',3,null,25,0)$$,'P0001','Coach capability required','non-coach blocked');
select * from finish();
rollback;
