begin;

select plan(44);

select has_function(
  'public',
  'stk_list_coach_pro_clients',
  array['text','integer','integer'],
  'Coach Pro roster RPC exists'
);

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

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select * from public.stk_list_coach_pro_clients(null,25,0)$$,
  'P0001',
  'Coach Pro entitlement required',
  'coach role without entitlement cannot query professional roster'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_list_coach_pro_clients(null,25,0)),
  2,
  'dashboard returns only linked non-revoked clients'
);

select is(
  (
    select total_count::integer
      from public.stk_list_coach_pro_clients(null,1,0)
     limit 1
  ),
  2,
  'pagination preserves total filtered count'
);

select is(
  (
    select workouts_7d
      from public.stk_list_coach_pro_clients(null,25,0)
     where client_user_id = '52000000-0000-0000-0000-000000000001'
  ),
  4,
  'progress aggregate is visible with view_progress permission'
);

select is(
  (
    select workouts_7d
      from public.stk_list_coach_pro_clients(null,25,0)
     where client_user_id = '52000000-0000-0000-0000-000000000002'
  ),
  null::integer,
  'progress aggregate is redacted without view_progress permission'
);

select ok(
  (
    select latest_checkin_at is not null
      from public.stk_list_coach_pro_clients(null,25,0)
     where client_user_id = '52000000-0000-0000-0000-000000000001'
  ),
  'latest check-in is exposed only through granted permission'
);

select is(
  (
    select latest_checkin_at
      from public.stk_list_coach_pro_clients(null,25,0)
     where client_user_id = '52000000-0000-0000-0000-000000000002'
  ),
  null::timestamptz,
  'check-in aggregate is redacted without permission'
);

select is(
  (
    select active_task_count::integer
      from public.stk_list_coach_pro_clients(null,25,0)
     where client_user_id = '52000000-0000-0000-0000-000000000001'
  ),
  1,
  'task count is aggregated in the roster without N+1'
);

select is(
  (
    select active_task_count::integer
      from public.stk_list_coach_pro_clients(null,25,0)
     where client_user_id = '52000000-0000-0000-0000-000000000002'
  ),
  null::integer,
  'task count is not leaked without assign_tasks permission'
);

select is(
  (
    select count(*)::integer
      from public.stk_list_coach_pro_clients('alpha',25,0)
  ),
  1,
  'search filters linked clients by display name'
);

select is(
  (
    select display_name
      from public.stk_list_coach_pro_clients('alpha',25,0)
     limit 1
  ),
  'Ana Alpha',
  'search returns the expected client'
);

select is(
  (
    select count(*)::integer
      from public.stk_list_coach_pro_clients('Carlos',25,0)
  ),
  0,
  'search cannot discover unrelated users'
);

select throws_ok(
  $$select * from public.stk_list_coach_pro_clients(null,101,0)$$,
  'P0001',
  'Coach Pro page limit must be between 1 and 100',
  'server rejects oversized pages'
);

select throws_ok(
  $$select * from public.stk_list_coach_pro_clients(repeat('x',81),25,0)$$,
  'P0001',
  'Coach Pro search is too long',
  'server bounds search payload size'
);


-- Extended signature: filter and sort BEFORE the count/window and page.
select has_function('public','stk_list_coach_pro_clients',
  array['text','integer','integer','text','boolean','text'],
  'extended roster RPC exists without ambiguous defaults');
select results_eq(
  $$select * from public.stk_list_coach_pro_clients()$$,
  $$select * from public.stk_list_coach_pro_clients(null,25,0,'all',null,'review')$$,
  'legacy defaults use the same authorized query');
select is((select total_count from public.stk_list_coach_pro_clients('beta',1,0,'active',null,'name')),
  1::bigint,'search and status precede total count');
select is((select display_name from public.stk_list_coach_pro_clients(null,1,1,'active',null,'name')),
  'Bruno Beta','name sort applies globally before offset');
select is((select total_count from public.stk_list_coach_pro_clients(null,1,1,'active',null,'name')),
  2::bigint,'offset retains full filtered total');
select is((select count(*) from public.stk_list_coach_pro_clients(null,25,0,'paused',null,'name')),
  0::bigint,'paused filter does not include active relationships');
select throws_ok($$select * from public.stk_list_coach_pro_clients(null,25,0,'revoked',null,'name')$$,
  'P0001','Coach Pro relationship filter is invalid','invalid status rejected');
select throws_ok($$select * from public.stk_list_coach_pro_clients(null,25,0,'all',null,'arbitrary_sql')$$,
  'P0001','Coach Pro sort is invalid','sort is a server allowlist');
select is((select count(*) from public.stk_list_coach_pro_clients('Carlos',25,0,'all',null,'recent_workout')),
  0::bigint,'extended search cannot enumerate unrelated users');
reset role;
-- A hidden recent workout must not outrank an authorized older one.
update public.stk_client_progress_snapshots set last_workout_at=now()
  where client_user_id='52000000-0000-0000-0000-000000000002';
update public.stk_client_progress_snapshots set last_workout_at=now()-interval '8 days'
  where client_user_id='52000000-0000-0000-0000-000000000001';
set local role authenticated;
select is((select display_name from public.stk_list_coach_pro_clients(null,1,0,'all',null,'recent_workout')),
  'Ana Alpha','recent sort ignores a newer workout without permission');
select is((select display_name from public.stk_list_coach_pro_clients(null,1,0,'active',true,'name')),
  'Ana Alpha','review filter uses authorized stale progress');
select is((select total_count from public.stk_list_coach_pro_clients(null,1,0,'active',true,'name')),
  1::bigint,'review filter precedes total count');
select is((select count(*) from public.stk_list_coach_pro_clients(null,1,1,'active',true,'name')),
  0::bigint,'offset applies after review filter');
reset role;
update public.stk_client_progress_snapshots set last_workout_at=now()-interval '90 days'
  where client_user_id='52000000-0000-0000-0000-000000000002';
set local role authenticated;
select is((select count(*) from public.stk_list_coach_pro_clients(null,25,0,'all',true,'review')),
  1::bigint,'hidden stale progress cannot enter review results');
select is((select display_name from public.stk_list_coach_pro_clients(null,1,0,'all',null,'recent_workout')),
  'Ana Alpha','hidden progress changes cannot change recent sorting');
-- A real granted tie resolves consistently by name and then client UUID.
reset role;
update public.stk_coach_client_relationships set permissions='{"view_progress":true}'
  where id='53000000-0000-0000-0000-000000000002';
update public.stk_client_progress_snapshots set last_workout_at=now()-interval '8 days'
  where client_user_id='52000000-0000-0000-0000-000000000002';
update public.stk_user_profiles set display_name='Ana Alpha'
  where user_id='52000000-0000-0000-0000-000000000002';
set local role authenticated;
select is((select client_user_id from public.stk_list_coach_pro_clients(null,1,1,'all',null,'recent_workout')),
  '52000000-0000-0000-0000-000000000002'::uuid,'ties have deterministic non-overlapping pages');
reset role;
update public.stk_user_profiles set display_name='Bruno Beta'
  where user_id='52000000-0000-0000-0000-000000000002';
update public.stk_coach_client_relationships set permissions='{}'
  where id='53000000-0000-0000-0000-000000000002';
set local role authenticated;

-- Two coaches share one client: check-ins belong to their own relationship.
reset role;
insert into public.stk_subscription_entitlements(
  user_id,product,status,tier,client_limit,starts_at,current_period_end,source
) values (
  '51000000-0000-0000-0000-000000000002','coach_pro','active','test',10,
  now()-interval '1 day',now()+interval '30 days','pgTap'
);
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions)
values ('53000000-0000-0000-0000-000000000003',
  '51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001',
  'active','{"view_checkins":true}');
insert into public.stk_coach_checkins(id,relationship_id,coach_user_id,client_user_id,energy,recovery,note,created_at)
values ('54000000-0000-0000-0000-000000000002','53000000-0000-0000-0000-000000000003',
  '51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001',
  3,3,'Other relationship',now()-interval '1 hour');
set local role authenticated;
select is(
  (select latest_checkin_at from public.stk_list_coach_pro_clients('alpha',25,0)),
  now()-interval '2 hours',
  'dashboard excludes a newer check-in belonging to another coach'
);
select is(
  (select count(*)::integer from public.stk_list_coach_checkins('52000000-0000-0000-0000-000000000001')),
  1,'legacy check-in RPC also isolates coach relationships'
);
select throws_ok(
  $$select * from public.stk_list_coach_pro_clients(null,25,-1)$$,
  'P0001','Coach Pro page offset is invalid','negative page offset is rejected'
);
select set_config('request.jwt.claims',
  '{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select is(
  (select latest_checkin_at from public.stk_list_coach_pro_clients('alpha',25,0)),
  now()-interval '1 hour','second coach sees only own relationship check-in'
);
select set_config('request.jwt.claims',
  '{"sub":"52000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(
  (select count(*)::integer from public.stk_list_coach_checkins('52000000-0000-0000-0000-000000000001')),
  2,'client retains both own check-ins'
);
reset role;
update public.stk_coach_client_relationships set permissions='{"assign_tasks":true}'
  where id='53000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(
  (select active_task_count from public.stk_list_coach_pro_clients('beta',25,0)),
  0::bigint,'zero means permission granted with no active tasks'
);
reset role;
update public.stk_coach_client_relationships set status='paused'
  where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select ok(
  (select workouts_7d is null and workouts_30d is null and average_rir_7d is null
    and last_workout_at is null and latest_checkin_at is null and active_task_count is null
    and not progress_available and not needs_review
    from public.stk_list_coach_pro_clients('alpha',25,0)),
  'paused relationship hides every protected aggregate despite stored permissions'
);
select is((select count(*) from public.stk_list_coach_pro_clients(null,25,0,'paused',null,'name')),
  1::bigint,'paused filter returns paused roster metadata');
select is((select count(*) from public.stk_list_coach_pro_clients(null,25,0,'paused',true,'review')),
  0::bigint,'paused stored permissions cannot enter review filter');
reset role;
update public.stk_coach_client_relationships set status='revoked',revoked_at=now()
  where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select is(
  (select count(*)::integer from public.stk_list_coach_pro_clients('alpha',25,0)),
  0,'revoked relationship disappears from professional roster'
);
select set_config('request.jwt.claims',
  '{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":true}',true);
select throws_ok(
  $$select * from public.stk_list_coach_pro_clients(null,25,0)$$,
  'P0001','Permanent authenticated account required','anonymous session cannot use paid roster'
);

select throws_ok($$select * from public.stk_list_coach_pro_clients(null,25,0,'all',null,'name')$$,
  'P0001','Permanent authenticated account required','anonymous cannot bypass extended RPC guard');
reset role;
update public.stk_subscription_entitlements set status='expired'
  where user_id='51000000-0000-0000-0000-000000000001' and product='coach_pro';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select * from public.stk_list_coach_pro_clients(null,25,0,'all',null,'name')$$,
  'P0001','Coach Pro entitlement required','expired plan cannot bypass extended RPC guard');

select * from finish();
rollback;
