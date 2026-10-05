-- Roadmap 4.0 / Coach Pro Phase 2
-- Immutable coach-authored program revisions.
--
-- A revision is a proposed prescription snapshot. Creating one never changes
-- the legacy assignment row, its version, acceptance state, or the client's
-- installed local program. Acceptance/installation is a separate future slice.

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
        unilateral,
        unilateral_target,
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
        coalesce((v_exercise ->> 'unilateral')::boolean, false),
        v_unilateral_target,
        v_superset_key
      );
    end loop;
  end loop;

  return v_revision_id;
end;
$$;

revoke all on function public.stk_insert_program_revision_snapshot(
  uuid, uuid, integer, integer, jsonb, uuid, timestamptz
) from public, anon, authenticated;

create or replace function public.stk_create_coach_pro_program_revision(
  p_relationship_id uuid,
  p_assignment_id uuid,
  p_expected_previous_revision_id uuid,
  p_program jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coach_user_id uuid := auth.uid();
  v_assignment public.stk_assigned_programs%rowtype;
  v_previous public.stk_assigned_program_revisions%rowtype;
  v_revision_id uuid;
  v_revision_number integer;
  v_authored_at timestamptz := now();
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
     )
   for update of assignment;

  if not found or v_assignment.status = 'archived' then
    raise exception 'Assigned program revision write unavailable';
  end if;

  perform public.stk_capture_assigned_program_baseline(v_assignment.id);

  select revision.*
    into v_previous
    from public.stk_assigned_program_revisions as revision
   where revision.assignment_id = v_assignment.id
   order by revision.revision_number desc, revision.id
   limit 1;

  if not found then
    raise exception 'Assigned program revision history unavailable';
  end if;

  if p_expected_previous_revision_id is null
     or p_expected_previous_revision_id <> v_previous.id then
    raise exception 'Program revision changed; reload';
  end if;

  v_revision_number := v_previous.revision_number + 1;
  if v_revision_number > 10000 then
    raise exception 'Program revision limit reached';
  end if;

  v_revision_id := public.stk_insert_program_revision_snapshot(
    v_assignment.id,
    v_previous.id,
    v_revision_number,
    v_assignment.version,
    p_program,
    v_coach_user_id,
    v_authored_at
  );

  return pg_catalog.jsonb_build_object(
    'revision_id', v_revision_id,
    'revision_number', v_revision_number,
    'previous_revision_id', v_previous.id,
    'observed_assignment_version', v_assignment.version,
    'authored_at', v_authored_at
  );
exception
  when unique_violation then
    raise exception 'Program revision changed; reload';
end;
$$;

revoke all on function public.stk_create_coach_pro_program_revision(
  uuid, uuid, uuid, jsonb
) from public, anon, authenticated;
grant execute on function public.stk_create_coach_pro_program_revision(
  uuid, uuid, uuid, jsonb
) to authenticated;

comment on function public.stk_create_coach_pro_program_revision(
  uuid, uuid, uuid, jsonb
) is
  'Creates one immutable Coach Pro proposal chained to the current latest revision. The expected previous revision is an optimistic concurrency token. This does not alter assignment.version, acceptance state, or the client local program.';
