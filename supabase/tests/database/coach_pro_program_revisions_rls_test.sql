begin;

select plan(30);

select has_table('public','stk_assigned_program_revisions','program revisions table exists');
select has_table('public','stk_assigned_program_revision_routines','program revision routines table exists');
select has_table('public','stk_assigned_program_revision_exercises','program revision exercises table exists');

select ok(
  (select relrowsecurity from pg_class where oid='public.stk_assigned_program_revisions'::regclass),
  'RLS enabled on program revisions'
);
select ok(
  (select relrowsecurity from pg_class where oid='public.stk_assigned_program_revision_routines'::regclass),
  'RLS enabled on program revision routines'
);
select ok(
  (select relrowsecurity from pg_class where oid='public.stk_assigned_program_revision_exercises'::regclass),
  'RLS enabled on program revision exercises'
);
select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public'
      and table_name in (
        'stk_assigned_program_revisions',
        'stk_assigned_program_revision_routines',
        'stk_assigned_program_revision_exercises'
      )
      and grantee='authenticated'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
  ),
  'authenticated has no direct revision-table privileges'
);

insert into auth.users (
  id,aud,role,email,encrypted_password,email_confirmed_at,
  created_at,updated_at,raw_app_meta_data,raw_user_meta_data
) values
('61000000-0000-0000-0000-000000000001','authenticated','authenticated','revision-coach-a@example.com','',now(),now(),now(),'{}','{}'),
('61000000-0000-0000-0000-000000000002','authenticated','authenticated','revision-coach-b@example.com','',now(),now(),now(),'{}','{}'),
('62000000-0000-0000-0000-000000000001','authenticated','authenticated','revision-client@example.com','',now(),now(),now(),'{}','{}');

insert into public.stk_user_profiles(user_id,display_name) values
('61000000-0000-0000-0000-000000000001','Revision Coach A'),
('61000000-0000-0000-0000-000000000002','Revision Coach B'),
('62000000-0000-0000-0000-000000000001','Revision Client');

insert into public.stk_user_capabilities(user_id,capability) values
('61000000-0000-0000-0000-000000000001','coach'),
('61000000-0000-0000-0000-000000000002','coach'),
('62000000-0000-0000-0000-000000000001','athlete');

insert into public.stk_subscription_entitlements(
  user_id,product,status,tier,client_limit,starts_at,current_period_end,source
) values
('61000000-0000-0000-0000-000000000001','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap'),
('61000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');

insert into public.stk_coach_client_relationships(
  id,coach_user_id,client_user_id,status,permissions
) values
('63000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000001','active','{"assign_programs":true}'::jsonb),
('63000000-0000-0000-0000-000000000002','61000000-0000-0000-0000-000000000002','62000000-0000-0000-0000-000000000001','active','{"assign_programs":true}'::jsonb);

create temporary table _program_revision_test(
  assignment_id uuid, revision_id uuid, revision_routine_id uuid
);
grant select,insert,update on _program_revision_test to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

insert into _program_revision_test(assignment_id)
select public.stk_assign_program(
  '62000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'name','Upper Lower Revision Baseline',
    'notes','Private prescription note retained only in snapshot storage.',
    'duration_weeks',8,
    'training_weekdays',jsonb_build_array(1,2,4,5),
    'starts_on','2026-10-06',
    'routines',jsonb_build_array(
      jsonb_build_object(
        'name','Upper A',
        'notes','Routine note',
        'exercises',jsonb_build_array(
          jsonb_build_object(
            'name','Bench Press','muscle_group','Chest','equipment','Barbell',
            'target_sets',4,'target_reps_min',6,'target_reps_max',8,
            'rest_seconds',180,'warmup_sets',2,'approach_sets',1,
            'unilateral',false,'unilateral_target','other'
          )
        )
      ),
      jsonb_build_object(
        'name','Lower A','notes','',
        'exercises',jsonb_build_array(
          jsonb_build_object(
            'name','Bulgarian Split Squat','muscle_group','Quads','equipment','Dumbbell',
            'target_sets',3,'target_reps_min',8,'target_reps_max',10,
            'rest_seconds',120,'warmup_sets',0,'approach_sets',0,
            'unilateral',true,'unilateral_target','leg'
          )
        )
      )
    )
  )
);

reset role;

update _program_revision_test
set revision_id=(
  select revision.id
  from public.stk_assigned_program_revisions as revision
  where revision.assignment_id=_program_revision_test.assignment_id
  limit 1
);
update _program_revision_test
set revision_routine_id=(
  select routine.id
  from public.stk_assigned_program_revision_routines as routine
  where routine.revision_id=_program_revision_test.revision_id
  order by routine.position
  limit 1
);

select is(
  (select count(*)::integer from public.stk_assigned_program_revisions
   where assignment_id=(select assignment_id from _program_revision_test)),
  1,
  'new assignment captures exactly one immutable baseline'
);
select is(
  (select source_kind from public.stk_assigned_program_revisions
   where id=(select revision_id from _program_revision_test)),
  'legacy_baseline',
  'baseline is explicitly identified as observed legacy state'
);
select is(
  (select observed_assignment_version from public.stk_assigned_program_revisions
   where id=(select revision_id from _program_revision_test)),
  1,
  'baseline preserves observed assignment version'
);
select ok(
  (select authored_by is null and authored_at is null
   from public.stk_assigned_program_revisions
   where id=(select revision_id from _program_revision_test)),
  'baseline does not invent historical author or authored timestamp'
);
select is(
  (select count(*)::integer from public.stk_assigned_program_revision_routines
   where revision_id=(select revision_id from _program_revision_test)),
  2,
  'baseline snapshots all normalized routines'
);
select is(
  (select count(*)::integer
   from public.stk_assigned_program_revision_exercises as exercise
   join public.stk_assigned_program_revision_routines as routine
     on routine.id=exercise.revision_routine_id
   where routine.revision_id=(select revision_id from _program_revision_test)),
  2,
  'baseline snapshots all normalized exercise prescriptions'
);
select is(
  (select exercise.unilateral_target
   from public.stk_assigned_program_revision_exercises as exercise
   join public.stk_assigned_program_revision_routines as routine
     on routine.id=exercise.revision_routine_id
   where routine.revision_id=(select revision_id from _program_revision_test)
     and exercise.exercise_name='Bulgarian Split Squat'),
  'leg',
  'baseline preserves prescription semantics'
);

select throws_ok(
  $$update public.stk_assigned_program_revisions
    set name='Mutated'
    where id=(select revision_id from _program_revision_test)$$,
  'P0001','Program revisions are immutable',
  'revision rows reject updates even for privileged callers'
);
select throws_ok(
  $$update public.stk_assigned_program_revision_routines
    set name='Mutated'
    where id=(select revision_routine_id from _program_revision_test)$$,
  'P0001','Program revisions are immutable',
  'revision routine rows reject updates'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (public.stk_list_coach_pro_program_revisions(
    '63000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_test),25,0
  )->>'total_count')::integer,
  1,
  'authorized Coach Pro roster exposes one revision'
);
select is(
  public.stk_list_coach_pro_program_revisions(
    '63000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_test),25,0
  )->'items'->0->>'source_kind',
  'legacy_baseline',
  'history identifies legacy baseline explicitly'
);
select ok(
  not (
    public.stk_list_coach_pro_program_revisions(
      '63000000-0000-0000-0000-000000000001',
      (select assignment_id from _program_revision_test),25,0
    )->'items'->0 ? 'notes'
  ),
  'revision list does not leak prescription notes'
);
select is(
  (public.stk_get_coach_pro_program_revision_page(
    '63000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_test),
    (select revision_id from _program_revision_test),
    null,25,0
  )->>'total_count')::integer,
  2,
  'revision detail paginates routine snapshots'
);
select is(
  public.stk_get_coach_pro_program_revision_page(
    '63000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_test),
    (select revision_id from _program_revision_test),
    (select revision_routine_id from _program_revision_test),
    25,0
  )->'items'->0->>'name',
  'Bench Press',
  'revision detail reads exercise prescription from selected snapshot routine'
);
select ok(
  not (
    public.stk_get_coach_pro_program_revision_page(
      '63000000-0000-0000-0000-000000000001',
      (select assignment_id from _program_revision_test),
      (select revision_id from _program_revision_test),
      null,25,0
    ) ? 'notes'
  ),
  'revision detail omits private program notes'
);

select throws_ok(
  $$select public.stk_list_coach_pro_program_revisions(
    '63000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_test),0,0
  )$$,
  'P0001','Coach Pro page limit must be between 1 and 100',
  'revision history enforces page bounds'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_program_revisions(
    '63000000-0000-0000-0000-000000000002',
    (select assignment_id from _program_revision_test),25,0
  )$$,
  'P0001','Assigned program revision access unavailable',
  'other coach of same client cannot read assignment revision history'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_program_revisions(
    '63000000-0000-0000-0000-000000000002',
    (select assignment_id from _program_revision_test),25,0
  )$$,
  'P0001','Assigned program revision access unavailable',
  'wrong relationship id cannot be mixed with assignment'
);

reset role;
update public.stk_coach_client_relationships
set permissions='{}'::jsonb
where id='63000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_get_coach_pro_program_revision_page(
    '63000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_test),
    (select revision_id from _program_revision_test),null,25,0
  )$$,
  'P0001','Assigned program revision access unavailable',
  'permission removal immediately hides revision detail'
);

reset role;
update public.stk_coach_client_relationships
set status='paused',permissions='{"assign_programs":true}'::jsonb
where id='63000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_program_revisions(
    '63000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_test),25,0
  )$$,
  'P0001','Assigned program revision access unavailable',
  'paused relationship blocks revision history'
);

reset role;
update public.stk_coach_client_relationships
set status='active',permissions='{"assign_programs":true}'::jsonb
where id='63000000-0000-0000-0000-000000000001';
update public.stk_subscription_entitlements
set status='expired'
where user_id='61000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_program_revisions(
    '63000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_test),25,0
  )$$,
  'P0001','Coach Pro entitlement required',
  'expired Coach Pro entitlement blocks revision history'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"61000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":true}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_program_revisions(
    '63000000-0000-0000-0000-000000000002',
    (select assignment_id from _program_revision_test),25,0
  )$$,
  'P0001','Permanent authenticated account required',
  'anonymous session cannot read revision history'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"62000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select public.stk_list_coach_pro_program_revisions(
    '63000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_test),25,0
  )$$,
  'P0001','Coach capability required',
  'non-coach cannot use Coach Pro revision history RPC'
);

reset role;
select * from finish();
rollback;
