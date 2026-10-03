begin;
select plan(23);
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


update public.stk_coach_client_relationships set permissions='{"comment":true}' where id='53000000-0000-0000-0000-000000000001';
insert into public.stk_coach_task_comments(id,task_id,author_user_id,body)
values ('59000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001','Existing client comment');
create temp table original_comments as select * from public.stk_coach_task_comments;
select ok(not has_function_privilege('anon','public.stk_add_coach_pro_task_comment(uuid,uuid,text)','EXECUTE'),'anon cannot invoke write');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select lives_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','  Shared comment  ')$$,'comment-only permission can send');
select is((select count(*)::int from jsonb_array_elements(public.stk_list_coach_pro_task_comments('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'items') as item where item->>'body'='Shared comment'),1,'one trimmed append');
select is((select item->>'author_user_id' from jsonb_array_elements(public.stk_list_coach_pro_task_comments('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'items') as item where item->>'body'='Shared comment'),'51000000-0000-0000-0000-000000000001','server sets coach author');
select ok((select item->'occurrence_date'='null'::jsonb from jsonb_array_elements(public.stk_list_coach_pro_task_comments('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',25,0)->'items') as item where item->>'body'='Shared comment'),'no fabricated occurrence date');
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','')$$,'P0001','Comment length is invalid','invalid body ');
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',repeat('a',2001))$$,'P0001','Comment length is invalid','invalid body repeat(a,2001)');
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',null)$$,'P0001','Comment length is invalid','invalid body null');
select lives_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',repeat('😀',2000))$$,'unicode codepoint boundary');
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000002','55000000-0000-0000-0000-000000000001','  Shared comment  ')$$,'P0001','Task comments access unavailable','wrong 530');
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000002','  Shared comment  ')$$,'P0001','Task comments access unavailable','wrong 550');
reset role;
update public.stk_coach_tasks set status='archived',archived_at=now();
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select lives_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','  Archived comment  ')$$,'archived task permits discussion');
reset role;
update public.stk_coach_client_relationships set permissions='{"assign_tasks":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','  Shared comment  ')$$,'P0001','Task comments access unavailable','revoked comment blocks sending despite assign_tasks');
reset role;
update public.stk_coach_client_relationships set permissions='{"comment":true}',status='paused',revoked_at=null where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','  Shared comment  ')$$,'P0001','Task comments access unavailable','paused denied');
reset role;
update public.stk_coach_client_relationships set permissions='{"comment":true}',status='revoked',revoked_at=now() where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','  Shared comment  ')$$,'P0001','Task comments access unavailable','revoked denied');
reset role;
update public.stk_coach_client_relationships set status='active',revoked_at=null where id='53000000-0000-0000-0000-000000000001';
update public.stk_subscription_entitlements set status='expired';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','  Shared comment  ')$$,'P0001','Coach Pro entitlement required','expired coach cannot send');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":true}',true);
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','  Shared comment  ')$$,'P0001','Permanent authenticated account required','anonymous denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"52000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','  Shared comment  ')$$,'P0001','Coach capability required','client cannot invoke professional write');
select lives_ok($$select public.stk_add_coach_task_comment('55000000-0000-0000-0000-000000000001',null,'Client reply')$$,'legacy client rights survive coach expiration');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','  Shared comment  ')$$,'P0001','Coach Pro entitlement required','no plan denied');
reset role;
insert into public.stk_subscription_entitlements(user_id,product,status,tier,client_limit,starts_at,current_period_end,source) values ('51000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions) values ('53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001','active','{"comment":true}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_add_coach_pro_task_comment('53000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001','  Shared comment  ')$$,'P0001','Task comments access unavailable','other coach same client cannot send');
reset role;
select results_eq($$select * from public.stk_coach_task_comments where id='59000000-0000-0000-0000-000000000001'$$,$$select * from original_comments$$,'original comment unchanged');
select is((select count(*)::int from public.stk_coach_task_comments),5,'only four authorized appends, rejected attempts write nothing');
select * from finish();
rollback;
