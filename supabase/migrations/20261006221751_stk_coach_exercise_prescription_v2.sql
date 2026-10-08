-- Coach exercise prescription contract v2.
-- Keeps preparation rests and unilateral behavior immutable across
-- assignment, Coach Pro revision history, and client installation.

alter table public.stk_assigned_program_exercises
  add column if not exists warmup_rest_seconds integer,
  add column if not exists approach_rest_seconds integer,
  add column if not exists preparation_unilateral boolean not null default true,
  add column if not exists unilateral_side_rest_seconds integer,
  add column if not exists preferred_unilateral_start_side text;

alter table public.stk_assigned_program_revision_exercises
  add column if not exists warmup_rest_seconds integer,
  add column if not exists approach_rest_seconds integer,
  add column if not exists preparation_unilateral boolean not null default true,
  add column if not exists unilateral_side_rest_seconds integer,
  add column if not exists preferred_unilateral_start_side text;

alter table public.stk_assigned_program_exercises
  add constraint stk_assigned_program_exercises_warmup_rest
    check (warmup_rest_seconds is null or warmup_rest_seconds between 0 and 3600),
  add constraint stk_assigned_program_exercises_approach_rest
    check (approach_rest_seconds is null or approach_rest_seconds between 0 and 3600),
  add constraint stk_assigned_program_exercises_side_rest
    check (
      unilateral_side_rest_seconds is null
      or unilateral_side_rest_seconds between 0 and 600
    ),
  add constraint stk_assigned_program_exercises_start_side
    check (
      preferred_unilateral_start_side is null
      or preferred_unilateral_start_side in ('automatic','left','right')
    );

alter table public.stk_assigned_program_revision_exercises
  add constraint stk_program_revision_exercise_warmup_rest
    check (warmup_rest_seconds is null or warmup_rest_seconds between 0 and 3600),
  add constraint stk_program_revision_exercise_approach_rest
    check (approach_rest_seconds is null or approach_rest_seconds between 0 and 3600),
  add constraint stk_program_revision_exercise_side_rest
    check (
      unilateral_side_rest_seconds is null
      or unilateral_side_rest_seconds between 0 and 600
    ),
  add constraint stk_program_revision_exercise_start_side
    check (
      preferred_unilateral_start_side is null
      or preferred_unilateral_start_side in ('automatic','left','right')
    );

comment on column public.stk_assigned_program_exercises.preparation_unilateral is
  'When false, warmup/approach sets stay bilateral even if effective work is unilateral.';
comment on column public.stk_assigned_program_revision_exercises.preparation_unilateral is
  'Immutable revision copy of preparation unilateral behavior.';

create or replace function public.stk_assign_program_legacy_impl(
  p_client_user_id uuid,
  p_program jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coach_user_id uuid := auth.uid();
  v_relationship public.stk_coach_client_relationships%rowtype;
  v_assignment_id uuid;
  v_routine_id uuid;
  v_name text;
  v_notes text;
  v_duration_weeks integer;
  v_weekdays smallint[];
  v_starts_on date;
  v_routine jsonb;
  v_exercise jsonb;
  v_routine_ord bigint;
  v_exercise_ord bigint;
  v_routine_count integer;
  v_exercise_count integer;
begin
  if v_coach_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select *
    into v_relationship
    from public.stk_coach_client_relationships
   where coach_user_id = v_coach_user_id
     and client_user_id = p_client_user_id
     and status = 'active'
   limit 1;

  if not found then
    raise exception 'Active coach/client relationship required';
  end if;

  if not coalesce(
    (v_relationship.permissions ->> 'assign_programs')::boolean,
    false
  ) then
    raise exception 'Program assignment permission required';
  end if;

  if pg_catalog.jsonb_typeof(p_program) <> 'object' then
    raise exception 'Program payload must be an object';
  end if;

  v_name := btrim(coalesce(p_program ->> 'name', ''));
  v_notes := coalesce(p_program ->> 'notes', '');
  v_duration_weeks :=
    coalesce((p_program ->> 'duration_weeks')::integer, 8);
  v_starts_on :=
    coalesce((p_program ->> 'starts_on')::date, current_date);

  if char_length(v_name) < 1 or char_length(v_name) > 120 then
    raise exception 'Program name length is invalid';
  end if;

  if char_length(v_notes) > 4000 then
    raise exception 'Program notes are too long';
  end if;

  if v_duration_weeks < 1 or v_duration_weeks > 104 then
    raise exception 'Program duration is invalid';
  end if;

  if pg_catalog.jsonb_typeof(
       coalesce(p_program -> 'training_weekdays', '[]'::jsonb)
     ) <> 'array' then
    raise exception 'training_weekdays must be an array';
  end if;

  select coalesce(
           array_agg(distinct weekday::smallint order by weekday::smallint),
           '{}'::smallint[]
         )
    into v_weekdays
    from pg_catalog.jsonb_array_elements_text(
      coalesce(p_program -> 'training_weekdays', '[]'::jsonb)
    ) as value(weekday);

  if not (
    v_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
  ) then
    raise exception 'training_weekdays contains an invalid day';
  end if;

  if pg_catalog.jsonb_typeof(p_program -> 'routines') <> 'array' then
    raise exception 'Program routines must be an array';
  end if;

  v_routine_count := pg_catalog.jsonb_array_length(p_program -> 'routines');
  if v_routine_count < 1 or v_routine_count > 20 then
    raise exception 'Program must contain between 1 and 20 routines';
  end if;

  insert into public.stk_assigned_programs (
    relationship_id,
    coach_user_id,
    client_user_id,
    name,
    notes,
    duration_weeks,
    training_weekdays,
    starts_on
  )
  values (
    v_relationship.id,
    v_coach_user_id,
    p_client_user_id,
    v_name,
    v_notes,
    v_duration_weeks,
    v_weekdays,
    v_starts_on
  )
  returning id into v_assignment_id;

  for v_routine, v_routine_ord in
    select item.value, item.ordinality
      from pg_catalog.jsonb_array_elements(p_program -> 'routines')
           with ordinality as item(value, ordinality)
  loop
    if pg_catalog.jsonb_typeof(v_routine) <> 'object' then
      raise exception 'Routine payload must be an object';
    end if;

    if char_length(btrim(coalesce(v_routine ->> 'name', ''))) < 1
       or char_length(btrim(coalesce(v_routine ->> 'name', ''))) > 120 then
      raise exception 'Routine name length is invalid';
    end if;

    if char_length(coalesce(v_routine ->> 'notes', '')) > 4000 then
      raise exception 'Routine notes are too long';
    end if;

    if pg_catalog.jsonb_typeof(v_routine -> 'exercises') <> 'array' then
      raise exception 'Routine exercises must be an array';
    end if;

    v_exercise_count :=
      pg_catalog.jsonb_array_length(v_routine -> 'exercises');
    if v_exercise_count < 1 or v_exercise_count > 60 then
      raise exception 'Routine must contain between 1 and 60 exercises';
    end if;

    insert into public.stk_assigned_program_routines (
      assignment_id,
      position,
      name,
      notes
    )
    values (
      v_assignment_id,
      (v_routine_ord - 1)::integer,
      btrim(v_routine ->> 'name'),
      coalesce(v_routine ->> 'notes', '')
    )
    returning id into v_routine_id;

    for v_exercise, v_exercise_ord in
      select item.value, item.ordinality
        from pg_catalog.jsonb_array_elements(v_routine -> 'exercises')
             with ordinality as item(value, ordinality)
    loop
      if pg_catalog.jsonb_typeof(v_exercise) <> 'object' then
        raise exception 'Exercise payload must be an object';
      end if;

      insert into public.stk_assigned_program_exercises (
        routine_id,
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
        warmup_rest_seconds,
        approach_rest_seconds,
        unilateral,
        unilateral_target,
        preparation_unilateral,
        unilateral_side_rest_seconds,
        preferred_unilateral_start_side,
        superset_key
      )
      values (
        v_routine_id,
        (v_exercise_ord - 1)::integer,
        btrim(coalesce(v_exercise ->> 'name', '')),
        coalesce(v_exercise ->> 'muscle_group', ''),
        coalesce(v_exercise ->> 'equipment', ''),
        coalesce((v_exercise ->> 'target_sets')::integer, 3),
        coalesce((v_exercise ->> 'target_reps_min')::integer, 8),
        coalesce((v_exercise ->> 'target_reps_max')::integer, 12),
        coalesce((v_exercise ->> 'rest_seconds')::integer, 120),
        coalesce((v_exercise ->> 'warmup_sets')::integer, 0),
        coalesce((v_exercise ->> 'approach_sets')::integer, 0),
        (v_exercise ->> 'warmup_rest_seconds')::integer,
        (v_exercise ->> 'approach_rest_seconds')::integer,
        coalesce((v_exercise ->> 'unilateral')::boolean, false),
        coalesce(v_exercise ->> 'unilateral_target', 'other'),
        coalesce((v_exercise ->> 'preparation_unilateral')::boolean, true),
        (v_exercise ->> 'unilateral_side_rest_seconds')::integer,
        nullif(v_exercise ->> 'preferred_unilateral_start_side', ''),
        nullif(v_exercise ->> 'superset_key', '')
      );
    end loop;
  end loop;

  return v_assignment_id;
end;
$$;

create or replace function public.stk_get_assigned_program(
  p_assignment_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select pg_catalog.jsonb_build_object(
    'id', assignment.id,
    'relationship_id', assignment.relationship_id,
    'coach_user_id', assignment.coach_user_id,
    'client_user_id', assignment.client_user_id,
    'name', assignment.name,
    'notes', assignment.notes,
    'duration_weeks', assignment.duration_weeks,
    'training_weekdays', assignment.training_weekdays,
    'starts_on', assignment.starts_on,
    'status', assignment.status,
    'version', assignment.version,
    'created_at', assignment.created_at,
    'accepted_at', assignment.accepted_at,
    'updated_at', assignment.updated_at,
    'routines', coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'id', routine.id,
            'position', routine.position,
            'name', routine.name,
            'notes', routine.notes,
            'exercises', coalesce(
              (
                select pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'id', exercise.id,
                    'position', exercise.position,
                    'name', exercise.exercise_name,
                    'muscle_group', exercise.muscle_group,
                    'equipment', exercise.equipment,
                    'target_sets', exercise.target_sets,
                    'target_reps_min', exercise.target_reps_min,
                    'target_reps_max', exercise.target_reps_max,
                    'rest_seconds', exercise.rest_seconds,
                    'warmup_sets', exercise.warmup_sets,
                    'approach_sets', exercise.approach_sets,
                    'warmup_rest_seconds', exercise.warmup_rest_seconds,
                    'approach_rest_seconds', exercise.approach_rest_seconds,
                    'unilateral', exercise.unilateral,
                    'unilateral_target', exercise.unilateral_target,
                    'preparation_unilateral', exercise.preparation_unilateral,
                    'unilateral_side_rest_seconds',
                      exercise.unilateral_side_rest_seconds,
                    'preferred_unilateral_start_side',
                      exercise.preferred_unilateral_start_side,
                    'superset_key', exercise.superset_key
                  )
                  order by exercise.position
                )
                from public.stk_assigned_program_exercises as exercise
                where exercise.routine_id = routine.id
              ),
              '[]'::jsonb
            )
          )
          order by routine.position
        )
        from public.stk_assigned_program_routines as routine
        where routine.assignment_id = assignment.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.stk_assigned_programs as assignment
  where assignment.id = p_assignment_id
    and (
      assignment.coach_user_id = v_user_id
      or assignment.client_user_id = v_user_id
    );

  if v_result is null then
    raise exception 'Assigned program not found';
  end if;

  return v_result;
end;
$$;

create or replace function public.stk_get_coach_pro_program_page(
  p_relationship_id uuid, p_assignment_id uuid, p_version integer,
  p_routine_id uuid default null, p_limit integer default 25, p_offset integer default 0
)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_coach uuid := auth.uid();
  v_program public.stk_assigned_programs%rowtype;
  v_routine jsonb := null;
  v_items jsonb;
  v_total bigint;
  v_limit integer := coalesce(p_limit,25);
  v_offset integer := coalesce(p_offset,0);
begin
  if v_coach is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities
    where user_id=v_coach and capability='coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  select a.* into v_program
    from public.stk_assigned_programs a
    join public.stk_coach_client_relationships r on r.id=a.relationship_id
    where a.id=p_assignment_id and r.id=p_relationship_id
      and a.coach_user_id=v_coach and r.coach_user_id=v_coach
      and a.client_user_id=r.client_user_id and r.status='active'
      and coalesce((r.permissions->>'assign_programs')::boolean,false);
  if not found then raise exception 'Assigned program access unavailable'; end if;
  if p_version is distinct from v_program.version then
    raise exception 'Assigned program version changed; reload';
  end if;
  if v_limit < 1 or v_limit > 100 then
    raise exception 'Coach Pro page limit must be between 1 and 100';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception 'Coach Pro page offset is invalid';
  end if;
  if p_routine_id is null then
    with permitted as (
      select r.id,r.position,r.name
      from public.stk_assigned_program_routines r where r.assignment_id=v_program.id
    ), page as (select * from permitted order by position,id limit v_limit offset v_offset)
    select coalesce((select jsonb_agg(to_jsonb(p) order by p.position,p.id) from page p),'[]'::jsonb),
      (select count(*) from permitted) into v_items,v_total;
  else
    select jsonb_build_object('id',r.id,'name',r.name,'position',r.position)
      into v_routine from public.stk_assigned_program_routines r
      where r.id=p_routine_id and r.assignment_id=v_program.id;
    if not found then raise exception 'Assigned program access unavailable'; end if;
    with permitted as (
      select e.id,e.position,e.exercise_name as name,e.muscle_group,e.equipment,
        e.target_sets,e.target_reps_min,e.target_reps_max,e.rest_seconds,
        e.warmup_sets,e.approach_sets,e.warmup_rest_seconds,e.approach_rest_seconds,
        e.unilateral,e.unilateral_target,e.preparation_unilateral,
        e.unilateral_side_rest_seconds,e.preferred_unilateral_start_side,e.superset_key
      from public.stk_assigned_program_exercises e
      join public.stk_assigned_program_routines r on r.id=e.routine_id
      where r.assignment_id=v_program.id and r.id=p_routine_id
    ), page as (select * from permitted order by position,id limit v_limit offset v_offset)
    select coalesce((select jsonb_agg(to_jsonb(p) order by p.position,p.id) from page p),'[]'::jsonb),
      (select count(*) from permitted) into v_items,v_total;
  end if;
  return jsonb_build_object('assignment_id',v_program.id,'relationship_id',v_program.relationship_id,
    'name',v_program.name,'version',v_program.version,'status',v_program.status,
    'routine',v_routine,'items',v_items,'total_count',v_total);
end;
$$;

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
      warmup_rest_seconds,
      approach_rest_seconds,
      unilateral,
      unilateral_target,
      preparation_unilateral,
      unilateral_side_rest_seconds,
      preferred_unilateral_start_side,
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
      exercise.warmup_rest_seconds,
      exercise.approach_rest_seconds,
      exercise.unilateral,
      exercise.unilateral_target,
      exercise.preparation_unilateral,
      exercise.unilateral_side_rest_seconds,
      exercise.preferred_unilateral_start_side,
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

create or replace function public.stk_insert_program_revision_snapshot(
  p_assignment_id uuid,
  p_previous_revision_id uuid,
  p_revision_number integer,
  p_observed_assignment_version integer,
  p_program jsonb,
  p_authored_by uuid,
  p_authored_at timestamptz
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_revision_id uuid;
  v_revision_routine_id uuid;
  v_name text;
  v_notes text;
  v_duration_weeks integer;
  v_weekdays smallint[];
  v_starts_on date;
  v_routine jsonb;
  v_exercise jsonb;
  v_routine_ord bigint;
  v_exercise_ord bigint;
  v_routine_count integer;
  v_exercise_count integer;
  v_target_sets integer;
  v_target_reps_min integer;
  v_target_reps_max integer;
  v_rest_seconds integer;
  v_warmup_sets integer;
  v_approach_sets integer;
  v_warmup_rest_seconds integer;
  v_approach_rest_seconds integer;
  v_preparation_unilateral boolean;
  v_unilateral_side_rest_seconds integer;
  v_preferred_unilateral_start_side text;
  v_unilateral_target text;
  v_superset_key text;
begin
  if pg_catalog.jsonb_typeof(p_program) is distinct from 'object' then
    raise exception 'Program revision payload must be an object';
  end if;

  v_name := btrim(coalesce(p_program ->> 'name', ''));
  v_notes := coalesce(p_program ->> 'notes', '');
  v_duration_weeks := coalesce((p_program ->> 'duration_weeks')::integer, 8);
  v_starts_on := coalesce((p_program ->> 'starts_on')::date, current_date);

  if char_length(v_name) < 1 or char_length(v_name) > 120 then
    raise exception 'Program name length is invalid';
  end if;
  if char_length(v_notes) > 4000 then
    raise exception 'Program notes are too long';
  end if;
  if v_duration_weeks < 1 or v_duration_weeks > 104 then
    raise exception 'Program duration is invalid';
  end if;

  if pg_catalog.jsonb_typeof(
       coalesce(p_program -> 'training_weekdays', '[]'::jsonb)
     ) <> 'array' then
    raise exception 'training_weekdays must be an array';
  end if;

  select coalesce(
           array_agg(distinct weekday::smallint order by weekday::smallint),
           '{}'::smallint[]
         )
    into v_weekdays
    from pg_catalog.jsonb_array_elements_text(
      coalesce(p_program -> 'training_weekdays', '[]'::jsonb)
    ) as value(weekday);

  if not (v_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]) then
    raise exception 'training_weekdays contains an invalid day';
  end if;

  if pg_catalog.jsonb_typeof(p_program -> 'routines') is distinct from 'array' then
    raise exception 'Program routines must be an array';
  end if;

  v_routine_count := pg_catalog.jsonb_array_length(p_program -> 'routines');
  if v_routine_count < 1 or v_routine_count > 20 then
    raise exception 'Program must contain between 1 and 20 routines';
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
    p_assignment_id,
    p_revision_number,
    p_previous_revision_id,
    'coach_revision',
    p_observed_assignment_version,
    v_name,
    v_notes,
    v_duration_weeks,
    v_weekdays,
    v_starts_on,
    p_authored_by,
    p_authored_at
  )
  returning id into v_revision_id;

  for v_routine, v_routine_ord in
    select item.value, item.ordinality
      from pg_catalog.jsonb_array_elements(p_program -> 'routines')
           with ordinality as item(value, ordinality)
  loop
    if pg_catalog.jsonb_typeof(v_routine) <> 'object' then
      raise exception 'Routine payload must be an object';
    end if;

    if char_length(btrim(coalesce(v_routine ->> 'name', ''))) < 1
       or char_length(btrim(coalesce(v_routine ->> 'name', ''))) > 120 then
      raise exception 'Routine name length is invalid';
    end if;
    if char_length(coalesce(v_routine ->> 'notes', '')) > 4000 then
      raise exception 'Routine notes are too long';
    end if;
    if pg_catalog.jsonb_typeof(v_routine -> 'exercises') is distinct from 'array' then
      raise exception 'Routine exercises must be an array';
    end if;

    v_exercise_count :=
      pg_catalog.jsonb_array_length(v_routine -> 'exercises');
    if v_exercise_count < 1 or v_exercise_count > 60 then
      raise exception 'Routine must contain between 1 and 60 exercises';
    end if;

    insert into public.stk_assigned_program_revision_routines (
      revision_id,
      position,
      name,
      notes
    )
    values (
      v_revision_id,
      (v_routine_ord - 1)::integer,
      btrim(v_routine ->> 'name'),
      coalesce(v_routine ->> 'notes', '')
    )
    returning id into v_revision_routine_id;

    for v_exercise, v_exercise_ord in
      select item.value, item.ordinality
        from pg_catalog.jsonb_array_elements(v_routine -> 'exercises')
             with ordinality as item(value, ordinality)
    loop
      if pg_catalog.jsonb_typeof(v_exercise) <> 'object' then
        raise exception 'Exercise payload must be an object';
      end if;

      if char_length(btrim(coalesce(v_exercise ->> 'name', ''))) < 1
         or char_length(btrim(coalesce(v_exercise ->> 'name', ''))) > 160 then
        raise exception 'Exercise name length is invalid';
      end if;
      if char_length(coalesce(v_exercise ->> 'muscle_group', '')) > 120
         or char_length(coalesce(v_exercise ->> 'equipment', '')) > 120 then
        raise exception 'Exercise metadata is too long';
      end if;

      v_target_sets := coalesce((v_exercise ->> 'target_sets')::integer, 3);
      v_target_reps_min :=
        coalesce((v_exercise ->> 'target_reps_min')::integer, 8);
      v_target_reps_max :=
        coalesce((v_exercise ->> 'target_reps_max')::integer, 12);
      v_rest_seconds :=
        coalesce((v_exercise ->> 'rest_seconds')::integer, 120);
      v_warmup_sets :=
        coalesce((v_exercise ->> 'warmup_sets')::integer, 0);
      v_approach_sets :=
        coalesce((v_exercise ->> 'approach_sets')::integer, 0);
      v_warmup_rest_seconds :=
        (v_exercise ->> 'warmup_rest_seconds')::integer;
      v_approach_rest_seconds :=
        (v_exercise ->> 'approach_rest_seconds')::integer;
      v_preparation_unilateral :=
        coalesce((v_exercise ->> 'preparation_unilateral')::boolean, true);
      v_unilateral_side_rest_seconds :=
        (v_exercise ->> 'unilateral_side_rest_seconds')::integer;
      v_preferred_unilateral_start_side :=
        nullif(v_exercise ->> 'preferred_unilateral_start_side', '');
      v_unilateral_target :=
        coalesce(v_exercise ->> 'unilateral_target', 'other');
      v_superset_key := nullif(v_exercise ->> 'superset_key', '');

      if v_target_sets < 1 or v_target_sets > 30 then
        raise exception 'Exercise target sets are invalid';
      end if;
      if v_target_reps_min < 1
         or v_target_reps_min > 1000
         or v_target_reps_max < v_target_reps_min
         or v_target_reps_max > 1000 then
        raise exception 'Exercise target reps are invalid';
      end if;
      if v_rest_seconds < 0 or v_rest_seconds > 3600 then
        raise exception 'Exercise rest is invalid';
      end if;
      if v_warmup_sets < 0 or v_warmup_sets > 20
         or v_approach_sets < 0 or v_approach_sets > 20 then
        raise exception 'Exercise warmup or approach sets are invalid';
      end if;
      if v_warmup_rest_seconds is not null
         and (v_warmup_rest_seconds < 0 or v_warmup_rest_seconds > 3600) then
        raise exception 'Exercise warmup rest is invalid';
      end if;
      if v_approach_rest_seconds is not null
         and (v_approach_rest_seconds < 0 or v_approach_rest_seconds > 3600) then
        raise exception 'Exercise approach rest is invalid';
      end if;
      if v_unilateral_side_rest_seconds is not null
         and (
           v_unilateral_side_rest_seconds < 0
           or v_unilateral_side_rest_seconds > 600
         ) then
        raise exception 'Exercise unilateral side rest is invalid';
      end if;
      if v_preferred_unilateral_start_side is not null
         and v_preferred_unilateral_start_side not in (
           'automatic','left','right'
         ) then
        raise exception 'Exercise preferred unilateral start side is invalid';
      end if;
      if v_unilateral_target not in (
        'arm','leg','glute','back','chest','other'
      ) then
        raise exception 'Exercise unilateral target is invalid';
      end if;
      if v_superset_key is not null and char_length(v_superset_key) > 80 then
        raise exception 'Exercise superset key is too long';
      end if;

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
        warmup_rest_seconds,
        approach_rest_seconds,
        unilateral,
        unilateral_target,
        preparation_unilateral,
        unilateral_side_rest_seconds,
        preferred_unilateral_start_side,
        superset_key
      )
      values (
        v_revision_routine_id,
        (v_exercise_ord - 1)::integer,
        btrim(v_exercise ->> 'name'),
        coalesce(v_exercise ->> 'muscle_group', ''),
        coalesce(v_exercise ->> 'equipment', ''),
        v_target_sets,
        v_target_reps_min,
        v_target_reps_max,
        v_rest_seconds,
        v_warmup_sets,
        v_approach_sets,
        v_warmup_rest_seconds,
        v_approach_rest_seconds,
        coalesce((v_exercise ->> 'unilateral')::boolean, false),
        v_unilateral_target,
        v_preparation_unilateral,
        v_unilateral_side_rest_seconds,
        v_preferred_unilateral_start_side,
        v_superset_key
      );
    end loop;
  end loop;

  return v_revision_id;
end;
$$;

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
        exercise.warmup_rest_seconds,
        exercise.approach_rest_seconds,
        exercise.unilateral,
        exercise.unilateral_target,
        exercise.preparation_unilateral,
        exercise.unilateral_side_rest_seconds,
        exercise.preferred_unilateral_start_side,
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
