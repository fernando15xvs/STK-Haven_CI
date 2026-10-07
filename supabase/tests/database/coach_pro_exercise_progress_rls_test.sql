begin;

select plan(27);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
)
values
('61000000-0000-0000-0000-000000000001','authenticated','authenticated','exercise-coach-a@example.com','',now(),now(),now(),'{}','{}'),
('61000000-0000-0000-0000-000000000002','authenticated','authenticated','exercise-coach-b@example.com','',now(),now(),now(),'{}','{}'),
('62000000-0000-0000-0000-000000000001','authenticated','authenticated','exercise-client-a@example.com','',now(),now(),now(),'{}','{}'),
('62000000-0000-0000-0000-000000000002','authenticated','authenticated','exercise-client-b@example.com','',now(),now(),now(),'{}','{}');

insert into public.stk_user_profiles(user_id, display_name) values
('61000000-0000-0000-0000-000000000001','Exercise Coach A'),
('61000000-0000-0000-0000-000000000002','Exercise Coach B'),
('62000000-0000-0000-0000-000000000001','Exercise Client A'),
('62000000-0000-0000-0000-000000000002','Exercise Client B');

insert into public.stk_user_capabilities(user_id, capability) values
('61000000-0000-0000-0000-000000000001','coach'),
('61000000-0000-0000-0000-000000000002','coach'),
('62000000-0000-0000-0000-000000000001','athlete'),
('62000000-0000-0000-0000-000000000002','athlete');

insert into public.stk_subscription_entitlements(
  user_id, product, status, tier, client_limit,
  starts_at, current_period_end, source
) values
(
  '61000000-0000-0000-0000-000000000001',
  'coach_pro','active','test',10,
  now() - interval '1 day', now() + interval '30 days','pgTap'
),
(
  '61000000-0000-0000-0000-000000000002',
  'coach_pro','active','test',10,
  now() - interval '1 day', now() + interval '30 days','pgTap'
);

insert into public.stk_coach_client_relationships(
  id, coach_user_id, client_user_id, status, permissions
) values
(
  '63000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  '62000000-0000-0000-0000-000000000001',
  'active',
  '{"view_progress":true,"view_workouts":true}'::jsonb
),
(
  '63000000-0000-0000-0000-000000000002',
  '61000000-0000-0000-0000-000000000002',
  '62000000-0000-0000-0000-000000000001',
  'active',
  '{"view_progress":true,"view_workouts":true}'::jsonb
),
(
  '63000000-0000-0000-0000-000000000003',
  '61000000-0000-0000-0000-000000000001',
  '62000000-0000-0000-0000-000000000002',
  'active',
  '{"view_progress":true,"view_workouts":true}'::jsonb
);

select ok(
  to_regclass('public.stk_client_exercise_progress_snapshots') is not null,
  'exercise progress snapshot table exists'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid='public.stk_client_exercise_progress_snapshots'::regclass
  ),
  'exercise progress snapshot table has RLS enabled'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.stk_client_exercise_progress_snapshots',
    'SELECT'
  ),
  'authenticated has no direct exercise progress table read'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.stk_sync_own_progress_v2(jsonb,jsonb,jsonb)',
    'EXECUTE'
  ),
  'anon cannot execute exercise progress sync'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.stk_list_coach_pro_client_exercise_progress(uuid,integer,integer)',
    'EXECUTE'
  ),
  'anon cannot execute Coach Pro exercise progress page'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"62000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $$
  select public.stk_sync_own_progress_v2(
    '{
      "workouts_7d":2,
      "workouts_30d":8,
      "training_minutes_7d":120,
      "completed_working_sets_7d":24,
      "volume_7d":9000,
      "average_rir_7d":2.5,
      "last_workout_at":"2026-10-06T12:00:00Z",
      "generated_at":"2026-10-07T12:00:00Z",
      "trend_baseline_available":true,
      "workouts_previous_7d":2,
      "training_minutes_previous_7d":100,
      "completed_working_sets_previous_7d":20,
      "volume_previous_7d":8000
    }'::jsonb,
    '[]'::jsonb,
    '[
      {
        "exercise_id":"bench",
        "exercise_name":"Press banca",
        "muscle_group":"Pecho",
        "last_performed_at":"2026-10-06T12:00:00Z",
        "generated_at":"2026-10-07T12:00:00Z",
        "sessions_30d":5,
        "working_sets_30d":20,
        "volume_30d":12000,
        "average_rir_30d":2.5,
        "sessions_previous_30d":4,
        "working_sets_previous_30d":16,
        "volume_previous_30d":10000,
        "best_estimated_1rm_30d":120,
        "best_estimated_1rm_previous_30d":115,
        "best_weight":110,
        "best_weight_at":"2026-09-30T12:00:00Z",
        "best_estimated_1rm":122,
        "best_estimated_1rm_at":"2026-10-01T12:00:00Z",
        "best_set_volume":1000,
        "best_set_volume_at":"2026-09-28T12:00:00Z"
      },
      {
        "exercise_id":"squat",
        "exercise_name":"Sentadilla",
        "muscle_group":"Piernas",
        "last_performed_at":"2026-10-05T12:00:00Z",
        "generated_at":"2026-10-07T12:00:00Z",
        "sessions_30d":4,
        "working_sets_30d":16,
        "volume_30d":15000,
        "average_rir_30d":null,
        "sessions_previous_30d":3,
        "working_sets_previous_30d":12,
        "volume_previous_30d":12000,
        "best_estimated_1rm_30d":150,
        "best_estimated_1rm_previous_30d":null,
        "best_weight":140,
        "best_weight_at":"2026-10-05T12:00:00Z",
        "best_estimated_1rm":150,
        "best_estimated_1rm_at":"2026-10-05T12:00:00Z",
        "best_set_volume":1400,
        "best_set_volume_at":"2026-10-05T12:00:00Z"
      }
    ]'::jsonb
  )
  $$,
  'client can atomically sync aggregate progress and exercise trends'
);

reset role;

select is(
  (
    select count(*)::integer
    from public.stk_client_exercise_progress_snapshots
    where client_user_id='62000000-0000-0000-0000-000000000001'
  ),
  2,
  'sync stores exactly the submitted aggregate exercise rows'
);
select is(
  (
    select volume_30d
    from public.stk_client_exercise_progress_snapshots
    where client_user_id='62000000-0000-0000-0000-000000000001'
      and exercise_id='bench'
  ),
  12000::numeric,
  'exercise aggregate volume round-trips exactly'
);
select is(
  (
    select workouts_7d
    from public.stk_client_progress_snapshots
    where client_user_id='62000000-0000-0000-0000-000000000001'
  ),
  2,
  'v2 sync preserves the existing progress snapshot contract'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (
    public.stk_list_coach_pro_client_exercise_progress(
      '63000000-0000-0000-0000-000000000001',25,0
    )->>'total_count'
  )::integer,
  2,
  'authorized coach receives exact exercise progress count'
);
select is(
  public.stk_list_coach_pro_client_exercise_progress(
    '63000000-0000-0000-0000-000000000001',1,0
  )->'items'->0->>'exercise_id',
  'bench',
  'exercise progress is ordered by latest performance'
);
select is(
  public.stk_list_coach_pro_client_exercise_progress(
    '63000000-0000-0000-0000-000000000001',1,1
  )->'items'->0->>'exercise_id',
  'squat',
  'exercise progress pagination is stable'
);
select is(
  (
    public.stk_list_coach_pro_client_exercise_progress(
      '63000000-0000-0000-0000-000000000001',25,0
    )->'items'->0->>'best_weight'
  )::numeric,
  110::numeric,
  'weight PR context is returned'
);
select is(
  (
    public.stk_list_coach_pro_client_exercise_progress(
      '63000000-0000-0000-0000-000000000001',25,0
    )->'items'->0->>'best_estimated_1rm_30d'
  )::numeric,
  120::numeric,
  'current 30-day estimated 1RM trend is returned'
);
select ok(
  not (
    public.stk_list_coach_pro_client_exercise_progress(
      '63000000-0000-0000-0000-000000000001',25,0
    )->'items'->0 ? 'notes'
  )
  and not (
    public.stk_list_coach_pro_client_exercise_progress(
      '63000000-0000-0000-0000-000000000001',25,0
    )->'items'->0 ? 'sets'
  ),
  'exercise progress page does not expose raw notes or sets'
);

reset role;
update public.stk_coach_client_relationships
set permissions='{"view_progress":true}'
where id='63000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_client_exercise_progress(
    '63000000-0000-0000-0000-000000000001',25,0
  )$$,
  'P0001',
  'Exercise progress access unavailable',
  'view_progress alone cannot expose exercise trends'
);

reset role;
update public.stk_coach_client_relationships
set permissions='{"view_workouts":true}'
where id='63000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_client_exercise_progress(
    '63000000-0000-0000-0000-000000000001',25,0
  )$$,
  'P0001',
  'Exercise progress access unavailable',
  'view_workouts alone cannot expose exercise trends'
);

reset role;
update public.stk_coach_client_relationships
set permissions='{"view_progress":true,"view_workouts":true}'
where id='63000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_client_exercise_progress(
    '63000000-0000-0000-0000-000000000001',25,0
  )$$,
  'P0001',
  'Exercise progress access unavailable',
  'coach B cannot borrow coach A relationship'
);
select is(
  (
    public.stk_list_coach_pro_client_exercise_progress(
      '63000000-0000-0000-0000-000000000002',25,0
    )->>'total_count'
  )::integer,
  2,
  'coach B can read the same client only through its own authorized relationship'
);

reset role;
update public.stk_coach_client_relationships
set status='paused'
where id='63000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_client_exercise_progress(
    '63000000-0000-0000-0000-000000000001',25,0
  )$$,
  'P0001',
  'Exercise progress access unavailable',
  'paused relationship loses exercise progress access immediately'
);

reset role;
update public.stk_coach_client_relationships
set status='revoked', revoked_at=now()
where id='63000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_client_exercise_progress(
    '63000000-0000-0000-0000-000000000002',25,0
  )$$,
  'P0001',
  'Exercise progress access unavailable',
  'revoked relationship loses exercise progress access immediately'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"62000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_client_exercise_progress(
    '63000000-0000-0000-0000-000000000003',25,0
  )$$,
  'P0001',
  'Coach capability required',
  'athlete capability cannot call Coach Pro exercise progress'
);

reset role;
set local role anon;
select set_config(
  'request.jwt.claims',
  '{"role":"anon"}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_client_exercise_progress(
    '63000000-0000-0000-0000-000000000001',25,0
  )$$,
  'P0001',
  'Permanent authenticated account required',
  'anonymous exercise progress read is rejected'
);

reset role;

select is(
  (
    select count(*)::integer
    from public.stk_client_exercise_progress_snapshots
    where client_user_id='62000000-0000-0000-0000-000000000001'
  ),
  2,
  'permission changes never delete client exercise aggregates'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='stk_client_exercise_progress_snapshots'
      and column_name in ('notes','sets','workout_notes','exercise_notes')
  ),
  'exercise progress storage has no raw notes or set columns'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.stk_sync_own_progress_v2(jsonb,jsonb,jsonb)',
    'EXECUTE'
  ),
  'authenticated clients can execute v2 sync RPC'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.stk_list_coach_pro_client_exercise_progress(uuid,integer,integer)',
    'EXECUTE'
  ),
  'authenticated role can invoke server-authorized exercise progress RPC'
);

select * from finish();
rollback;
