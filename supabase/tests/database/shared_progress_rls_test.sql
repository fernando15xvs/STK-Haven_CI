begin;

select plan(26);

select has_table(
  'public',
  'stk_client_progress_snapshots',
  'shared progress snapshot table exists'
);

select has_table(
  'public',
  'stk_client_workout_summaries',
  'shared workout summary table exists'
);

select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_client_progress_snapshots'::regclass
  ),
  'RLS is enabled on shared progress snapshots'
);

select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_client_workout_summaries'::regclass
  ),
  'RLS is enabled on shared workout summaries'
);

select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name = 'stk_client_progress_snapshots'
       and grantee = 'authenticated'
       and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ),
  'authenticated cannot mutate progress snapshots directly'
);

select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name = 'stk_client_workout_summaries'
       and grantee = 'authenticated'
       and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ),
  'authenticated cannot mutate workout summaries directly'
);

insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data
)
values
(
  'cccccccc-cccc-cccc-cccc-ccccccccccc1',
  'authenticated',
  'authenticated',
  'progress-coach@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
),
(
  'dddddddd-dddd-dddd-dddd-ddddddddddd1',
  'authenticated',
  'authenticated',
  'progress-client@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
),
(
  'cccccccc-cccc-cccc-cccc-ccccccccccc2',
  'authenticated',
  'authenticated',
  'progress-stranger@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
);

insert into public.stk_user_profiles (user_id, display_name)
values
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1', 'Progress Coach'),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'Progress Client'),
  ('cccccccc-cccc-cccc-cccc-ccccccccccc2', 'Unlinked Coach');

insert into public.stk_user_capabilities (user_id, capability)
values
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1', 'coach'),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'athlete'),
  ('cccccccc-cccc-cccc-cccc-ccccccccccc2', 'coach');

insert into public.stk_coach_client_relationships (
  id,
  coach_user_id,
  client_user_id,
  status,
  permissions
)
values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
  'cccccccc-cccc-cccc-cccc-ccccccccccc1',
  'dddddddd-dddd-dddd-dddd-ddddddddddd1',
  'active',
  '{"view_progress":true,"view_workouts":false}'::jsonb
);

set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"dddddddd-dddd-dddd-dddd-ddddddddddd1","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $$select public.stk_sync_own_progress(
      jsonb_build_object(
        'workouts_7d', 3,
        'workouts_30d', 11,
        'training_minutes_7d', 190,
        'completed_working_sets_7d', 42,
        'volume_7d', 12345.5,
        'average_rir_7d', 2.1,
        'last_workout_at', now() - interval '1 day',
        'generated_at', now()
      ),
      jsonb_build_array(
        jsonb_build_object(
          'workout_id', 'local-w1',
          'started_at', now() - interval '1 day',
          'routine_name', 'Upper A',
          'duration_seconds', 3600,
          'planned_working_sets', 15,
          'completed_working_sets', 15,
          'completion_percent', 100,
          'volume', 5100.5,
          'average_rir', 2.0
        ),
        jsonb_build_object(
          'workout_id', 'local-w2',
          'started_at', now() - interval '3 days',
          'routine_name', 'Lower A',
          'duration_seconds', 3300,
          'planned_working_sets', 14,
          'completed_working_sets', 13,
          'completion_percent', 93,
          'volume', 4700,
          'average_rir', 2.3
        )
      )
    )$$,
  'client can sync own privacy-scoped progress'
);

select is(
  (select count(*)::integer from public.stk_client_progress_snapshots),
  1,
  'client can read own progress snapshot'
);

select is(
  (select count(*)::integer from public.stk_client_workout_summaries),
  2,
  'client can read own workout summaries'
);

select is(
  (
    select (public.stk_get_client_progress(
      'dddddddd-dddd-dddd-dddd-ddddddddddd1'
    ) ->> 'workouts_visible')::boolean
  ),
  true,
  'client RPC includes own recent workouts'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-ccccccccccc1","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_client_progress_snapshots),
  1,
  'linked coach with view_progress can read aggregate snapshot'
);

select is(
  (select count(*)::integer from public.stk_client_workout_summaries),
  0,
  'view_progress alone does not expose workout summaries'
);

select is(
  (
    select (
      public.stk_get_client_progress(
        'dddddddd-dddd-dddd-dddd-ddddddddddd1'
      ) -> 'progress' ->> 'available'
    )::boolean
  ),
  true,
  'linked coach RPC receives available aggregate progress'
);

select is(
  jsonb_array_length(
    public.stk_get_client_progress(
      'dddddddd-dddd-dddd-dddd-ddddddddddd1'
    ) -> 'recent_workouts'
  ),
  0,
  'linked coach RPC omits workouts without view_workouts consent'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-ccccccccccc2","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_client_progress_snapshots),
  0,
  'unlinked coach cannot read client progress'
);

select is(
  (select count(*)::integer from public.stk_client_workout_summaries),
  0,
  'unlinked coach cannot read client workout summaries'
);

select throws_ok(
  $$select public.stk_get_client_progress(
      'dddddddd-dddd-dddd-dddd-ddddddddddd1'
    )$$,
  'P0001',
  'Progress permission required',
  'unlinked coach RPC cannot read client progress'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-ccccccccccc2","role":"authenticated","is_anonymous":true}',
  true
);

select throws_ok(
  $$select public.stk_sync_own_progress('{}'::jsonb, '[]'::jsonb)$$,
  'P0001',
  'Permanent authenticated account required',
  'anonymous session cannot sync progress'
);

select throws_ok(
  $$select public.stk_get_client_progress(
      'dddddddd-dddd-dddd-dddd-ddddddddddd1'
    )$$,
  'P0001',
  'Permanent authenticated account required',
  'anonymous session cannot read shared progress'
);

reset role;

update public.stk_coach_client_relationships
   set permissions =
     '{"view_progress":true,"view_workouts":true}'::jsonb,
       updated_at = now()
 where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1';

set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-ccccccccccc1","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_client_workout_summaries),
  2,
  'view_workouts permission exposes only linked client workout summaries'
);

select is(
  jsonb_array_length(
    public.stk_get_client_progress(
      'dddddddd-dddd-dddd-dddd-ddddddddddd1'
    ) -> 'recent_workouts'
  ),
  2,
  'RPC includes recent workouts after explicit view_workouts consent'
);

reset role;

update public.stk_coach_client_relationships
   set status = 'revoked',
       revoked_at = now(),
       updated_at = now()
 where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1';

set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-ccccccccccc1","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_client_progress_snapshots),
  0,
  'revocation immediately removes progress access'
);

select is(
  (select count(*)::integer from public.stk_client_workout_summaries),
  0,
  'revocation immediately removes workout summary access'
);

select throws_ok(
  $$select public.stk_get_client_progress(
      'dddddddd-dddd-dddd-dddd-ddddddddddd1'
    )$$,
  'P0001',
  'Progress permission required',
  'revoked coach cannot use progress RPC'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"dddddddd-dddd-dddd-dddd-ddddddddddd1","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select public.stk_sync_own_progress(
      jsonb_build_object(
        'workouts_7d', 1,
        'workouts_30d', 1,
        'training_minutes_7d', 60,
        'completed_working_sets_7d', 10,
        'volume_7d', 1000,
        'average_rir_7d', 11,
        'generated_at', now()
      ),
      '[]'::jsonb
    )$$,
  'P0001',
  'Average RIR is invalid',
  'invalid progress metrics are rejected'
);

select throws_ok(
  $$select public.stk_sync_own_progress(
      jsonb_build_object(
        'workouts_7d', 1,
        'workouts_30d', 1,
        'training_minutes_7d', 60,
        'completed_working_sets_7d', 10,
        'volume_7d', 1000,
        'generated_at', now()
      ),
      (
        select jsonb_agg(
          jsonb_build_object(
            'workout_id', 'w-' || value,
            'started_at', now() - interval '1 day',
            'routine_name', 'Routine',
            'duration_seconds', 60,
            'planned_working_sets', 1,
            'completed_working_sets', 1,
            'completion_percent', 100,
            'volume', 10
          )
        )
        from generate_series(1, 31) as value
      )
    )$$,
  'P0001',
  'At most 30 recent workouts may be synced',
  'oversized recent workout payload is rejected'
);

select * from finish();

rollback;
