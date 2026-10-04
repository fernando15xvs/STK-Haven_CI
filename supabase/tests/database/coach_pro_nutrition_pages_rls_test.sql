begin;
select plan(37);
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


update public.stk_coach_client_relationships set permissions='{"view_nutrition":true}' where id='53000000-0000-0000-0000-000000000001';
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions)
values ('53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001','active','{"view_nutrition":true}');
insert into public.stk_nutrition_guidance_plans(id,relationship_id,coach_user_id,client_user_id)
select ('61000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'53000000-0000-0000-0000-000000000001',
'51000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001' from generate_series(1,27)n;
insert into public.stk_nutrition_guidance_plans(id,relationship_id,coach_user_id,client_user_id)
values ('61000000-0000-0000-0000-000000000028','53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001'),
('61000000-0000-0000-0000-000000000029','53000000-0000-0000-0000-000000000002','51000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000002');
insert into public.stk_nutrition_guidance_versions(id,plan_id,version,title,overview,scope_notice,created_by)
select ('62000000-0000-0000-0000-'||lpad((row_number() over(order by id))::text,12,'0'))::uuid,id,1,'Original title','Original overview',
'Orientación general no clínica y compartida.',coach_user_id from public.stk_nutrition_guidance_plans;
insert into public.stk_nutrition_guidance_versions(id,plan_id,version,title,scope_notice,created_by)
values ('62000000-0000-0000-0000-000000000030','61000000-0000-0000-0000-000000000001',2,'New title','Orientación general no clínica y compartida.','51000000-0000-0000-0000-000000000001');
update public.stk_nutrition_guidance_plans set current_version=2 where id='61000000-0000-0000-0000-000000000001';
insert into public.stk_nutrition_guidance_meals(id,version_id,position,name)
select ('63000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'62000000-0000-0000-0000-000000000001',n-1,'Meal '||n from generate_series(1,6)n;
insert into public.stk_nutrition_guidance_meals(id,version_id,position,name)
values ('63000000-0000-0000-0000-000000000007','62000000-0000-0000-0000-000000000030',0,'New version meal');
insert into public.stk_nutrition_guidance_items(meal_id,position,food_example,serving_note)
values ('63000000-0000-0000-0000-000000000001',0,'Shared example','Shared serving');
create temp table original_versions as select * from public.stk_nutrition_guidance_versions;
select ok(not has_function_privilege('anon','public.stk_list_coach_pro_nutrition(uuid,integer,integer)','EXECUTE'),'anon denied 0');
select ok(not has_function_privilege('anon','public.stk_get_coach_pro_nutrition_page(uuid,uuid,integer,integer)','EXECUTE'),'anon denied 1');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(jsonb_array_length(public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,0)->'items'),25,'list bounded');
select is((public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,0)->>'total_count')::int,27,'list excludes other coach and client');
select is(public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,0)->'items'->0->>'title','New title','list uses current version');
select ok(not (public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,0)->'items'->0 ? 'meals') and not (public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,0)->'items'->0 ? 'overview'),'summary excludes details');
select is(jsonb_array_length(public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,25)->'items'),2,'second list page');
select is((public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,50)->>'total_count')::int,27,'empty list page keeps total');
select is(public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)->'plan'->>'title','Original title','detail stays on selected version');
select is(jsonb_array_length(public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)->'plan'->'meals'),5,'detail bounded to five meals');
select is(public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)->'plan'->'meals'->0->'items'->0->>'food_example','Shared example','nested item preserved');
select is(public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)->'plan'->'meals'->0->'items'->0->>'serving_note','Shared serving','serving preserved');
select is(public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,5)->'plan'->'meals'->0->>'name','Meal 6','meal next page order');
select is((public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,10)->>'total_count')::int,6,'empty detail page keeps count');
select is(public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',2,0)->'plan'->'meals'->0->>'name','New version meal','versions never mix');
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',3,0)$$,'P0001','Nutrition version unavailable','unknown version');
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',null,0)$$,'P0001','Nutrition version is invalid','missing pinned version');
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,-1)$$,'P0001','Coach Pro page offset is invalid','negative detail offset');
select throws_ok($$select public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',101,0)$$,'P0001','Coach Pro page limit must be between 1 and 100','list bound');
select throws_ok($$select public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,10001)$$,'P0001','Coach Pro page offset is invalid','list offset bound');
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000028',1,0)$$,'P0001','Nutrition access unavailable','other coach plan');
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000003','61000000-0000-0000-0000-000000000001',1,0)$$,'P0001','Nutrition access unavailable','wrong relationship');
reset role;
update public.stk_nutrition_guidance_plans set status='archived',archived_at=now() where id='61000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)->'plan'->>'status','archived','archived plan still readable with consent');
reset role;
update public.stk_coach_client_relationships set status='active',revoked_at=null,permissions='{"view_progress":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Nutrition access unavailable','active list blocked');
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)$$,'P0001','Nutrition access unavailable','active detail blocked');
reset role;
update public.stk_coach_client_relationships set status='paused',revoked_at=null,permissions='{"view_nutrition":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Nutrition access unavailable','paused list blocked');
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)$$,'P0001','Nutrition access unavailable','paused detail blocked');
reset role;
update public.stk_coach_client_relationships set status='revoked',revoked_at=now(),permissions='{"view_nutrition":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Nutrition access unavailable','revoked list blocked');
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)$$,'P0001','Nutrition access unavailable','revoked detail blocked');
reset role;
update public.stk_subscription_entitlements set status='expired';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Coach Pro entitlement required','expired list');
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)$$,'P0001','Coach Pro entitlement required','expired detail');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":true}',true);
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)$$,'P0001','Permanent authenticated account required','anonymous detail');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"52000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)$$,'P0001','Coach capability required','noncoach detail');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000001',25,0)$$,'P0001','Coach Pro entitlement required','no plan list');
reset role;
insert into public.stk_subscription_entitlements(user_id,product,status,tier,client_limit,starts_at,current_period_end,source)
values ('51000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_nutrition_page('53000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',1,0)$$,'P0001','Nutrition access unavailable','other paid coach same client');
select is((public.stk_list_coach_pro_nutrition('53000000-0000-0000-0000-000000000003',25,0)->>'total_count')::int,1,'other coach only owns own plan');
reset role;
select results_eq($$select * from public.stk_nutrition_guidance_versions order by id$$,$$select * from original_versions order by id$$,'read and access changes preserve version history');
select * from finish();
rollback;
