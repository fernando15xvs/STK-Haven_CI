begin;

select plan(39);

select has_table(
  'public',
  'stk_assigned_program_revision_acceptances',
  'revision acceptance table exists'
);

select has_function(
  'public',
  'stk_get_my_program_revision_state',
  array['uuid'],
  'client revision state RPC exists'
);

select has_function(
  'public',
  'stk_get_my_program_revision_page',
  array['uuid','uuid','uuid','integer','integer'],
  'client revision page RPC exists'
);

select has_function(
  'public',
  'stk_accept_program_revision',
  array['uuid','uuid'],
  'explicit revision acceptance RPC exists'
);

select ok(
  (
    select relrowsecurity
      from pg_class
     where oid = 'public.stk_assigned_program_revision_acceptances'::regclass
  ),
  'RLS is enabled on revision acceptances'
);

select ok(
  not exists(
    select 1
      from information_schema.role_table_grants
     where table_schema = 'public'
       and table_name = 'stk_assigned_program_revision_acceptances'
       and grantee in ('anon','authenticated')
  ),
  'clients cannot access acceptance rows directly'
);

insert into auth.users (
  id,aud,role,email,encrypted_password,email_confirmed_at,
  created_at,updated_at,raw_app_meta_data,raw_user_meta_data
) values
('81000000-0000-0000-0000-000000000001','authenticated','authenticated','revision-accept-coach@example.com','',now(),now(),now(),'{}','{}'),
('82000000-0000-0000-0000-000000000001','authenticated','authenticated','revision-accept-client@example.com','',now(),now(),now(),'{}','{}'),
('82000000-0000-0000-0000-000000000002','authenticated','authenticated','revision-accept-other@example.com','',now(),now(),now(),'{}','{}');

insert into public.stk_user_profiles(user_id,display_name) values
('81000000-0000-0000-0000-000000000001','Revision Accept Coach'),
('82000000-0000-0000-0000-000000000001','Revision Accept Client'),
('82000000-0000-0000-0000-000000000002','Revision Accept Other');

insert into public.stk_user_capabilities(user_id,capability) values
('81000000-0000-0000-0000-000000000001','coach'),
('82000000-0000-0000-0000-000000000001','athlete'),
('82000000-0000-0000-0000-000000000002','athlete');

insert into public.stk_subscription_entitlements(
  user_id,product,status,tier,client_limit,starts_at,current_period_end,source
) values (
  '81000000-0000-0000-0000-000000000001',
  'coach_pro','active','test',10,
  now()-interval '1 day',now()+interval '30 days','pgTap'
);

insert into public.stk_coach_client_relationships(
  id,coach_user_id,client_user_id,status,permissions
) values (
  '83000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  'active',
  '{"assign_programs":true}'::jsonb
);

create temporary table _revision_acceptance_test (
  assignment_id uuid,
  baseline_id uuid,
  revision_two_id uuid,
  revision_three_id uuid,
  revision_four_id uuid
);
grant select,insert,update on _revision_acceptance_test to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

insert into _revision_acceptance_test(assignment_id)
select public.stk_assign_program(
  '82000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'name','Original Plan',
    'notes','Base prescription',
    'duration_weeks',8,
    'training_weekdays',jsonb_build_array(1,3,5),
    'starts_on','2026-10-06',
    'routines',jsonb_build_array(
      jsonb_build_object(
        'name','Base Upper',
        'notes','',
        'exercises',jsonb_build_array(
          jsonb_build_object(
            'name','Base Row',
            'muscle_group','Back',
            'equipment','Dumbbell',
            'target_sets',3,
            'target_reps_min',8,
            'target_reps_max',12,
            'rest_seconds',120,
            'warmup_sets',1,
            'approach_sets',1,
            'warmup_rest_seconds',40,
            'approach_rest_seconds',70,
            'unilateral',true,
            'unilateral_target','arm',
            'preparation_unilateral',false,
            'unilateral_side_rest_seconds',15,
            'preferred_unilateral_start_side','left'
          )
        )
      )
    )
  )
);

reset role;

update _revision_acceptance_test
set baseline_id = (
  select revision.id
    from public.stk_assigned_program_revisions as revision
   where revision.assignment_id = _revision_acceptance_test.assignment_id
     and revision.revision_number = 1
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $test$
    select public.stk_accept_assigned_program(
      (select assignment_id from _revision_acceptance_test)
    )
  $test$,
  'initial assignment acceptance records baseline consent'
);

reset role;

select is(
  (
    select count(*)::integer
      from public.stk_assigned_program_revision_acceptances
     where assignment_id=(select assignment_id from _revision_acceptance_test)
  ),
  1,
  'initial acceptance creates one baseline acceptance event'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (
    public.stk_get_my_program_revision_state(
      (select assignment_id from _revision_acceptance_test)
    )->>'accepted_revision_number'
  )::integer,
  1,
  'client state exposes accepted baseline revision'
);

select is(
  (
    public.stk_get_my_program_revision_state(
      (select assignment_id from _revision_acceptance_test)
    )->>'has_pending_revision'
  )::boolean,
  false,
  'baseline alone is not a pending coach revision'
);

select is(
  (
    select status
      from public.stk_assigned_programs
     where id=(select assignment_id from _revision_acceptance_test)
  ),
  'accepted',
  'legacy assignment status remains accepted'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

update _revision_acceptance_test
set revision_two_id = (
  public.stk_create_coach_pro_program_revision(
    '83000000-0000-0000-0000-000000000001',
    assignment_id,
    baseline_id,
    jsonb_build_object(
      'name','Revision 2',
      'notes','First proposal',
      'duration_weeks',9,
      'training_weekdays',jsonb_build_array(1,3,5),
      'starts_on','2026-10-13',
      'routines',jsonb_build_array(
        jsonb_build_object(
          'name','Upper R2',
          'notes','',
          'exercises',jsonb_build_array(
            jsonb_build_object(
              'name','Row R2',
              'muscle_group','Back',
              'equipment','Dumbbell',
              'target_sets',3,
              'target_reps_min',8,
              'target_reps_max',10,
              'rest_seconds',130,
              'warmup_sets',1,
              'approach_sets',1,
              'warmup_rest_seconds',45,
              'approach_rest_seconds',75,
              'unilateral',true,
              'unilateral_target','arm',
              'preparation_unilateral',false,
              'unilateral_side_rest_seconds',10,
              'preferred_unilateral_start_side','left'
            )
          )
        )
      )
    )
  )->>'revision_id'
)::uuid;

update _revision_acceptance_test
set revision_three_id = (
  public.stk_create_coach_pro_program_revision(
    '83000000-0000-0000-0000-000000000001',
    assignment_id,
    revision_two_id,
    jsonb_build_object(
      'name','Revision 3',
      'notes','Current proposal',
      'duration_weeks',10,
      'training_weekdays',jsonb_build_array(1,2,4,5),
      'starts_on','2026-10-20',
      'routines',jsonb_build_array(
        jsonb_build_object(
          'name','Upper R3',
          'notes','Install routine note',
          'exercises',jsonb_build_array(
            jsonb_build_object(
              'name','Row R3',
              'muscle_group','Back',
              'equipment','Cable',
              'target_sets',4,
              'target_reps_min',6,
              'target_reps_max',9,
              'rest_seconds',150,
              'warmup_sets',2,
              'approach_sets',1,
              'warmup_rest_seconds',50,
              'approach_rest_seconds',80,
              'unilateral',true,
              'unilateral_target','back',
              'preparation_unilateral',false,
              'unilateral_side_rest_seconds',0,
              'preferred_unilateral_start_side','right'
            )
          )
        )
      )
    )
  )->>'revision_id'
)::uuid;

reset role;

select is(
  (
    select count(*)::integer
      from public.stk_assigned_program_revisions
     where assignment_id=(select assignment_id from _revision_acceptance_test)
  ),
  3,
  'coach proposals append revisions 2 and 3'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (
    public.stk_get_my_program_revision_state(
      (select assignment_id from _revision_acceptance_test)
    )->>'latest_revision_number'
  )::integer,
  3,
  'client state exposes only the current latest proposal'
);

select is(
  (
    public.stk_get_my_program_revision_state(
      (select assignment_id from _revision_acceptance_test)
    )->>'has_pending_revision'
  )::boolean,
  true,
  'latest coach revision is pending before consent'
);

select is(
  (
    public.stk_get_my_program_revision_state(
      (select assignment_id from _revision_acceptance_test)
    )->>'can_accept_latest'
  )::boolean,
  true,
  'client can explicitly accept current latest revision'
);

select throws_ok(
  format(
    'select public.stk_accept_program_revision(%L::uuid,%L::uuid)',
    (select assignment_id from _revision_acceptance_test),
    (select revision_two_id from _revision_acceptance_test)
  ),
  'P0001',
  'Program revision changed; reload',
  'stale unaccepted revision cannot be accepted'
);

select lives_ok(
  format(
    'select public.stk_accept_program_revision(%L::uuid,%L::uuid)',
    (select assignment_id from _revision_acceptance_test),
    (select revision_three_id from _revision_acceptance_test)
  ),
  'client can accept current latest revision'
);

select is(
  (
    select version
      from public.stk_assigned_programs
     where id=(select assignment_id from _revision_acceptance_test)
  ),
  1,
  'revision acceptance does not advance assignment version'
);

select is(
  (
    select name
      from public.stk_assigned_programs
     where id=(select assignment_id from _revision_acceptance_test)
  ),
  'Original Plan',
  'revision acceptance does not rewrite assignment prescription'
);

select is(
  (
    public.stk_get_my_program_revision_state(
      (select assignment_id from _revision_acceptance_test)
    )->>'accepted_revision_number'
  )::integer,
  3,
  'accepted revision pointer advances to revision 3'
);

select is(
  (
    public.stk_get_my_program_revision_state(
      (select assignment_id from _revision_acceptance_test)
    )->>'has_pending_revision'
  )::boolean,
  false,
  'accepted latest revision is no longer pending'
);

reset role;

select is(
  (
    select count(*)::integer
      from public.stk_assigned_program_revision_acceptances
     where assignment_id=(select assignment_id from _revision_acceptance_test)
  ),
  2,
  'acceptance history keeps baseline and revision 3 events'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (
    public.stk_accept_program_revision(
      (select assignment_id from _revision_acceptance_test),
      (select revision_three_id from _revision_acceptance_test)
    )->>'already_accepted'
  )::boolean,
  true,
  'double acceptance is idempotent'
);

reset role;

select is(
  (
    select count(*)::integer
      from public.stk_assigned_program_revision_acceptances
     where assignment_id=(select assignment_id from _revision_acceptance_test)
  ),
  2,
  'double acceptance does not append another event'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (
    public.stk_get_my_program_revision_page(
      (select assignment_id from _revision_acceptance_test),
      (select revision_three_id from _revision_acceptance_test),
      null,25,0
    )->>'is_accepted'
  )::boolean,
  true,
  'accepted revision page reports accepted state'
);

select is(
  (
    public.stk_get_my_program_revision_page(
      (select assignment_id from _revision_acceptance_test),
      (select revision_three_id from _revision_acceptance_test),
      null,25,0
    )->>'can_accept'
  )::boolean,
  false,
  'accepted revision page cannot be accepted again from UI state'
);


select is(
  public.stk_get_my_program_revision_page(
    (select assignment_id from _revision_acceptance_test),
    (select revision_three_id from _revision_acceptance_test),
    null,25,0
  )->>'notes',
  'Current proposal',
  'accepted revision page exposes immutable program notes for installation'
);

select is(
  public.stk_get_my_program_revision_page(
    (select assignment_id from _revision_acceptance_test),
    (select revision_three_id from _revision_acceptance_test),
    null,25,0
  )->'items'->0->>'notes',
  'Install routine note',
  'accepted revision page exposes immutable routine notes for installation'
);

select is(
  (
    public.stk_get_my_program_revision_page(
      (select assignment_id from _revision_acceptance_test),
      (select revision_three_id from _revision_acceptance_test),
      (
        public.stk_get_my_program_revision_page(
          (select assignment_id from _revision_acceptance_test),
          (select revision_three_id from _revision_acceptance_test),
          null,25,0
        )->'items'->0->>'id'
      )::uuid,
      25,0
    )->'items'->0
  ) - array[
    'id','position','name','muscle_group','equipment','target_sets',
    'target_reps_min','target_reps_max','rest_seconds','warmup_sets',
    'approach_sets','unilateral','unilateral_target','superset_key'
  ],
  '{"warmup_rest_seconds":50,"approach_rest_seconds":80,"preparation_unilateral":false,"unilateral_side_rest_seconds":0,"preferred_unilateral_start_side":"right"}'::jsonb,
  'client revision transport preserves exercise prescription v2'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

update _revision_acceptance_test
set revision_four_id = (
  public.stk_create_coach_pro_program_revision(
    '83000000-0000-0000-0000-000000000001',
    assignment_id,
    revision_three_id,
    jsonb_build_object(
      'name','Revision 4',
      'notes','Pending after revision 3',
      'duration_weeks',11,
      'training_weekdays',jsonb_build_array(1,2,4,5),
      'starts_on','2026-10-27',
      'routines',jsonb_build_array(
        jsonb_build_object(
          'name','Upper R4',
          'notes','',
          'exercises',jsonb_build_array(
            jsonb_build_object(
              'name','Row R4',
              'muscle_group','Back',
              'equipment','Cable',
              'target_sets',4,
              'target_reps_min',6,
              'target_reps_max',8,
              'rest_seconds',160,
              'warmup_sets',2,
              'approach_sets',1,
              'unilateral',true,
              'unilateral_target','back'
            )
          )
        )
      )
    )
  )->>'revision_id'
)::uuid;

reset role;

update public.stk_coach_client_relationships
set permissions='{}'::jsonb
where id='83000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  format(
    'select public.stk_accept_program_revision(%L::uuid,%L::uuid)',
    (select assignment_id from _revision_acceptance_test),
    (select revision_four_id from _revision_acceptance_test)
  ),
  'P0001',
  'Assigned program revision acceptance unavailable',
  'permission revocation blocks pending revision acceptance'
);

select is(
  (
    public.stk_get_my_program_revision_state(
      (select assignment_id from _revision_acceptance_test)
    )->>'latest_revision_number'
  )::integer,
  3,
  'revoked access exposes accepted revision instead of pending proposal'
);

select is(
  (
    public.stk_get_my_program_revision_state(
      (select assignment_id from _revision_acceptance_test)
    )->>'has_pending_revision'
  )::boolean,
  false,
  'revoked access hides pending proposal'
);

select is(
  public.stk_get_my_program_revision_page(
    (select assignment_id from _revision_acceptance_test),
    (select revision_three_id from _revision_acceptance_test),
    null,25,0
  )->>'name',
  'Revision 3',
  'accepted revision remains readable after permission revocation'
);

reset role;

update public.stk_coach_client_relationships
set permissions='{"assign_programs":true}'::jsonb
where id='83000000-0000-0000-0000-000000000001';

update public.stk_subscription_entitlements
set status='canceled',
    current_period_end=now()-interval '1 minute'
where user_id='81000000-0000-0000-0000-000000000001'
  and product='coach_pro';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  format(
    'select public.stk_accept_program_revision(%L::uuid,%L::uuid)',
    (select assignment_id from _revision_acceptance_test),
    (select revision_four_id from _revision_acceptance_test)
  ),
  'P0001',
  'Coach Pro entitlement required',
  'Coach Pro downgrade blocks pending revision acceptance'
);

select is(
  public.stk_get_my_program_revision_page(
    (select assignment_id from _revision_acceptance_test),
    (select revision_three_id from _revision_acceptance_test),
    null,25,0
  )->>'name',
  'Revision 3',
  'accepted revision remains readable after Coach Pro downgrade'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);

select throws_ok(
  format(
    'select public.stk_get_my_program_revision_state(%L::uuid)',
    (select assignment_id from _revision_acceptance_test)
  ),
  'P0001',
  'Assigned program revision access unavailable',
  'unrelated user cannot read revision state'
);

select throws_ok(
  format(
    'select public.stk_get_my_program_revision_page(%L::uuid,%L::uuid,null,25,0)',
    (select assignment_id from _revision_acceptance_test),
    (select revision_three_id from _revision_acceptance_test)
  ),
  'P0001',
  'Assigned program revision access unavailable',
  'unrelated user cannot read accepted revision'
);

select throws_ok(
  format(
    'select public.stk_accept_program_revision(%L::uuid,%L::uuid)',
    (select assignment_id from _revision_acceptance_test),
    (select revision_four_id from _revision_acceptance_test)
  ),
  'P0001',
  'Assigned program revision acceptance unavailable',
  'unrelated user cannot accept revision'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":true}',
  true
);

select throws_ok(
  format(
    'select public.stk_get_my_program_revision_state(%L::uuid)',
    (select assignment_id from _revision_acceptance_test)
  ),
  'P0001',
  'Permanent authenticated account required',
  'anonymous session cannot read client revision state'
);

select * from finish();

rollback;
