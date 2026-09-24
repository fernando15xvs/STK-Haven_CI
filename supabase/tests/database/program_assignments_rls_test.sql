begin;

select plan(22);

select has_table(
  'public',
  'stk_assigned_programs',
  'assigned program table exists'
);

select has_table(
  'public',
  'stk_assigned_program_routines',
  'assigned routine table exists'
);

select has_table(
  'public',
  'stk_assigned_program_exercises',
  'assigned exercise table exists'
);

select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_assigned_programs'::regclass
  ),
  'RLS is enabled on assigned programs'
);

select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name in (
         'stk_assigned_programs',
         'stk_assigned_program_routines',
         'stk_assigned_program_exercises'
       )
       and grantee = 'authenticated'
       and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ),
  'authenticated cannot mutate assignment tables directly'
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
  'coach-program@example.com',
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
  'client-program@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
),
(
  'dddddddd-dddd-dddd-dddd-ddddddddddd2',
  'authenticated',
  'authenticated',
  'other-client@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
);

insert into public.stk_user_profiles (user_id, display_name)
values
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1', 'Program Coach'),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'Program Client'),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd2', 'Other Client');

insert into public.stk_user_capabilities (user_id, capability)
values
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1', 'coach'),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'athlete'),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd2', 'athlete');

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
  '{"assign_programs":true,"view_progress":true}'::jsonb
);

create temporary table _stk_program_assignment_test (
  assignment_id uuid
);
grant select, insert, update on table _stk_program_assignment_test
  to authenticated;

set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-ccccccccccc1","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $test$
    insert into _stk_program_assignment_test (assignment_id)
    select public.stk_assign_program(
      'dddddddd-dddd-dddd-dddd-ddddddddddd1'::uuid,
      '{
        "name":"Upper Lower",
        "notes":"Programa asignado",
        "duration_weeks":8,
        "training_weekdays":[1,2,4,5,6],
        "starts_on":"2026-09-28",
        "routines":[
          {
            "name":"Upper A",
            "notes":"",
            "exercises":[
              {
                "name":"Press banca",
                "muscle_group":"Pecho",
                "equipment":"Barra",
                "target_sets":3,
                "target_reps_min":6,
                "target_reps_max":8,
                "rest_seconds":180,
                "warmup_sets":2,
                "approach_sets":0,
                "unilateral":false,
                "unilateral_target":"other"
              }
            ]
          },
          {
            "name":"Lower A",
            "notes":"",
            "exercises":[
              {
                "name":"Sentadilla",
                "muscle_group":"Piernas",
                "equipment":"Barra",
                "target_sets":4,
                "target_reps_min":5,
                "target_reps_max":8,
                "rest_seconds":180,
                "warmup_sets":2,
                "approach_sets":1,
                "unilateral":false,
                "unilateral_target":"leg"
              }
            ]
          }
        ]
      }'::jsonb
    )
  $test$,
  'coach with explicit permission can assign normalized program'
);

select is(
  (select count(*)::integer from public.stk_assigned_programs),
  1,
  'coach sees assigned parent row'
);

select is(
  (select count(*)::integer from public.stk_assigned_program_routines),
  2,
  'coach sees two normalized routines'
);

select is(
  (select count(*)::integer from public.stk_assigned_program_exercises),
  2,
  'coach sees normalized exercise prescriptions'
);

select is(
  (
    select pg_catalog.jsonb_array_length(
      public.stk_get_assigned_program(
        (select assignment_id from _stk_program_assignment_test limit 1)
      ) -> 'routines'
    )
  ),
  2,
  'authorized coach can reconstruct assignment transport document'
);

select is(
  (
    select count(*)::integer
      from public.stk_list_my_assigned_programs()
  ),
  1,
  'coach assignment list contains linked assignment'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"dddddddd-dddd-dddd-dddd-ddddddddddd2","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_assigned_programs),
  0,
  'unrelated user cannot read assigned parent row'
);

select is(
  (select count(*)::integer from public.stk_assigned_program_routines),
  0,
  'unrelated user cannot read assigned routine rows'
);

select is(
  (select count(*)::integer from public.stk_assigned_program_exercises),
  0,
  'unrelated user cannot read assigned exercise rows'
);

select is(
  (
    select count(*)::integer
      from public.stk_list_my_assigned_programs()
  ),
  0,
  'unrelated user list RPC returns no assignments'
);

select throws_ok(
  $test$
    select public.stk_get_assigned_program(
      (select assignment_id from _stk_program_assignment_test limit 1)
    )
  $test$,
  'P0001',
  'Assigned program not found',
  'unrelated user cannot reconstruct assignment'
);

reset role;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"dddddddd-dddd-dddd-dddd-ddddddddddd1","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (
    select count(*)::integer
      from public.stk_list_my_assigned_programs()
  ),
  1,
  'client receives assigned program in own list'
);

select is(
  (
    public.stk_get_assigned_program(
      (select assignment_id from _stk_program_assignment_test limit 1)
    ) ->> 'name'
  ),
  'Upper Lower',
  'client can preview assigned program details'
);

select lives_ok(
  $test$
    select public.stk_accept_assigned_program(
      (select assignment_id from _stk_program_assignment_test limit 1)
    )
  $test$,
  'client can explicitly accept assigned program'
);

select is(
  (
    select status
      from public.stk_list_my_assigned_programs()
     limit 1
  ),
  'accepted',
  'accepted status is visible to client'
);

select lives_ok(
  $test$
    select public.stk_archive_assigned_program(
      (select assignment_id from _stk_program_assignment_test limit 1)
    )
  $test$,
  'client can archive assignment without deleting history'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"dddddddd-dddd-dddd-dddd-ddddddddddd2","role":"authenticated","is_anonymous":true}',
  true
);

select throws_ok(
  $$select public.stk_list_my_assigned_programs()$$,
  'P0001',
  'Permanent authenticated account required',
  'anonymous session cannot list assignments'
);

select * from finish();

rollback;
