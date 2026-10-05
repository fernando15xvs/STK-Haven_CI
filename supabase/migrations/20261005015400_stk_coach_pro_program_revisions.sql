-- Roadmap 4.0 / Coach Pro Phase 2
-- Immutable program revision history foundation.
--
-- This migration deliberately separates immutable prescription snapshots from
-- client acceptance/installation state. Existing assignments are captured as
-- observed legacy baselines without inventing historical author/timestamp data.

create table if not exists public.stk_assigned_program_revisions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null
    references public.stk_assigned_programs(id) on delete cascade,
  revision_number integer not null,
  previous_revision_id uuid
    references public.stk_assigned_program_revisions(id) on delete restrict,
  source_kind text not null,
  observed_assignment_version integer not null,
  name text not null,
  notes text not null default '',
  duration_weeks integer not null,
  training_weekdays smallint[] not null default '{}'::smallint[],
  starts_on date not null,
  authored_by uuid references auth.users(id) on delete set null,
  authored_at timestamptz,
  recorded_at timestamptz not null default now(),
  constraint stk_program_revision_number
    check (revision_number between 1 and 10000),
  constraint stk_program_revision_source
    check (source_kind in ('legacy_baseline', 'coach_revision')),
  constraint stk_program_revision_assignment_version
    check (observed_assignment_version > 0),
  constraint stk_program_revision_name
    check (char_length(btrim(name)) between 1 and 120),
  constraint stk_program_revision_notes
    check (char_length(notes) <= 4000),
  constraint stk_program_revision_duration
    check (duration_weeks between 1 and 104),
  constraint stk_program_revision_weekdays
    check (
      training_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
      and cardinality(training_weekdays) <= 7
    ),
  constraint stk_program_revision_authorship
    check (
      (
        source_kind = 'legacy_baseline'
        and authored_by is null
        and authored_at is null
      )
      or (
        source_kind = 'coach_revision'
        and authored_at is not null
      )
    ),
  unique (assignment_id, revision_number),
  unique (previous_revision_id)
);

create table if not exists public.stk_assigned_program_revision_routines (
  id uuid primary key default gen_random_uuid(),
  revision_id uuid not null
    references public.stk_assigned_program_revisions(id) on delete cascade,
  position integer not null,
  name text not null,
  notes text not null default '',
  constraint stk_program_revision_routine_position
    check (position between 0 and 49),
  constraint stk_program_revision_routine_name
    check (char_length(btrim(name)) between 1 and 120),
  constraint stk_program_revision_routine_notes
    check (char_length(notes) <= 4000),
  unique (revision_id, position)
);

create table if not exists public.stk_assigned_program_revision_exercises (
  id uuid primary key default gen_random_uuid(),
  revision_routine_id uuid not null
    references public.stk_assigned_program_revision_routines(id)
    on delete cascade,
  position integer not null,
  exercise_name text not null,
  muscle_group text not null default '',
  equipment text not null default '',
  target_sets integer not null,
  target_reps_min integer not null,
  target_reps_max integer not null,
  rest_seconds integer not null,
  warmup_sets integer not null default 0,
  approach_sets integer not null default 0,
  unilateral boolean not null default false,
  unilateral_target text not null default 'other',
  superset_key text,
  constraint stk_program_revision_exercise_position
    check (position between 0 and 99),
  constraint stk_program_revision_exercise_name
    check (char_length(btrim(exercise_name)) between 1 and 160),
  constraint stk_program_revision_exercise_muscle
    check (char_length(muscle_group) <= 120),
  constraint stk_program_revision_exercise_equipment
    check (char_length(equipment) <= 120),
  constraint stk_program_revision_exercise_sets
    check (target_sets between 1 and 30),
  constraint stk_program_revision_exercise_reps
    check (
      target_reps_min between 1 and 1000
      and target_reps_max between target_reps_min and 1000
    ),
  constraint stk_program_revision_exercise_rest
    check (rest_seconds between 0 and 3600),
  constraint stk_program_revision_exercise_warmup
    check (warmup_sets between 0 and 20),
  constraint stk_program_revision_exercise_approach
    check (approach_sets between 0 and 20),
  constraint stk_program_revision_exercise_unilateral_target
    check (
      unilateral_target in ('arm','leg','glute','back','chest','other')
    ),
  constraint stk_program_revision_exercise_superset
    check (superset_key is null or char_length(superset_key) <= 80),
  unique (revision_routine_id, position)
);

create index if not exists stk_program_revisions_assignment_idx
  on public.stk_assigned_program_revisions
  (assignment_id, revision_number desc, recorded_at desc);

create index if not exists stk_program_revision_routines_revision_idx
  on public.stk_assigned_program_revision_routines
  (revision_id, position, id);

create index if not exists stk_program_revision_exercises_routine_idx
  on public.stk_assigned_program_revision_exercises
  (revision_routine_id, position, id);

alter table public.stk_assigned_program_revisions enable row level security;
alter table public.stk_assigned_program_revision_routines enable row level security;
alter table public.stk_assigned_program_revision_exercises enable row level security;

revoke all on public.stk_assigned_program_revisions from anon, authenticated;
revoke all on public.stk_assigned_program_revision_routines from anon, authenticated;
revoke all on public.stk_assigned_program_revision_exercises from anon, authenticated;

create or replace function public.stk_reject_program_revision_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Program revisions are immutable';
end;
$$;

revoke all on function public.stk_reject_program_revision_update()
  from public, anon, authenticated;

drop trigger if exists stk_program_revision_no_update
  on public.stk_assigned_program_revisions;
create trigger stk_program_revision_no_update
before update on public.stk_assigned_program_revisions
for each row execute function public.stk_reject_program_revision_update();

drop trigger if exists stk_program_revision_routine_no_update
  on public.stk_assigned_program_revision_routines;
create trigger stk_program_revision_routine_no_update
before update on public.stk_assigned_program_revision_routines
for each row execute function public.stk_reject_program_revision_update();

drop trigger if exists stk_program_revision_exercise_no_update
  on public.stk_assigned_program_revision_exercises;
create trigger stk_program_revision_exercise_no_update
before update on public.stk_assigned_program_revision_exercises
for each row execute function public.stk_reject_program_revision_update();

create or replace function public.stk_capture_assigned_program_baseline(
  p_assignment_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.stk_assigned_programs%rowtype;
  v_existing uuid;
  v_revision_id uuid;
  v_revision_routine_id uuid;
  v_routine record;
begin
  select revision.id
    into v_existing
    from public.stk_assigned_program_revisions as revision
   where revision.assignment_id = p_assignment_id
   order by revision.revision_number
   limit 1;

  if v_existing is not null then
    return v_existing;
  end if;

  select assignment.*
    into v_assignment
    from public.stk_assigned_programs as assignment
   where assignment.id = p_assignment_id
   for share;

  if not found then
    raise exception 'Assigned program not found';
  end if;

  insert into public.stk_assigned_program_revisions (
    assignment_id,
    revision_number,
    previous_revision_id,
    source_kind,
    observed_assignment_version,
    name,
    notes,
    duration_weeks,
    training_weekdays,
    starts_on,
    authored_by,
    authored_at
  )
  values (
    v_assignment.id,
    1,
    null,
    'legacy_baseline',
    v_assignment.version,
    v_assignment.name,
    v_assignment.notes,
    v_assignment.duration_weeks,
    v_assignment.training_weekdays,
    v_assignment.starts_on,
    null,
    null
  )
  returning id into v_revision_id;

  for v_routine in
    select routine.*
      from public.stk_assigned_program_routines as routine
     where routine.assignment_id = v_assignment.id
     order by routine.position, routine.id
  loop
    insert into public.stk_assigned_program_revision_routines (
      revision_id,
      position,
      name,
      notes
    )
    values (
      v_revision_id,
      v_routine.position,
      v_routine.name,
      v_routine.notes
    )
    returning id into v_revision_routine_id;

    insert into public.stk_assigned_program_revision_exercises (
      revision_routine_id,
      position,
      exercise_name,
      muscle_group,
      equipment,
      target_sets,
      target_reps_min,
      target_reps_max,
      rest_seconds,
      warmup_sets,
      approach_sets,
      unilateral,
      unilateral_target,
      superset_key
    )
    select
      v_revision_routine_id,
      exercise.position,
      exercise.exercise_name,
      exercise.muscle_group,
      exercise.equipment,
      exercise.target_sets,
      exercise.target_reps_min,
      exercise.target_reps_max,
      exercise.rest_seconds,
      exercise.warmup_sets,
      exercise.approach_sets,
      exercise.unilateral,
      exercise.unilateral_target,
      exercise.superset_key
    from public.stk_assigned_program_exercises as exercise
    where exercise.routine_id = v_routine.id
    order by exercise.position, exercise.id;
  end loop;

  return v_revision_id;
exception
  when unique_violation then
    select revision.id
      into v_existing
      from public.stk_assigned_program_revisions as revision
     where revision.assignment_id = p_assignment_id
     order by revision.revision_number
     limit 1;
    if v_existing is not null then
      return v_existing;
    end if;
    raise;
end;
$$;

revoke all on function public.stk_capture_assigned_program_baseline(uuid)
  from public, anon, authenticated;

do $$
declare
  v_assignment_id uuid;
begin
  for v_assignment_id in
    select assignment.id
      from public.stk_assigned_programs as assignment
     order by assignment.created_at, assignment.id
  loop
    perform public.stk_capture_assigned_program_baseline(v_assignment_id);
  end loop;
end;
$$;

alter function public.stk_assign_program(uuid, jsonb)
  rename to stk_assign_program_legacy_impl;

revoke all on function public.stk_assign_program_legacy_impl(uuid, jsonb)
  from public, anon, authenticated;

create or replace function public.stk_assign_program(
  p_client_user_id uuid,
  p_program jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment_id uuid;
begin
  v_assignment_id := public.stk_assign_program_legacy_impl(
    p_client_user_id,
    p_program
  );
  perform public.stk_capture_assigned_program_baseline(v_assignment_id);
  return v_assignment_id;
end;
$$;

revoke all on function public.stk_assign_program(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.stk_assign_program(uuid, jsonb)
  to authenticated;

create or replace function public.stk_list_coach_pro_program_revisions(
  p_relationship_id uuid,
  p_assignment_id uuid,
  p_limit integer default 25,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_coach_user_id uuid := auth.uid();
  v_assignment public.stk_assigned_programs%rowtype;
  v_limit integer := coalesce(p_limit, 25);
  v_offset integer := coalesce(p_offset, 0);
  v_items jsonb;
  v_total bigint;
begin
  if v_coach_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if not exists (
    select 1
      from public.stk_user_capabilities
     where user_id = v_coach_user_id
       and capability = 'coach'
  ) then
    raise exception 'Coach capability required';
  end if;

  perform public.stk_assert_coach_pro_access(v_coach_user_id);

  if v_limit < 1 or v_limit > 100 then
    raise exception 'Coach Pro page limit must be between 1 and 100';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception 'Coach Pro page offset is invalid';
  end if;

  select assignment.*
    into v_assignment
    from public.stk_assigned_programs as assignment
    join public.stk_coach_client_relationships as relationship
      on relationship.id = assignment.relationship_id
   where assignment.id = p_assignment_id
     and relationship.id = p_relationship_id
     and assignment.coach_user_id = v_coach_user_id
     and relationship.coach_user_id = v_coach_user_id
     and assignment.client_user_id = relationship.client_user_id
     and relationship.status = 'active'
     and coalesce(
       (relationship.permissions ->> 'assign_programs')::boolean,
       false
     );

  if not found then
    raise exception 'Assigned program revision access unavailable';
  end if;

  with permitted as (
    select
      revision.id,
      revision.revision_number,
      revision.previous_revision_id,
      revision.source_kind,
      revision.observed_assignment_version,
      revision.recorded_at,
      revision.authored_at
    from public.stk_assigned_program_revisions as revision
    where revision.assignment_id = v_assignment.id
  ), page as (
    select *
      from permitted
     order by revision_number desc, id
     limit v_limit
     offset v_offset
  )
  select
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.to_jsonb(item)
          order by item.revision_number desc, item.id
        )
        from page as item
      ),
      '[]'::jsonb
    ),
    (select count(*) from permitted)
  into v_items, v_total;

  return pg_catalog.jsonb_build_object(
    'assignment_id', v_assignment.id,
    'relationship_id', v_assignment.relationship_id,
    'current_assignment_version', v_assignment.version,
    'items', v_items,
    'total_count', v_total
  );
end;
$$;

revoke all on function public.stk_list_coach_pro_program_revisions(
  uuid, uuid, integer, integer
) from public, anon, authenticated;
grant execute on function public.stk_list_coach_pro_program_revisions(
  uuid, uuid, integer, integer
) to authenticated;

create or replace function public.stk_get_coach_pro_program_revision_page(
  p_relationship_id uuid,
  p_assignment_id uuid,
  p_revision_id uuid,
  p_revision_routine_id uuid default null,
  p_limit integer default 25,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_coach_user_id uuid := auth.uid();
  v_assignment public.stk_assigned_programs%rowtype;
  v_revision public.stk_assigned_program_revisions%rowtype;
  v_routine jsonb := null;
  v_limit integer := coalesce(p_limit, 25);
  v_offset integer := coalesce(p_offset, 0);
  v_items jsonb;
  v_total bigint;
begin
  if v_coach_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if not exists (
    select 1
      from public.stk_user_capabilities
     where user_id = v_coach_user_id
       and capability = 'coach'
  ) then
    raise exception 'Coach capability required';
  end if;

  perform public.stk_assert_coach_pro_access(v_coach_user_id);

  if v_limit < 1 or v_limit > 100 then
    raise exception 'Coach Pro page limit must be between 1 and 100';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception 'Coach Pro page offset is invalid';
  end if;

  select assignment.*
    into v_assignment
    from public.stk_assigned_programs as assignment
    join public.stk_coach_client_relationships as relationship
      on relationship.id = assignment.relationship_id
   where assignment.id = p_assignment_id
     and relationship.id = p_relationship_id
     and assignment.coach_user_id = v_coach_user_id
     and relationship.coach_user_id = v_coach_user_id
     and assignment.client_user_id = relationship.client_user_id
     and relationship.status = 'active'
     and coalesce(
       (relationship.permissions ->> 'assign_programs')::boolean,
       false
     );

  if not found then
    raise exception 'Assigned program revision access unavailable';
  end if;

  select revision.*
    into v_revision
    from public.stk_assigned_program_revisions as revision
   where revision.id = p_revision_id
     and revision.assignment_id = v_assignment.id;

  if not found then
    raise exception 'Assigned program revision access unavailable';
  end if;

  if p_revision_routine_id is null then
    with permitted as (
      select routine.id, routine.position, routine.name
        from public.stk_assigned_program_revision_routines as routine
       where routine.revision_id = v_revision.id
    ), page as (
      select *
        from permitted
       order by position, id
       limit v_limit
       offset v_offset
    )
    select
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.to_jsonb(item)
            order by item.position, item.id
          )
          from page as item
        ),
        '[]'::jsonb
      ),
      (select count(*) from permitted)
    into v_items, v_total;
  else
    select pg_catalog.jsonb_build_object(
      'id', routine.id,
      'name', routine.name,
      'position', routine.position
    )
    into v_routine
    from public.stk_assigned_program_revision_routines as routine
    where routine.id = p_revision_routine_id
      and routine.revision_id = v_revision.id;

    if not found then
      raise exception 'Assigned program revision access unavailable';
    end if;

    with permitted as (
      select
        exercise.id,
        exercise.position,
        exercise.exercise_name as name,
        exercise.muscle_group,
        exercise.equipment,
        exercise.target_sets,
        exercise.target_reps_min,
        exercise.target_reps_max,
        exercise.rest_seconds,
        exercise.warmup_sets,
        exercise.approach_sets,
        exercise.unilateral,
        exercise.unilateral_target,
        exercise.superset_key
      from public.stk_assigned_program_revision_exercises as exercise
      where exercise.revision_routine_id = p_revision_routine_id
    ), page as (
      select *
        from permitted
       order by position, id
       limit v_limit
       offset v_offset
    )
    select
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.to_jsonb(item)
            order by item.position, item.id
          )
          from page as item
        ),
        '[]'::jsonb
      ),
      (select count(*) from permitted)
    into v_items, v_total;
  end if;

  return pg_catalog.jsonb_build_object(
    'assignment_id', v_assignment.id,
    'relationship_id', v_assignment.relationship_id,
    'revision_id', v_revision.id,
    'revision_number', v_revision.revision_number,
    'previous_revision_id', v_revision.previous_revision_id,
    'source_kind', v_revision.source_kind,
    'observed_assignment_version', v_revision.observed_assignment_version,
    'name', v_revision.name,
    'duration_weeks', v_revision.duration_weeks,
    'training_weekdays', v_revision.training_weekdays,
    'starts_on', v_revision.starts_on,
    'recorded_at', v_revision.recorded_at,
    'authored_at', v_revision.authored_at,
    'routine', v_routine,
    'items', v_items,
    'total_count', v_total
  );
end;
$$;

revoke all on function public.stk_get_coach_pro_program_revision_page(
  uuid, uuid, uuid, uuid, integer, integer
) from public, anon, authenticated;
grant execute on function public.stk_get_coach_pro_program_revision_page(
  uuid, uuid, uuid, uuid, integer, integer
) to authenticated;

comment on table public.stk_assigned_program_revisions is
  'Immutable prescription snapshots for coach-assigned programs. Legacy baselines record observed state without inventing historical authorship.';
comment on table public.stk_assigned_program_revision_routines is
  'Immutable routine snapshots belonging to one assigned-program revision.';
comment on table public.stk_assigned_program_revision_exercises is
  'Immutable exercise prescription snapshots belonging to one revision routine.';
comment on function public.stk_list_coach_pro_program_revisions(uuid, uuid, integer, integer) is
  'Coach Pro paginated immutable revision history. Requires permanent coach account, active entitlement, active owned relationship and assign_programs consent.';
comment on function public.stk_get_coach_pro_program_revision_page(uuid, uuid, uuid, uuid, integer, integer) is
  'Coach Pro paginated read of one immutable program revision. Listing metadata intentionally excludes notes.';
