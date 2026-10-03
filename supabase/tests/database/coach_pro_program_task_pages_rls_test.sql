begin;
select plan(48);
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


select has_function('public','stk_list_coach_pro_client_programs',array['uuid','integer','integer'],'programs page RPC exists');
select ok(not has_function_privilege('anon','public.stk_list_coach_pro_client_programs(uuid,integer,integer)','EXECUTE'),'programs denies anon execution');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001')$$,'P0001','Coach Pro entitlement required','programs requires plan');
reset role;
select has_function('public','stk_list_coach_pro_client_tasks',array['uuid','integer','integer'],'tasks page RPC exists');
select ok(not has_function_privilege('anon','public.stk_list_coach_pro_client_tasks(uuid,integer,integer)','EXECUTE'),'tasks denies anon execution');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001')$$,'P0001','Coach Pro entitlement required','tasks requires plan');
reset role;
update public.stk_coach_client_relationships set permissions='{"assign_programs":true,"assign_tasks":true}' where id='53000000-0000-0000-0000-000000000001';
insert into public.stk_subscription_entitlements(user_id,product,status,tier,client_limit,starts_at,current_period_end,source)
values ('51000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions)
values ('53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001','active','{"assign_programs":true,"assign_tasks":true}');
insert into public.stk_assigned_programs(id,relationship_id,coach_user_id,client_user_id,name,notes,status)
select ('56000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'53000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001',
  'Program '||n,'Excluded program notes',case when n=27 then 'archived' else 'assigned' end
from generate_series(1,27) n;
insert into public.stk_coach_tasks(id,relationship_id,coach_user_id,client_user_id,title,coach_instructions,status)
select ('55000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'53000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001',
  'Task '||n,'Excluded task instructions',case when n=27 then 'archived' else 'active' end
from generate_series(2,27) n;
insert into public.stk_assigned_programs(id,relationship_id,coach_user_id,client_user_id,name)
values ('56000000-0000-0000-0000-000000000100','53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001','Other coach program');
insert into public.stk_coach_tasks(id,relationship_id,coach_user_id,client_user_id,title)
values ('55000000-0000-0000-0000-000000000100','53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001','Other coach task');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is((select count(*) from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001')),25::bigint,'programs default page is bounded');
select is((select total_count from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',1,25)),27::bigint,'programs total excludes other coach');
select is((select id from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',1,25)),'56000000-0000-0000-0000-000000000026'::uuid,'programs tied dates use stable ID ordering');
select is((select count(*) from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',25,25)),2::bigint,'programs last page only has remaining rows');
select is((select count(*) from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',25,50)),0::bigint,'programs beyond last page is empty');
select is((select status from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',1,26)),'archived','programs history retains archived rows');
select ok((select not (to_jsonb(p) ? 'notes') from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',1,0) p),'programs list excludes text outside its summary contract');
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000002')$$,'P0001','Client programs access unavailable','programs rejects missing permission');
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000003')$$,'P0001','Client programs access unavailable','programs rejects other coach same client');
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000099')$$,'P0001','Client programs access unavailable','programs rejects unknown relation');
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',0,0)$$,'P0001','Coach Pro page limit must be between 1 and 100','programs validates bounds 0 0');
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',101,0)$$,'P0001','Coach Pro page limit must be between 1 and 100','programs validates bounds 101 0');
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',25,-1)$$,'P0001','Coach Pro page offset is invalid','programs validates bounds 25 -1');
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',25,10001)$$,'P0001','Coach Pro page offset is invalid','programs validates bounds 25 10001');
select is((select count(*) from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001')),25::bigint,'tasks default page is bounded');
select is((select total_count from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',1,25)),27::bigint,'tasks total excludes other coach');
select is((select id from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',1,25)),'55000000-0000-0000-0000-000000000026'::uuid,'tasks tied dates use stable ID ordering');
select is((select count(*) from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',25,25)),2::bigint,'tasks last page only has remaining rows');
select is((select count(*) from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',25,50)),0::bigint,'tasks beyond last page is empty');
select is((select status from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',1,26)),'archived','tasks history retains archived rows');
select ok((select not (to_jsonb(p) ? 'coach_instructions') from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',1,0) p),'tasks list excludes text outside its summary contract');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000002')$$,'P0001','Client tasks access unavailable','tasks rejects missing permission');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000003')$$,'P0001','Client tasks access unavailable','tasks rejects other coach same client');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000099')$$,'P0001','Client tasks access unavailable','tasks rejects unknown relation');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',0,0)$$,'P0001','Coach Pro page limit must be between 1 and 100','tasks validates bounds 0 0');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',101,0)$$,'P0001','Coach Pro page limit must be between 1 and 100','tasks validates bounds 101 0');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',25,-1)$$,'P0001','Coach Pro page offset is invalid','tasks validates bounds 25 -1');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',25,10001)$$,'P0001','Coach Pro page offset is invalid','tasks validates bounds 25 10001');
reset role;
update public.stk_coach_client_relationships set permissions='{"assign_tasks":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',25,25)$$,'P0001','Client programs access unavailable','programs revocation blocks next page independently');
select is((select count(*) from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',1,0)),1::bigint,'tasks remains permitted');
reset role;
update public.stk_coach_client_relationships set permissions='{"assign_programs":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001',25,25)$$,'P0001','Client tasks access unavailable','tasks revocation blocks next page independently');
select is((select count(*) from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001',1,0)),1::bigint,'programs remains permitted');
reset role;
update public.stk_coach_client_relationships set status='paused',revoked_at=null, permissions='{"assign_programs":true,"assign_tasks":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001')$$,'P0001','Client programs access unavailable','paused blocks programs');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001')$$,'P0001','Client tasks access unavailable','paused blocks tasks');
reset role;
update public.stk_coach_client_relationships set status='revoked',revoked_at=now(), permissions='{"assign_programs":true,"assign_tasks":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001')$$,'P0001','Client programs access unavailable','revoked blocks programs');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001')$$,'P0001','Client tasks access unavailable','revoked blocks tasks');
reset role;
update public.stk_subscription_entitlements set status='expired' where user_id='51000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001')$$,'P0001','Coach Pro entitlement required','expired plan blocks programs');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001')$$,'P0001','Coach Pro entitlement required','expired plan blocks tasks');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":true}',true);
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000003')$$,'P0001','Permanent authenticated account required','anonymous blocks programs');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000003')$$,'P0001','Permanent authenticated account required','anonymous blocks tasks');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"52000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select * from public.stk_list_coach_pro_client_programs('53000000-0000-0000-0000-000000000001')$$,'P0001','Coach capability required','non-coach blocked programs');
select throws_ok($$select * from public.stk_list_coach_pro_client_tasks('53000000-0000-0000-0000-000000000001')$$,'P0001','Coach capability required','non-coach blocked tasks');
select * from finish();
rollback;
