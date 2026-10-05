begin;

select plan(30);

select has_function(
  'public',
  'stk_create_coach_pro_program_revision',
  array['uuid','uuid','uuid','jsonb'],
  'Coach Pro immutable revision write RPC exists'
);

insert into auth.users (
  id,aud,role,email,encrypted_password,email_confirmed_at,
  created_at,updated_at,raw_app_meta_data,raw_user_meta_data
) values
('71000000-0000-0000-0000-000000000001','authenticated','authenticated','revision-write-coach-a@example.com','',now(),now(),now(),'{}','{}'),
('71000000-0000-0000-0000-000000000002','authenticated','authenticated','revision-write-coach-b@example.com','',now(),now(),now(),'{}','{}'),
('72000000-0000-0000-0000-000000000001','authenticated','authenticated','revision-write-client@example.com','',now(),now(),now(),'{}','{}');

insert into public.stk_user_profiles(user_id,display_name) values
('71000000-0000-0000-0000-000000000001','Revision Writer A'),
('71000000-0000-0000-0000-000000000002','Revision Writer B'),
('72000000-0000-0000-0000-000000000001','Revision Write Client');

insert into public.stk_user_capabilities(user_id,capability) values
('71000000-0000-0000-0000-000000000001','coach'),
('71000000-0000-0000-0000-000000000002','coach'),
('72000000-0000-0000-0000-000000000001','athlete');

insert into public.stk_subscription_entitlements(
  user_id,product,status,tier,client_limit,starts_at,current_period_end,source
) values
('71000000-0000-0000-0000-000000000001','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap'),
('71000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');

insert into public.stk_coach_client_relationships(
  id,coach_user_id,client_user_id,status,permissions
) values
('73000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','active','{"assign_programs":true}'::jsonb),
('73000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','active','{"assign_programs":true}'::jsonb);

create temporary table _program_revision_write_test (
  assignment_id uuid,
  baseline_id uuid,
  revision_two_id uuid
);
grant select,insert,update on _program_revision_write_test to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

insert into _program_revision_write_test(assignment_id)
select public.stk_assign_program(
  '72000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'name','Legacy Program',
    'notes','Legacy assignment note',
    'duration_weeks',8,
    'training_weekdays',jsonb_build_array(1,3,5),
    'starts_on','2026-10-06',
    'routines',jsonb_build_array(
      jsonb_build_object(
        'name','Legacy Upper',
        'notes','',
        'exercises',jsonb_build_array(
          jsonb_build_object(
            'name','Bench Press','muscle_group','Chest','equipment','Barbell',
            'target_sets',3,'target_reps_min',8,'target_reps_max',10,
            'rest_seconds',120,'warmup_sets',1,'approach_sets',0,
            'unilateral',false,'unilateral_target','other'
          )
        )
      )
    )
  )
);

reset role;

update _program_revision_write_test
set baseline_id=(
  select revision.id
  from public.stk_assigned_program_revisions revision
  where revision.assignment_id=_program_revision_write_test.assignment_id
    and revision.revision_number=1
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

update _program_revision_write_test
set revision_two_id=(
  public.stk_create_coach_pro_program_revision(
    '73000000-0000-0000-0000-000000000001',
    assignment_id,
    baseline_id,
    jsonb_build_object(
      'name','Program Revision 2',
      'notes','Second immutable proposal',
      'duration_weeks',10,
      'training_weekdays',jsonb_build_array(1,2,4,5),
      'starts_on','2026-10-13',
      'routines',jsonb_build_array(
        jsonb_build_object(
          'name','Upper Revised',
          'notes','Updated prescription',
          'exercises',jsonb_build_array(
            jsonb_build_object(
              'name','Incline Press','muscle_group','Chest','equipment','Dumbbell',
              'target_sets',4,'target_reps_min',6,'target_reps_max',9,
              'rest_seconds',150,'warmup_sets',1,'approach_sets',1,
              'unilateral',false,'unilateral_target','other'
            ),
            jsonb_build_object(
              'name','One Arm Row','muscle_group','Back','equipment','Dumbbell',
              'target_sets',3,'target_reps_min',8,'target_reps_max',12,
              'rest_seconds',90,'warmup_sets',0,'approach_sets',0,
              'unilateral',true,'unilateral_target','arm'
            )
          )
        )
      )
    )
  )->>'revision_id'
)::uuid;

reset role;

select is(
  (select count(*)::integer from public.stk_assigned_program_revisions
   where assignment_id=(select assignment_id from _program_revision_write_test)),
  2,
  'creating a proposal appends exactly one revision'
);
select is(
  (select revision_number from public.stk_assigned_program_revisions
   where id=(select revision_two_id from _program_revision_write_test)),
  2,
  'new proposal receives revision number 2'
);
select is(
  (select previous_revision_id from public.stk_assigned_program_revisions
   where id=(select revision_two_id from _program_revision_write_test)),
  (select baseline_id from _program_revision_write_test),
  'revision 2 links directly to baseline'
);
select is(
  (select source_kind from public.stk_assigned_program_revisions
   where id=(select revision_two_id from _program_revision_write_test)),
  'coach_revision',
  'new proposal is identified as coach revision'
);
select is(
  (select authored_by from public.stk_assigned_program_revisions
   where id=(select revision_two_id from _program_revision_write_test)),
  '71000000-0000-0000-0000-000000000001'::uuid,
  'coach authors the revision server-side'
);
select ok(
  (select authored_at is not null
   from public.stk_assigned_program_revisions
   where id=(select revision_two_id from _program_revision_write_test)),
  'coach revision has server-authored timestamp'
);
select is(
  (select observed_assignment_version from public.stk_assigned_program_revisions
   where id=(select revision_two_id from _program_revision_write_test)),
  1,
  'proposal records observed assignment version without changing it'
);
select is(
  (select name from public.stk_assigned_program_revisions
   where id=(select baseline_id from _program_revision_write_test)),
  'Legacy Program',
  'baseline remains unchanged after proposal'
);
select is(
  (select name from public.stk_assigned_program_revisions
   where id=(select revision_two_id from _program_revision_write_test)),
  'Program Revision 2',
  'new revision stores its own prescription metadata'
);
select is(
  (select count(*)::integer
   from public.stk_assigned_program_revision_exercises exercise
   join public.stk_assigned_program_revision_routines routine
     on routine.id=exercise.revision_routine_id
   where routine.revision_id=(select revision_two_id from _program_revision_write_test)),
  2,
  'new revision snapshots all proposed exercises'
);
select is(
  (select version from public.stk_assigned_programs
   where id=(select assignment_id from _program_revision_write_test)),
  1,
  'creating proposal does not advance legacy assignment version'
);
select is(
  (select name from public.stk_assigned_programs
   where id=(select assignment_id from _program_revision_write_test)),
  'Legacy Program',
  'creating proposal does not rewrite current assignment prescription'
);
select is(
  (select status from public.stk_assigned_programs
   where id=(select assignment_id from _program_revision_write_test)),
  'assigned',
  'creating proposal does not accept or install assignment'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select public.stk_create_coach_pro_program_revision(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    (select baseline_id from _program_revision_write_test),
    jsonb_build_object(
      'name','Fork Attempt',
      'routines',jsonb_build_array(
        jsonb_build_object(
          'name','Fork',
          'exercises',jsonb_build_array(
            jsonb_build_object(
              'name','Squat','target_sets',3,'target_reps_min',5,
              'target_reps_max',5,'rest_seconds',180
            )
          )
        )
      )
    )
  )$$,
  'P0001','Program revision changed; reload',
  'stale previous revision token cannot create a fork'
);

select throws_ok(
  $$select public.stk_create_coach_pro_program_revision(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    (select revision_two_id from _program_revision_write_test),
    '{"name":"No routines"}'::jsonb
  )$$,
  'P0001','Program routines must be an array',
  'invalid revision payload rolls back without partial revision'
);

reset role;

select is(
  (select count(*)::integer from public.stk_assigned_program_revisions
   where assignment_id=(select assignment_id from _program_revision_write_test)),
  2,
  'failed payload leaves revision history unchanged'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select public.stk_create_coach_pro_program_revision(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    null,
    '{}'::jsonb
  )$$,
  'P0001','Program revision changed; reload',
  'missing optimistic concurrency token is rejected before write'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"71000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select public.stk_create_coach_pro_program_revision(
    '73000000-0000-0000-0000-000000000002',
    (select assignment_id from _program_revision_write_test),
    (select revision_two_id from _program_revision_write_test),
    jsonb_build_object('name','Other Coach','routines','[]'::jsonb)
  )$$,
  'P0001','Assigned program revision write unavailable',
  'other coach of same client cannot revise assignment'
);

reset role;
update public.stk_coach_client_relationships
set permissions='{}'::jsonb
where id='73000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select public.stk_create_coach_pro_program_revision(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    (select revision_two_id from _program_revision_write_test),
    jsonb_build_object('name','No Consent','routines','[]'::jsonb)
  )$$,
  'P0001','Assigned program revision write unavailable',
  'permission removal blocks revision writes'
);

reset role;
update public.stk_coach_client_relationships
set status='paused',permissions='{"assign_programs":true}'::jsonb
where id='73000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select public.stk_create_coach_pro_program_revision(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    (select revision_two_id from _program_revision_write_test),
    jsonb_build_object('name','Paused','routines','[]'::jsonb)
  )$$,
  'P0001','Assigned program revision write unavailable',
  'paused relationship blocks revision writes'
);

reset role;
update public.stk_coach_client_relationships
set status='active',permissions='{"assign_programs":true}'::jsonb
where id='73000000-0000-0000-0000-000000000001';
update public.stk_subscription_entitlements
set status='expired'
where user_id='71000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select public.stk_create_coach_pro_program_revision(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    (select revision_two_id from _program_revision_write_test),
    jsonb_build_object('name','Expired','routines','[]'::jsonb)
  )$$,
  'P0001','Coach Pro entitlement required',
  'expired Coach Pro entitlement blocks revision writes'
);

reset role;
update public.stk_subscription_entitlements
set status='active'
where user_id='71000000-0000-0000-0000-000000000001';
update public.stk_assigned_programs
set status='archived'
where id=(select assignment_id from _program_revision_write_test);
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select public.stk_create_coach_pro_program_revision(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    (select revision_two_id from _program_revision_write_test),
    jsonb_build_object('name','Archived','routines','[]'::jsonb)
  )$$,
  'P0001','Assigned program revision write unavailable',
  'archived assignment cannot receive new revision'
);

reset role;
update public.stk_assigned_programs
set status='assigned'
where id=(select assignment_id from _program_revision_write_test);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"71000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":true}',
  true
);

select throws_ok(
  $$select public.stk_create_coach_pro_program_revision(
    '73000000-0000-0000-0000-000000000002',
    (select assignment_id from _program_revision_write_test),
    (select revision_two_id from _program_revision_write_test),
    '{}'::jsonb
  )$$,
  'P0001','Permanent authenticated account required',
  'anonymous session cannot create revisions'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"72000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  $$select public.stk_create_coach_pro_program_revision(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    (select revision_two_id from _program_revision_write_test),
    '{}'::jsonb
  )$$,
  'P0001','Coach capability required',
  'client cannot call Coach Pro revision write RPC'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (
    public.stk_list_coach_pro_program_revisions(
      '73000000-0000-0000-0000-000000000001',
      (select assignment_id from _program_revision_write_test),
      25,0
    )->>'total_count'
  )::integer,
  2,
  'history reader sees baseline plus proposal'
);

select is(
  public.stk_get_coach_pro_program_revision_page(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    (select baseline_id from _program_revision_write_test),
    null,25,0
  )->>'name',
  'Legacy Program',
  'baseline remains readable after proposal creation'
);

select is(
  public.stk_get_coach_pro_program_revision_page(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    (select revision_two_id from _program_revision_write_test),
    null,25,0
  )->>'name',
  'Program Revision 2',
  'new immutable proposal is independently readable'
);

select is(
  public.stk_get_coach_pro_program_revision_page(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    (select revision_two_id from _program_revision_write_test),
    null,25,0
  )->'items'->0->>'name',
  'Upper Revised',
  'new proposal owns its own routine snapshot'
);

select is(
  public.stk_get_coach_pro_program_revision_page(
    '73000000-0000-0000-0000-000000000001',
    (select assignment_id from _program_revision_write_test),
    (select revision_two_id from _program_revision_write_test),
    (
      public.stk_get_coach_pro_program_revision_page(
        '73000000-0000-0000-0000-000000000001',
        (select assignment_id from _program_revision_write_test),
        (select revision_two_id from _program_revision_write_test),
        null,25,0
      )->'items'->0->>'id'
    )::uuid,
    25,0
  )->'items'->1->>'name',
  'One Arm Row',
  'exercise page reads the proposed immutable prescription'
);

reset role;
select * from finish();
rollback;
