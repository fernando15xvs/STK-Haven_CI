-- Coach Pro Phase 2: privacy-scoped progress trends and frequency adherence.
-- Trend baselines are computed on-device from the client's own workout history.
-- Frequency adherence compares the current accepted coach-assigned calendar with
-- aggregate workout counts; it does not claim exact routine/exercise adherence.

alter table public.stk_client_progress_snapshots
  add column if not exists trend_baseline_available boolean not null default false,
  add column if not exists workouts_previous_7d integer not null default 0
    check (workouts_previous_7d between 0 and 1000),
  add column if not exists training_minutes_previous_7d integer not null default 0
    check (training_minutes_previous_7d between 0 and 10080),
  add column if not exists completed_working_sets_previous_7d integer not null default 0
    check (completed_working_sets_previous_7d between 0 and 100000),
  add column if not exists volume_previous_7d numeric(18,2) not null default 0
    check (volume_previous_7d between 0 and 1000000000000);

create or replace function public.stk_sync_own_progress(
  p_progress jsonb,
  p_recent_workouts jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_workout jsonb;
  v_workout_count integer;
  v_workouts_7d integer;
  v_workouts_30d integer;
  v_training_minutes_7d integer;
  v_completed_sets_7d integer;
  v_volume_7d numeric;
  v_average_rir_7d numeric;
  v_last_workout_at timestamptz;
  v_generated_at timestamptz;
  v_trend_baseline_available boolean;
  v_workouts_previous_7d integer;
  v_training_minutes_previous_7d integer;
  v_completed_sets_previous_7d integer;
  v_volume_previous_7d numeric;
  v_workout_id text;
  v_started_at timestamptz;
  v_routine_name text;
  v_duration_seconds integer;
  v_planned_sets integer;
  v_completed_sets integer;
  v_completion_percent integer;
  v_volume numeric;
  v_average_rir numeric;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if pg_catalog.jsonb_typeof(p_progress) <> 'object' then
    raise exception 'Progress payload must be an object';
  end if;

  if pg_catalog.jsonb_typeof(p_recent_workouts) <> 'array' then
    raise exception 'Recent workouts payload must be an array';
  end if;

  v_workout_count := pg_catalog.jsonb_array_length(p_recent_workouts);
  if v_workout_count > 30 then
    raise exception 'At most 30 recent workouts may be synced';
  end if;

  v_workouts_7d := coalesce((p_progress ->> 'workouts_7d')::integer, 0);
  v_workouts_30d := coalesce((p_progress ->> 'workouts_30d')::integer, 0);
  v_training_minutes_7d :=
    coalesce((p_progress ->> 'training_minutes_7d')::integer, 0);
  v_completed_sets_7d :=
    coalesce((p_progress ->> 'completed_working_sets_7d')::integer, 0);
  v_volume_7d := coalesce((p_progress ->> 'volume_7d')::numeric, 0);
  v_average_rir_7d := (p_progress ->> 'average_rir_7d')::numeric;
  v_last_workout_at := (p_progress ->> 'last_workout_at')::timestamptz;
  v_generated_at :=
    coalesce((p_progress ->> 'generated_at')::timestamptz, now());

  v_trend_baseline_available :=
    coalesce((p_progress ->> 'trend_baseline_available')::boolean, false);
  v_workouts_previous_7d :=
    coalesce((p_progress ->> 'workouts_previous_7d')::integer, 0);
  v_training_minutes_previous_7d :=
    coalesce((p_progress ->> 'training_minutes_previous_7d')::integer, 0);
  v_completed_sets_previous_7d :=
    coalesce(
      (p_progress ->> 'completed_working_sets_previous_7d')::integer,
      0
    );
  v_volume_previous_7d :=
    coalesce((p_progress ->> 'volume_previous_7d')::numeric, 0);

  if v_workouts_7d < 0 or v_workouts_7d > 1000
     or v_workouts_30d < 0 or v_workouts_30d > 4000
     or v_workouts_7d > v_workouts_30d then
    raise exception 'Workout counts are invalid';
  end if;

  if v_training_minutes_7d < 0 or v_training_minutes_7d > 10080 then
    raise exception 'Training minutes are invalid';
  end if;

  if v_completed_sets_7d < 0 or v_completed_sets_7d > 100000 then
    raise exception 'Completed set count is invalid';
  end if;

  if v_volume_7d < 0 or v_volume_7d > 1000000000000 then
    raise exception 'Training volume is invalid';
  end if;

  if v_average_rir_7d is not null
     and (v_average_rir_7d < 0 or v_average_rir_7d > 10) then
    raise exception 'Average RIR is invalid';
  end if;

  if v_workouts_previous_7d < 0 or v_workouts_previous_7d > 1000
     or v_training_minutes_previous_7d < 0
     or v_training_minutes_previous_7d > 10080
     or v_completed_sets_previous_7d < 0
     or v_completed_sets_previous_7d > 100000
     or v_volume_previous_7d < 0
     or v_volume_previous_7d > 1000000000000 then
    raise exception 'Previous progress period is invalid';
  end if;

  if v_generated_at > now() + interval '1 day'
     or (
       v_last_workout_at is not null
       and v_last_workout_at > now() + interval '1 day'
     ) then
    raise exception 'Progress timestamps are invalid';
  end if;

  insert into public.stk_client_progress_snapshots (
    client_user_id,
    workouts_7d,
    workouts_30d,
    training_minutes_7d,
    completed_working_sets_7d,
    volume_7d,
    average_rir_7d,
    last_workout_at,
    generated_at,
    trend_baseline_available,
    workouts_previous_7d,
    training_minutes_previous_7d,
    completed_working_sets_previous_7d,
    volume_previous_7d,
    updated_at
  )
  values (
    v_user_id,
    v_workouts_7d,
    v_workouts_30d,
    v_training_minutes_7d,
    v_completed_sets_7d,
    v_volume_7d,
    v_average_rir_7d,
    v_last_workout_at,
    v_generated_at,
    v_trend_baseline_available,
    v_workouts_previous_7d,
    v_training_minutes_previous_7d,
    v_completed_sets_previous_7d,
    v_volume_previous_7d,
    now()
  )
  on conflict (client_user_id) do update
     set workouts_7d = excluded.workouts_7d,
         workouts_30d = excluded.workouts_30d,
         training_minutes_7d = excluded.training_minutes_7d,
         completed_working_sets_7d = excluded.completed_working_sets_7d,
         volume_7d = excluded.volume_7d,
         average_rir_7d = excluded.average_rir_7d,
         last_workout_at = excluded.last_workout_at,
         generated_at = excluded.generated_at,
         trend_baseline_available = excluded.trend_baseline_available,
         workouts_previous_7d = excluded.workouts_previous_7d,
         training_minutes_previous_7d =
           excluded.training_minutes_previous_7d,
         completed_working_sets_previous_7d =
           excluded.completed_working_sets_previous_7d,
         volume_previous_7d = excluded.volume_previous_7d,
         updated_at = now();

  delete from public.stk_client_workout_summaries
   where client_user_id = v_user_id;

  for v_workout in
    select value
      from pg_catalog.jsonb_array_elements(p_recent_workouts)
  loop
    if pg_catalog.jsonb_typeof(v_workout) <> 'object' then
      raise exception 'Workout summary must be an object';
    end if;

    v_workout_id := btrim(coalesce(v_workout ->> 'workout_id', ''));
    v_started_at := (v_workout ->> 'started_at')::timestamptz;
    v_routine_name := coalesce(v_workout ->> 'routine_name', '');
    v_duration_seconds :=
      coalesce((v_workout ->> 'duration_seconds')::integer, 0);
    v_planned_sets :=
      coalesce((v_workout ->> 'planned_working_sets')::integer, 0);
    v_completed_sets :=
      coalesce((v_workout ->> 'completed_working_sets')::integer, 0);
    v_completion_percent :=
      coalesce((v_workout ->> 'completion_percent')::integer, 0);
    v_volume := coalesce((v_workout ->> 'volume')::numeric, 0);
    v_average_rir := (v_workout ->> 'average_rir')::numeric;

    if char_length(v_workout_id) < 1
       or char_length(v_workout_id) > 120 then
      raise exception 'Workout id length is invalid';
    end if;
    if v_started_at is null or v_started_at > now() + interval '1 day' then
      raise exception 'Workout timestamp is invalid';
    end if;
    if char_length(v_routine_name) > 160 then
      raise exception 'Routine name is too long';
    end if;
    if v_duration_seconds < 0 or v_duration_seconds > 86400 then
      raise exception 'Workout duration is invalid';
    end if;
    if v_planned_sets < 0 or v_planned_sets > 2000
       or v_completed_sets < 0
       or v_completed_sets > v_planned_sets then
      raise exception 'Workout set counts are invalid';
    end if;
    if v_completion_percent < 0 or v_completion_percent > 100 then
      raise exception 'Workout completion percent is invalid';
    end if;
    if v_volume < 0 or v_volume > 1000000000000 then
      raise exception 'Workout volume is invalid';
    end if;
    if v_average_rir is not null
       and (v_average_rir < 0 or v_average_rir > 10) then
      raise exception 'Workout average RIR is invalid';
    end if;

    insert into public.stk_client_workout_summaries (
      client_user_id,
      workout_id,
      started_at,
      routine_name,
      duration_seconds,
      planned_working_sets,
      completed_working_sets,
      completion_percent,
      volume,
      average_rir,
      updated_at
    )
    values (
      v_user_id,
      v_workout_id,
      v_started_at,
      v_routine_name,
      v_duration_seconds,
      v_planned_sets,
      v_completed_sets,
      v_completion_percent,
      v_volume,
      v_average_rir,
      now()
    );
  end loop;
end;
$$;

create or replace function public.stk_get_client_progress(
  p_client_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_self boolean;
  v_relationship public.stk_coach_client_relationships%rowtype;
  v_can_view_workouts boolean := false;
  v_progress jsonb;
  v_workouts jsonb := '[]'::jsonb;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  v_is_self := v_user_id = p_client_user_id;

  if not v_is_self then
    select *
      into v_relationship
      from public.stk_coach_client_relationships
     where coach_user_id = v_user_id
       and client_user_id = p_client_user_id
       and status = 'active'
       and coalesce(
         (permissions ->> 'view_progress')::boolean,
         false
       )
     limit 1;

    if not found then
      raise exception 'Progress permission required';
    end if;

    v_can_view_workouts := coalesce(
      (v_relationship.permissions ->> 'view_workouts')::boolean,
      false
    );
  else
    v_can_view_workouts := true;
  end if;

  select pg_catalog.jsonb_build_object(
    'available', true,
    'client_user_id', snapshot.client_user_id,
    'workouts_7d', snapshot.workouts_7d,
    'workouts_30d', snapshot.workouts_30d,
    'training_minutes_7d', snapshot.training_minutes_7d,
    'completed_working_sets_7d', snapshot.completed_working_sets_7d,
    'volume_7d', snapshot.volume_7d,
    'average_rir_7d', snapshot.average_rir_7d,
    'last_workout_at', snapshot.last_workout_at,
    'generated_at', snapshot.generated_at,
    'trend_baseline_available', snapshot.trend_baseline_available,
    'workouts_previous_7d', snapshot.workouts_previous_7d,
    'training_minutes_previous_7d',
      snapshot.training_minutes_previous_7d,
    'completed_working_sets_previous_7d',
      snapshot.completed_working_sets_previous_7d,
    'volume_previous_7d', snapshot.volume_previous_7d,
    'updated_at', snapshot.updated_at
  )
  into v_progress
  from public.stk_client_progress_snapshots as snapshot
  where snapshot.client_user_id = p_client_user_id;

  if v_progress is null then
    v_progress := pg_catalog.jsonb_build_object(
      'available', false,
      'client_user_id', p_client_user_id
    );
  end if;

  if v_can_view_workouts then
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'workout_id', workout.workout_id,
          'started_at', workout.started_at,
          'routine_name', workout.routine_name,
          'duration_seconds', workout.duration_seconds,
          'planned_working_sets', workout.planned_working_sets,
          'completed_working_sets', workout.completed_working_sets,
          'completion_percent', workout.completion_percent,
          'volume', workout.volume,
          'average_rir', workout.average_rir
        )
        order by workout.started_at desc
      ),
      '[]'::jsonb
    )
    into v_workouts
    from (
      select *
      from public.stk_client_workout_summaries
      where client_user_id = p_client_user_id
      order by started_at desc
      limit 20
    ) as workout;
  end if;

  return pg_catalog.jsonb_build_object(
    'progress', v_progress,
    'recent_workouts', v_workouts,
    'workouts_visible', v_can_view_workouts
  );
end;
$$;

create or replace function public.stk_get_coach_pro_client_progress(
  p_relationship_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_coach uuid := auth.uid();
  v_relationship public.stk_coach_client_relationships%rowtype;
  v_snapshot public.stk_client_progress_snapshots%rowtype;
  v_snapshot_json jsonb;
  v_program public.stk_assigned_programs%rowtype;
  v_program_end_date date;
  v_reference_date date;
  v_scheduled_7d integer := 0;
  v_scheduled_30d integer := 0;
  v_percent_7d integer;
  v_percent_30d integer;
  v_adherence jsonb := null;
begin
  if v_coach is null
     or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if not exists (
    select 1
      from public.stk_user_capabilities
     where user_id = v_coach
       and capability = 'coach'
  ) then
    raise exception 'Coach capability required';
  end if;

  perform public.stk_assert_coach_pro_access(v_coach);

  select relationship.*
    into v_relationship
    from public.stk_coach_client_relationships as relationship
   where relationship.id = p_relationship_id
     and relationship.coach_user_id = v_coach
     and relationship.status = 'active'
     and coalesce(
       (relationship.permissions ->> 'view_progress')::boolean,
       false
     );

  if not found then
    raise exception 'Shared progress access unavailable';
  end if;

  select snapshot.*
    into v_snapshot
    from public.stk_client_progress_snapshots as snapshot
   where snapshot.client_user_id = v_relationship.client_user_id;

  if not found then
    return pg_catalog.jsonb_build_object(
      'relationship_id', p_relationship_id,
      'client_user_id', v_relationship.client_user_id,
      'snapshot', null,
      'adherence', null
    );
  end if;

  v_snapshot_json := pg_catalog.jsonb_build_object(
    'workouts_7d', v_snapshot.workouts_7d,
    'workouts_30d', v_snapshot.workouts_30d,
    'training_minutes_7d', v_snapshot.training_minutes_7d,
    'completed_working_sets_7d', v_snapshot.completed_working_sets_7d,
    'volume_7d', v_snapshot.volume_7d,
    'average_rir_7d', v_snapshot.average_rir_7d,
    'last_workout_at', v_snapshot.last_workout_at,
    'generated_at', v_snapshot.generated_at,
    'trend_baseline_available', v_snapshot.trend_baseline_available,
    'workouts_previous_7d', v_snapshot.workouts_previous_7d,
    'training_minutes_previous_7d',
      v_snapshot.training_minutes_previous_7d,
    'completed_working_sets_previous_7d',
      v_snapshot.completed_working_sets_previous_7d,
    'volume_previous_7d', v_snapshot.volume_previous_7d
  );

  if coalesce(
       (v_relationship.permissions ->> 'assign_programs')::boolean,
       false
     ) then
    select assignment.*
      into v_program
      from public.stk_assigned_programs as assignment
     where assignment.relationship_id = v_relationship.id
       and assignment.coach_user_id = v_coach
       and assignment.client_user_id = v_relationship.client_user_id
       and assignment.status = 'accepted'
     order by
       coalesce(assignment.accepted_at, assignment.updated_at) desc,
       assignment.updated_at desc,
       assignment.id
     limit 1;

    if found then
      v_reference_date := v_snapshot.generated_at::date;
      v_program_end_date :=
        v_program.starts_on + (v_program.duration_weeks * 7 - 1);

      if cardinality(v_program.training_weekdays) > 0 then
        select count(*)::integer
          into v_scheduled_7d
          from pg_catalog.generate_series(
            greatest(v_program.starts_on, v_reference_date - 6),
            least(v_program_end_date, v_reference_date),
            interval '1 day'
          ) as scheduled(day)
         where extract(isodow from scheduled.day)::smallint =
               any(v_program.training_weekdays);

        select count(*)::integer
          into v_scheduled_30d
          from pg_catalog.generate_series(
            greatest(v_program.starts_on, v_reference_date - 29),
            least(v_program_end_date, v_reference_date),
            interval '1 day'
          ) as scheduled(day)
         where extract(isodow from scheduled.day)::smallint =
               any(v_program.training_weekdays);
      end if;

      v_percent_7d := case
        when v_scheduled_7d = 0 then null
        else least(
          100,
          round(
            100.0 * least(v_snapshot.workouts_7d, v_scheduled_7d)
            / v_scheduled_7d
          )::integer
        )
      end;
      v_percent_30d := case
        when v_scheduled_30d = 0 then null
        else least(
          100,
          round(
            100.0 * least(v_snapshot.workouts_30d, v_scheduled_30d)
            / v_scheduled_30d
          )::integer
        )
      end;

      v_adherence := pg_catalog.jsonb_build_object(
        'assignment_id', v_program.id,
        'assignment_name', v_program.name,
        'starts_on', v_program.starts_on,
        'ends_on', v_program_end_date,
        'scheduled_sessions_7d', v_scheduled_7d,
        'completed_sessions_7d', v_snapshot.workouts_7d,
        'percent_7d', v_percent_7d,
        'scheduled_sessions_30d', v_scheduled_30d,
        'completed_sessions_30d', v_snapshot.workouts_30d,
        'percent_30d', v_percent_30d
      );
    end if;
  end if;

  return pg_catalog.jsonb_build_object(
    'relationship_id', p_relationship_id,
    'client_user_id', v_relationship.client_user_id,
    'snapshot', v_snapshot_json,
    'adherence', v_adherence
  );
end;
$$;

revoke all on function public.stk_sync_own_progress(jsonb, jsonb)
  from public, anon;
revoke all on function public.stk_get_client_progress(uuid)
  from public, anon;
revoke all on function public.stk_get_coach_pro_client_progress(uuid)
  from public, anon;

grant execute on function public.stk_sync_own_progress(jsonb, jsonb)
  to authenticated;
grant execute on function public.stk_get_client_progress(uuid)
  to authenticated;
grant execute on function public.stk_get_coach_pro_client_progress(uuid)
  to authenticated;

comment on function public.stk_get_coach_pro_client_progress(uuid) is
  'Coach Pro progress snapshot with client-computed previous-7-day trends. Frequency adherence is returned only when view_progress and assign_programs are both active, and compares scheduled weekdays with aggregate workout counts rather than exact routine matching.';
