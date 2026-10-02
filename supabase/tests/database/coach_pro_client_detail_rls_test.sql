begin;
select plan(28);
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


select has_function('public','stk_get_coach_pro_client',array['uuid'],'targeted summary exists');
select has_function('public','stk_list_coach_pro_client_checkins',array['uuid','integer','integer'],'paged check-ins exist');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select * from public.stk_get_coach_pro_client('53000000-0000-0000-0000-000000000001')$$,
  'P0001','Coach Pro entitlement required','summary requires entitlement');
select throws_ok($$select * from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001')$$,
  'P0001','Coach Pro entitlement required','check-ins require entitlement');
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select results_eq(
  $$select * from public.stk_get_coach_pro_client('53000000-0000-0000-0000-000000000001')$$,
  $$select * from public.stk_list_coach_pro_clients('alpha',25,0)$$,
  'targeted summary matches permitted roster contract');
select ok((select workouts_7d is null and active_task_count is null and latest_checkin_at is null
  from public.stk_get_coach_pro_client('53000000-0000-0000-0000-000000000002')),
  'targeted summary redacts unpermitted aggregates');
select is((select count(*) from public.stk_get_coach_pro_client('53000000-0000-0000-0000-000000000099')),
  0::bigint,'unknown relationship has no metadata');
select throws_ok($$select * from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000002')$$,
  'P0001','Client check-in access unavailable','no-permission section is rejected');
select throws_ok($$select * from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000099')$$,
  'P0001','Client check-in access unavailable','unknown relationship has same denial');
reset role;
insert into public.stk_subscription_entitlements(user_id,product,status,tier,client_limit,starts_at,current_period_end,source)
values ('51000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions)
values ('53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002',
  '52000000-0000-0000-0000-000000000001','active','{"view_checkins":true}');
insert into public.stk_coach_checkins(id,relationship_id,coach_user_id,client_user_id,energy,recovery,note,created_at)
select ('54000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
  '53000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',
  '52000000-0000-0000-0000-000000000001',3,4,'Shared note',now()-interval '1 hour'
from generate_series(2,27) n;
insert into public.stk_coach_checkins(id,relationship_id,coach_user_id,client_user_id,energy,recovery,note,created_at)
values ('54000000-0000-0000-0000-000000000100','53000000-0000-0000-0000-000000000003',
  '51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001',1,1,'Other coach private context',now());
set local role authenticated;
select is((select count(*) from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001')),
  25::bigint,'one page is bounded to 25');
select is((select total_count from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001',1,25)),
  27::bigint,'count includes only this coach relationship');
select is((select id from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001',1,25)),
  '54000000-0000-0000-0000-000000000027'::uuid,'ties have deterministic pagination');
select is((select count(*) from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001',25,25)),
  2::bigint,'last page contains only remaining rows');
select is((select count(*) from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001',25,50)),
  0::bigint,'beyond last page is empty');
select is((select count(*) from public.stk_get_coach_pro_client('53000000-0000-0000-0000-000000000003')),
  0::bigint,'other coach relationship metadata is unavailable');
select throws_ok($$select * from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000003')$$,
  'P0001','Client check-in access unavailable','same client does not grant other coach notes');
select throws_ok($$select * from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001',101,0)$$,
  'P0001','Coach Pro page limit must be between 1 and 100','oversized page rejected');
select throws_ok($$select * from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001',25,-1)$$,
  'P0001','Coach Pro page offset is invalid','negative offset rejected');
select throws_ok($$select * from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001',25,10001)$$,
  'P0001','Coach Pro page offset is invalid','excess offset rejected');
reset role;
update public.stk_coach_client_relationships set status='paused' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select ok((select workouts_7d is null and latest_checkin_at is null and active_task_count is null
  from public.stk_get_coach_pro_client('53000000-0000-0000-0000-000000000001')),
  'paused summary has metadata only');
select throws_ok($$select * from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001')$$,
  'P0001','Client check-in access unavailable','pause prevents subsequent page reads');
reset role;
update public.stk_coach_client_relationships set status='active',permissions='{}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select throws_ok($$select * from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001',25,25)$$,
  'P0001','Client check-in access unavailable','permission revocation blocks next page');
reset role;
update public.stk_coach_client_relationships set status='revoked',revoked_at=now() where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select is((select count(*) from public.stk_get_coach_pro_client('53000000-0000-0000-0000-000000000001')),
  0::bigint,'revoked relationship disappears from direct lookup');
reset role;
update public.stk_subscription_entitlements set status='expired' where user_id='51000000-0000-0000-0000-000000000001';
set local role authenticated;
select throws_ok($$select * from public.stk_get_coach_pro_client('53000000-0000-0000-0000-000000000002')$$,
  'P0001','Coach Pro entitlement required','expired plan blocks direct summary');
select throws_ok($$select * from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000001')$$,
  'P0001','Coach Pro entitlement required','expired plan blocks check-in page');
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":true}',true);
select throws_ok($$select * from public.stk_get_coach_pro_client('53000000-0000-0000-0000-000000000003')$$,
  'P0001','Permanent authenticated account required','anonymous cannot read summary');
select throws_ok($$select * from public.stk_list_coach_pro_client_checkins('53000000-0000-0000-0000-000000000003')$$,
  'P0001','Permanent authenticated account required','anonymous cannot read check-ins');
select set_config('request.jwt.claims','{"sub":"52000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select * from public.stk_get_coach_pro_client('53000000-0000-0000-0000-000000000001')$$,
  'P0001','Coach capability required','non-coach cannot read Pro summary');
select * from finish();
rollback;
