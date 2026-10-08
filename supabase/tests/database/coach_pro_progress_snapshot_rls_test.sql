begin;
select plan(38);
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


update public.stk_coach_client_relationships set permissions='{"view_progress":true}' where id='53000000-0000-0000-0000-000000000001';
update public.stk_client_progress_snapshots
set generated_at='2026-09-01T00:00:00Z',
    average_rir_7d=null,
    last_workout_at=null,
    trend_baseline_available=true,
    workouts_previous_7d=3,
    training_minutes_previous_7d=180,
    completed_working_sets_previous_7d=40,
    volume_previous_7d=10000
where client_user_id='52000000-0000-0000-0000-000000000001';
delete from public.stk_client_progress_snapshots where client_user_id='52000000-0000-0000-0000-000000000002';
create temp table original_progress as select * from public.stk_client_progress_snapshots;
select ok(not has_function_privilege('anon','public.stk_get_coach_pro_client_progress(uuid)','EXECUTE'),'anon execute denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is((public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->>'workouts_7d')::numeric,4::numeric,'workouts_7d preserves recorded aggregate');
select is((public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->>'workouts_30d')::numeric,15::numeric,'workouts_30d preserves recorded aggregate');
select is((public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->>'training_minutes_7d')::numeric,240::numeric,'training_minutes_7d preserves recorded aggregate');
select is((public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->>'completed_working_sets_7d')::numeric,52::numeric,'completed_working_sets_7d preserves recorded aggregate');
select is((public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->>'volume_7d')::numeric,12000::numeric,'volume_7d preserves recorded aggregate');
select ok(public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->'average_rir_7d'='null'::jsonb,'missing RIR stays null');
select ok(public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->'last_workout_at'='null'::jsonb,'missing workout timestamp stays null');
select is((public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->>'generated_at')::timestamptz,'2026-09-01T00:00:00Z'::timestamptz,'old snapshot date is not rewritten as now');
select ok(
  not (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001') ? 'recent_workouts')
  and not (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot' ? 'measurements')
  and not (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot' ? 'nutrition'),
  'progress payload excludes adjacent protected datasets'
);
select is(
  (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->>'trend_baseline_available')::boolean,
  true,
  'trend baseline availability is shared under view_progress'
);
select is(
  (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->>'workouts_previous_7d')::integer,
  3,
  'previous seven day workout count is shared'
);
select is(
  (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->>'training_minutes_previous_7d')::integer,
  180,
  'previous seven day minutes are shared'
);
select is(
  (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->>'completed_working_sets_previous_7d')::integer,
  40,
  'previous seven day working sets are shared'
);
select is(
  (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'snapshot'->>'volume_previous_7d')::numeric,
  10000::numeric,
  'previous seven day volume is shared'
);
select ok(
  public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'adherence' = 'null'::jsonb,
  'view_progress alone does not expose program adherence'
);
reset role;

insert into public.stk_assigned_programs(
  id, relationship_id, coach_user_id, client_user_id, name, notes,
  duration_weeks, training_weekdays, starts_on, status, version,
  created_at, accepted_at, updated_at
) values (
  '56000000-0000-0000-0000-000000000001',
  '53000000-0000-0000-0000-000000000001',
  '51000000-0000-0000-0000-000000000001',
  '52000000-0000-0000-0000-000000000001',
  'Plan frecuencia', '', 12, array[1,3,5]::smallint[], '2026-08-01',
  'accepted', 1, '2026-08-01T00:00:00Z', '2026-08-01T00:00:00Z',
  '2026-08-01T00:00:00Z'
);

insert into public.stk_assigned_program_revisions(
  id, assignment_id, revision_number, previous_revision_id, source_kind,
  observed_assignment_version, name, notes, duration_weeks,
  training_weekdays, starts_on, authored_by, authored_at, recorded_at
) values (
  '57000000-0000-0000-0000-000000000001',
  '56000000-0000-0000-0000-000000000001',
  2, null, 'coach_revision', 1, 'Plan frecuencia revisado', '', 12,
  array[2,4]::smallint[], '2026-08-01',
  '51000000-0000-0000-0000-000000000001',
  '2026-08-15T00:00:00Z', '2026-08-15T00:00:00Z'
);

insert into public.stk_assigned_program_revision_acceptances(
  assignment_id, revision_id, client_user_id, accepted_at
) values (
  '56000000-0000-0000-0000-000000000001',
  '57000000-0000-0000-0000-000000000001',
  '52000000-0000-0000-0000-000000000001',
  '2026-08-16T00:00:00Z'
);
update public.stk_coach_client_relationships
set permissions='{"view_progress":true,"assign_programs":true}'
where id='53000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(
  public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'adherence'->>'assignment_id',
  '56000000-0000-0000-0000-000000000001',
  'adherence uses an accepted program from this exact relationship'
);
select is(
  public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'adherence'->>'assignment_name',
  'Plan frecuencia revisado',
  'adherence reports the latest explicitly accepted immutable revision'
);
select is(
  (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'adherence'->>'scheduled_sessions_7d')::integer,
  2,
  'seven day frequency target uses accepted revision weekdays'
);
select is(
  (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'adherence'->>'scheduled_sessions_30d')::integer,
  9,
  'thirty day frequency target uses accepted revision weekdays'
);
select is(
  (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'adherence'->>'completed_sessions_7d')::integer,
  4,
  'adherence uses aggregate shared workout count without workout-detail permission'
);
select is(
  (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'adherence'->>'percent_7d')::integer,
  100,
  'frequency adherence is capped at one hundred percent'
);
select is(
  (public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'adherence'->>'percent_30d')::integer,
  100,
  'thirty day frequency adherence is capped at one hundred percent'
);
reset role;

update public.stk_coach_client_relationships
set permissions='{"view_progress":true}'
where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select ok(
  public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')->'adherence' = 'null'::jsonb,
  'revoking assign_programs immediately removes adherence while progress remains visible'
);

select throws_ok($$select public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000002')$$,'P0001','Shared progress access unavailable','unpermitted client');
select throws_ok($$select public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000009')$$,'P0001','Shared progress access unavailable','unknown relationship');
reset role;
update public.stk_coach_client_relationships set permissions='{"view_progress":true}' where id='53000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select ok(public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000002')->'snapshot'='null'::jsonb,'no shared snapshot remains null not zero-filled');
reset role;
update public.stk_coach_client_relationships set permissions='{"view_workouts":true}' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')$$,'P0001','Shared progress access unavailable','workout consent cannot replace revoked progress');
reset role;
update public.stk_coach_client_relationships set permissions='{"view_progress":true}',status='paused',revoked_at=null where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')$$,'P0001','Shared progress access unavailable','paused denied');
reset role;
update public.stk_coach_client_relationships set permissions='{"view_progress":true}',status='revoked',revoked_at=now() where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')$$,'P0001','Shared progress access unavailable','revoked denied');
reset role;
update public.stk_coach_client_relationships set status='active',revoked_at=null where id='53000000-0000-0000-0000-000000000001';
update public.stk_subscription_entitlements set status='expired';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')$$,'P0001','Coach Pro entitlement required','expired denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":true}',true);
select throws_ok($$select public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')$$,'P0001','Permanent authenticated account required','anonymous denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"52000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')$$,'P0001','Coach capability required','non-coach denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')$$,'P0001','Coach Pro entitlement required','no plan denied');
reset role;
insert into public.stk_subscription_entitlements(user_id,product,status,tier,client_limit,starts_at,current_period_end,source)
values ('51000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');
insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions)
values ('53000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000001','active','{"view_workouts":true}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select throws_ok($$select public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000001')$$,'P0001','Shared progress access unavailable','other coach cannot use first relationship');
select throws_ok($$select public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000003')$$,'P0001','Shared progress access unavailable','cannot borrow first coach consent');
reset role;
update public.stk_coach_client_relationships set permissions='{"view_progress":true}' where id='53000000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select is((public.stk_get_coach_pro_client_progress('53000000-0000-0000-0000-000000000003')->'snapshot'->>'training_minutes_7d')::int,240,'own consent permits same client aggregate');
reset role;
select results_eq($$select * from public.stk_client_progress_snapshots order by client_user_id$$,$$select * from original_progress order by client_user_id$$,'reads and consent changes preserve snapshot');
select * from finish();
rollback;
