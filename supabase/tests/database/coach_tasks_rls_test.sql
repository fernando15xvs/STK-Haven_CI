begin;

select plan(37);

-- 1
select has_table(
  'public',
  'stk_coach_tasks',
  'coach task table exists'
);

-- 2
select has_table(
  'public',
  'stk_coach_task_occurrences',
  'coach task occurrence table exists'
);

-- 3
select has_table(
  'public',
  'stk_coach_task_comments',
  'coach task comments table exists'
);

-- 4
select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_coach_tasks'::regclass
  ),
  'RLS is enabled on coach tasks'
);

-- 5
select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_coach_task_occurrences'::regclass
  ),
  'RLS is enabled on task occurrences'
);

-- 6
select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_coach_task_comments'::regclass
  ),
  'RLS is enabled on task comments'
);

-- 7
select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name = 'stk_coach_tasks'
       and grantee = 'authenticated'
       and privilege_type = 'INSERT'
  ),
  'authenticated cannot insert coach tasks directly'
);

-- 8
select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name = 'stk_coach_task_occurrences'
       and grantee = 'authenticated'
       and privilege_type = 'UPDATE'
  ),
  'authenticated cannot rewrite task outcomes directly'
);

-- 9
select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name = 'stk_coach_task_comments'
       and grantee = 'authenticated'
       and privilege_type = 'INSERT'
  ),
  'authenticated cannot bypass append-only comment RPC'
);

-- 10
select ok(
  public.stk_valid_coach_permissions(
    '{"assign_tasks":true,"comment":true}'::jsonb
  ),
  'assign_tasks is a supported explicit permission'
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
  'a1000000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'task-coach@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
),
(
  'b1000000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'task-client@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
),
(
  'a1000000-0000-0000-0000-000000000002',
  'authenticated',
  'authenticated',
  'task-stranger@example.com',
  '',
  now(),
  now(),
  now(),
  '{}'::jsonb,
  '{}'::jsonb
);

insert into public.stk_user_profiles (user_id, display_name)
values
  ('a1000000-0000-0000-0000-000000000001', 'Task Coach'),
  ('b1000000-0000-0000-0000-000000000001', 'Task Client'),
  ('a1000000-0000-0000-0000-000000000002', 'Task Stranger');

insert into public.stk_user_capabilities (user_id, capability)
values
  ('a1000000-0000-0000-0000-000000000001', 'coach'),
  ('b1000000-0000-0000-0000-000000000001', 'athlete'),
  ('a1000000-0000-0000-0000-000000000002', 'coach');

insert into public.stk_coach_client_relationships (
  id,
  coach_user_id,
  client_user_id,
  status,
  permissions
)
values (
  'c1000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'b1000000-0000-0000-0000-000000000001',
  'active',
  '{"assign_tasks":true,"comment":true}'::jsonb
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

-- 11
select lives_ok(
  $$select public.stk_assign_coach_task(
      'b1000000-0000-0000-0000-000000000001',
      jsonb_build_object(
        'title', 'Movilidad 10 min',
        'category', 'Movilidad',
        'task_type', 'checklist',
        'target_minutes', 10,
        'recurrence_type', 'once',
        'weekdays', '[]'::jsonb,
        'starts_on', current_date,
        'due_at', now(),
        'coach_instructions', 'Movilidad suave'
      )
    )$$,
  'authorized coach can assign task'
);

-- 12
select is(
  (select count(*)::integer from public.stk_coach_tasks),
  1,
  'authorized coach can read assigned task'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a1000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);

-- 13
select is(
  (select count(*)::integer from public.stk_coach_tasks),
  0,
  'unlinked coach cannot read client tasks'
);

-- 14
select throws_ok(
  $$select public.stk_assign_coach_task(
      'b1000000-0000-0000-0000-000000000001',
      '{"title":"Forbidden","recurrence_type":"once","weekdays":[]}'::jsonb
    )$$,
  'P0001',
  'Task assignment permission required',
  'unlinked coach cannot assign task'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

-- 15
select is(
  (select count(*)::integer from public.stk_coach_tasks),
  1,
  'client can read own assigned task'
);

-- 16
select lives_ok(
  $$select public.stk_set_coach_task_status(
      (select id from public.stk_coach_tasks limit 1),
      current_date,
      'completed',
      10
    )$$,
  'client can complete a due task'
);

-- 17
select throws_ok(
  $$select public.stk_set_coach_task_status(
      (select id from public.stk_coach_tasks limit 1),
      current_date,
      'skipped',
      0
    )$$,
  'P0001',
  'Task occurrence already has a final status',
  'final task outcome cannot be rewritten'
);

-- 18
select is(
  (
    public.stk_get_task_adherence(
      'b1000000-0000-0000-0000-000000000001',
      30
    ) ->> 'due_count'
  )::integer,
  1,
  'adherence counts due task'
);

-- 19
select is(
  (
    public.stk_get_task_adherence(
      'b1000000-0000-0000-0000-000000000001',
      30
    ) ->> 'completed_count'
  )::integer,
  1,
  'adherence counts completed task'
);

-- 20
select lives_ok(
  $$select public.stk_add_coach_task_comment(
      (select id from public.stk_coach_tasks limit 1),
      current_date,
      'Listo'
    )$$,
  'client can append comment'
);

-- 21
select is(
  (select count(*)::integer from public.stk_coach_task_comments),
  1,
  'client can read own task comments'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

-- 22
select is(
  (select count(*)::integer from public.stk_coach_task_comments),
  1,
  'coach with comment consent can read client comment'
);

-- 23
select lives_ok(
  $$select public.stk_add_coach_task_comment(
      (select id from public.stk_coach_tasks limit 1),
      current_date,
      'Buen trabajo'
    )$$,
  'coach with comment consent can append comment'
);

-- 24
select is(
  (select count(*)::integer from public.stk_coach_task_comments),
  2,
  'task comment history is append-only'
);

reset role;

update public.stk_coach_client_relationships
   set permissions = '{"assign_tasks":true,"comment":false}'::jsonb,
       updated_at = now()
 where id = 'c1000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

-- 25
select throws_ok(
  $$select public.stk_add_coach_task_comment(
      (select id from public.stk_coach_tasks limit 1),
      current_date,
      'Should fail'
    )$$,
  'P0001',
  'Comment permission required',
  'coach cannot comment after comment consent is removed'
);

-- 26
select is(
  (select count(*)::integer from public.stk_coach_tasks),
  1,
  'assign_tasks remains independent from comment permission'
);

-- 27
select lives_ok(
  $$select public.stk_assign_coach_task(
      'b1000000-0000-0000-0000-000000000001',
      jsonb_build_object(
        'title', 'Caminata',
        'category', 'Actividad',
        'task_type', 'checklist',
        'target_minutes', 20,
        'recurrence_type', 'daily',
        'weekdays', '[]'::jsonb,
        'starts_on', current_date,
        'coach_instructions', 'Ritmo cómodo'
      )
    )$$,
  'coach can assign recurring daily task'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

-- 28
select lives_ok(
  $$select public.stk_set_coach_task_status(
      (
        select id
        from public.stk_coach_tasks
        where title = 'Caminata'
      ),
      current_date,
      'skipped',
      0
    )$$,
  'client can explicitly skip recurring task occurrence'
);

-- 29
select is(
  (
    public.stk_get_task_adherence(
      'b1000000-0000-0000-0000-000000000001',
      30
    ) ->> 'skipped_count'
  )::integer,
  1,
  'adherence separates skipped from completed'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

-- 30
select lives_ok(
  $$select public.stk_archive_coach_task(
      (
        select id
        from public.stk_coach_tasks
        where title = 'Caminata'
      )
    )$$,
  'coach can archive assigned task'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

-- 31
select is(
  (
    public.stk_get_task_adherence(
      'b1000000-0000-0000-0000-000000000001',
      30
    ) ->> 'due_count'
  )::integer,
  2,
  'archiving preserves historical due occurrences in adherence'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

-- 32
select throws_ok(
  $$select public.stk_assign_coach_task(
      'b1000000-0000-0000-0000-000000000001',
      jsonb_build_object(
        'title', 'Weekly invalid',
        'task_type', 'checklist',
        'recurrence_type', 'weekly',
        'weekdays', '[]'::jsonb,
        'starts_on', current_date
      )
    )$$,
  'P0001',
  'Weekly task requires at least one weekday',
  'weekly task without weekdays is rejected'
);

reset role;

update public.stk_coach_client_relationships
   set status = 'revoked',
       revoked_at = now(),
       updated_at = now()
 where id = 'c1000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

-- 33
select is(
  (select count(*)::integer from public.stk_coach_tasks),
  0,
  'revoked coach immediately loses task read access'
);

-- 34
select throws_ok(
  $$select public.stk_get_task_adherence(
      'b1000000-0000-0000-0000-000000000001',
      30
    )$$,
  'P0001',
  'Task assignment permission required',
  'revoked coach cannot read adherence'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

-- 35
select is(
  (select count(*)::integer from public.stk_coach_tasks),
  2,
  'client retains assigned-task history after revocation'
);

-- 36
select throws_ok(
  $$select public.stk_set_coach_task_status(
      (
        select id
        from public.stk_coach_tasks
        where title = 'Movilidad 10 min'
      ),
      current_date + 1,
      'completed',
      10
    )$$,
  'P0001',
  'Task is not due on that date',
  'client cannot fabricate an outcome on a non-due date'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":true}',
  true
);

-- 37
select throws_ok(
  $$select public.stk_get_task_adherence(
      'b1000000-0000-0000-0000-000000000001',
      30
    )$$,
  'P0001',
  'Permanent authenticated account required',
  'anonymous session cannot read collaborative task adherence'
);

select * from finish();

rollback;
