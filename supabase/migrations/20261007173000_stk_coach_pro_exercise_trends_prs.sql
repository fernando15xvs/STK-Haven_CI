-- Coach Pro Phase 2: exercise-level trend aggregates and PR context.
-- The client syncs bounded aggregates only. Raw sets and workout/exercise notes
-- are never persisted in this shared surface.
-- Coach reads require BOTH view_progress and view_workouts on the active
-- relationship, in addition to Coach Pro entitlement.

create table if not exists public.stk_client_exercise_progress_snapshots (
  client_user_id uuid not null
    references auth.users(id) on delete cascade,
  exercise_id text not null,
  exercise_name text not null,
  muscle_group text not null default '',
  last_performed_at timestamptz not null,
  generated_at timestamptz not null,
  sessions_30d integer not null
    check (sessions_30d between 0 and 1000),
  working_sets_30d integer not null
    check (working_sets_30d between 0 and 100000),
  volume_30d numeric(18,2) not null
    check (volume_30d between 0 and 1000000000000),
  average_rir_30d numeric(5,2)
    check (average_rir_30d is null or average_rir_30d between 0 and 10),
  sessions_previous_30d integer not null
    check (sessions_previous_30d between 0 and 1000),
  working_sets_previous_30d integer not null
    check (working_sets_previous_30d between 0 and 100000),
  volume_previous_30d numeric(18,2) not null
    check (volume_previous_30d between 0 and 1000000000000),
  best_estimated_1rm_30d numeric(12,3)
    check (
      best_estimated_1rm_30d is null
      or best_estimated_1rm_30d between 0 and 1000000
    ),
  best_estimated_1rm_previous_30d numeric(12,3)
    check (
      best_estimated_1rm_previous_30d is null
      or best_estimated_1rm_previous_30d between 0 and 1000000
    ),
  best_weight numeric(12,3)
    check (best_weight is null or best_weight between 0 and 1000000),
  best_weight_at timestamptz,
  best_estimated_1rm numeric(12,3)
    check (
      best_estimated_1rm is null
      or best_estimated_1rm between 0 and 1000000
    ),
  best_estimated_1rm_at timestamptz,
  best_set_volume numeric(18,2)
    check (
      best_set_volume is null
      or best_set_volume between 0 and 1000000000
    ),
  best_set_volume_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (client_user_id, exercise_id),
  check (char_length(exercise_id) between 1 and 120),
  check (char_length(exercise_name) between 1 and 160),
  check (char_length(muscle_group) <= 120),
  check ((best_weight is null) = (best_weight_at is null)),
  check (
    (best_estimated_1rm is null) = (best_estimated_1rm_at is null)
  ),
  check ((best_set_volume is null) = (best_set_volume_at is null))
);

create index if not exists
  stk_client_exercise_progress_recent_idx
on public.stk_client_exercise_progress_snapshots (
  client_user_id,
  last_performed_at desc,
  exercise_id
);

alter table public.stk_client_exercise_progress_snapshots
  enable row level security;

revoke all on public.stk_client_exercise_progress_snapshots
  from anon, authenticated;

create or replace function public.stk_sync_own_progress_v2(
  p_progress jsonb,
  p_recent_workouts jsonb,
  p_exercise_progress jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_item jsonb;
  v_count integer;
  v_exercise_id text;
  v_exercise_name text;
  v_muscle_group text;
  v_last_performed_at timestamptz;
  v_generated_at timestamptz;
  v_sessions_30d integer;
  v_working_sets_30d integer;
  v_volume_30d numeric;
  v_average_rir_30d numeric;
  v_sessions_previous_30d integer;
  v_working_sets_previous_30d integer;
  v_volume_previous_30d numeric;
  v_best_estimated_1rm_30d numeric;
  v_best_estimated_1rm_previous_30d numeric;
  v_best_weight numeric;
  v_best_weight_at timestamptz;
  v_best_estimated_1rm numeric;
  v_best_estimated_1rm_at timestamptz;
  v_best_set_volume numeric;
  v_best_set_volume_at timestamptz;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if pg_catalog.jsonb_typeof(p_exercise_progress) <> 'array' then
    raise exception 'Exercise progress payload must be an array';
  end if;

  v_count := pg_catalog.jsonb_array_length(p_exercise_progress);
  if v_count > 100 then
    raise exception 'At most 100 exercise progress rows may be synced';
  end if;

  -- Keep the existing aggregate/workout contract authoritative and backward
  -- compatible. Any validation failure below rolls this call back atomically.
  perform public.stk_sync_own_progress(p_progress, p_recent_workouts);

  delete from public.stk_client_exercise_progress_snapshots
   where client_user_id = v_user_id;

  for v_item in
    select value
      from pg_catalog.jsonb_array_elements(p_exercise_progress)
  loop
    if pg_catalog.jsonb_typeof(v_item) <> 'object' then
      raise exception 'Exercise progress row must be an object';
    end if;

    v_exercise_id := btrim(coalesce(v_item ->> 'exercise_id', ''));
    v_exercise_name := btrim(coalesce(v_item ->> 'exercise_name', ''));
    v_muscle_group := btrim(coalesce(v_item ->> 'muscle_group', ''));
    v_last_performed_at :=
      (v_item ->> 'last_performed_at')::timestamptz;
    v_generated_at := (v_item ->> 'generated_at')::timestamptz;
    v_sessions_30d := (v_item ->> 'sessions_30d')::integer;
    v_working_sets_30d := (v_item ->> 'working_sets_30d')::integer;
    v_volume_30d := (v_item ->> 'volume_30d')::numeric;
    v_average_rir_30d := (v_item ->> 'average_rir_30d')::numeric;
    v_sessions_previous_30d :=
      (v_item ->> 'sessions_previous_30d')::integer;
    v_working_sets_previous_30d :=
      (v_item ->> 'working_sets_previous_30d')::integer;
    v_volume_previous_30d :=
      (v_item ->> 'volume_previous_30d')::numeric;
    v_best_estimated_1rm_30d :=
      (v_item ->> 'best_estimated_1rm_30d')::numeric;
    v_best_estimated_1rm_previous_30d :=
      (v_item ->> 'best_estimated_1rm_previous_30d')::numeric;
    v_best_weight := (v_item ->> 'best_weight')::numeric;
    v_best_weight_at := (v_item ->> 'best_weight_at')::timestamptz;
    v_best_estimated_1rm :=
      (v_item ->> 'best_estimated_1rm')::numeric;
    v_best_estimated_1rm_at :=
      (v_item ->> 'best_estimated_1rm_at')::timestamptz;
    v_best_set_volume := (v_item ->> 'best_set_volume')::numeric;
    v_best_set_volume_at :=
      (v_item ->> 'best_set_volume_at')::timestamptz;

    if char_length(v_exercise_id) < 1
       or char_length(v_exercise_id) > 120
       or char_length(v_exercise_name) < 1
       or char_length(v_exercise_name) > 160
       or char_length(v_muscle_group) > 120 then
      raise exception 'Exercise progress identity is invalid';
    end if;

    if v_last_performed_at is null
       or v_generated_at is null
       or v_last_performed_at > now() + interval '1 day'
       or v_generated_at > now() + interval '1 day' then
      raise exception 'Exercise progress timestamp is invalid';
    end if;

    if v_sessions_30d < 0 or v_sessions_30d > 1000
       or v_sessions_previous_30d < 0
       or v_sessions_previous_30d > 1000
       or v_working_sets_30d < 0
       or v_working_sets_30d > 100000
       or v_working_sets_previous_30d < 0
       or v_working_sets_previous_30d > 100000 then
      raise exception 'Exercise progress counts are invalid';
    end if;

    if v_volume_30d < 0 or v_volume_30d > 1000000000000
       or v_volume_previous_30d < 0
       or v_volume_previous_30d > 1000000000000 then
      raise exception 'Exercise progress volume is invalid';
    end if;

    if v_average_rir_30d is not null
       and (v_average_rir_30d < 0 or v_average_rir_30d > 10) then
      raise exception 'Exercise progress RIR is invalid';
    end if;

    if v_best_estimated_1rm_30d is not null
       and (
         v_best_estimated_1rm_30d < 0
         or v_best_estimated_1rm_30d > 1000000
       ) then
      raise exception 'Exercise 1RM trend is invalid';
    end if;

    if v_best_estimated_1rm_previous_30d is not null
       and (
         v_best_estimated_1rm_previous_30d < 0
         or v_best_estimated_1rm_previous_30d > 1000000
       ) then
      raise exception 'Exercise previous 1RM trend is invalid';
    end if;

    if v_best_weight is not null
       and (v_best_weight < 0 or v_best_weight > 1000000) then
      raise exception 'Exercise weight PR is invalid';
    end if;

    if v_best_estimated_1rm is not null
       and (
         v_best_estimated_1rm < 0
         or v_best_estimated_1rm > 1000000
       ) then
      raise exception 'Exercise estimated 1RM PR is invalid';
    end if;

    if v_best_set_volume is not null
       and (
         v_best_set_volume < 0
         or v_best_set_volume > 1000000000
       ) then
      raise exception 'Exercise set-volume PR is invalid';
    end if;

    if (v_best_weight is null) <> (v_best_weight_at is null)
       or (v_best_estimated_1rm is null)
          <> (v_best_estimated_1rm_at is null)
       or (v_best_set_volume is null)
          <> (v_best_set_volume_at is null) then
      raise exception 'Exercise PR timestamp is invalid';
    end if;

    if v_best_weight_at > now() + interval '1 day'
       or v_best_estimated_1rm_at > now() + interval '1 day'
       or v_best_set_volume_at > now() + interval '1 day' then
      raise exception 'Exercise PR timestamp is invalid';
    end if;

    insert into public.stk_client_exercise_progress_snapshots (
      client_user_id,
      exercise_id,
      exercise_name,
      muscle_group,
      last_performed_at,
      generated_at,
      sessions_30d,
      working_sets_30d,
      volume_30d,
      average_rir_30d,
      sessions_previous_30d,
      working_sets_previous_30d,
      volume_previous_30d,
      best_estimated_1rm_30d,
      best_estimated_1rm_previous_30d,
      best_weight,
      best_weight_at,
      best_estimated_1rm,
      best_estimated_1rm_at,
      best_set_volume,
      best_set_volume_at,
      updated_at
    )
    values (
      v_user_id,
      v_exercise_id,
      v_exercise_name,
      v_muscle_group,
      v_last_performed_at,
      v_generated_at,
      v_sessions_30d,
      v_working_sets_30d,
      v_volume_30d,
      v_average_rir_30d,
      v_sessions_previous_30d,
      v_working_sets_previous_30d,
      v_volume_previous_30d,
      v_best_estimated_1rm_30d,
      v_best_estimated_1rm_previous_30d,
      v_best_weight,
      v_best_weight_at,
      v_best_estimated_1rm,
      v_best_estimated_1rm_at,
      v_best_set_volume,
      v_best_set_volume_at,
      now()
    );
  end loop;
end;
$$;

create or replace function public.stk_list_coach_pro_client_exercise_progress(
  p_relationship_id uuid,
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
  v_coach uuid := auth.uid();
  v_relationship public.stk_coach_client_relationships%rowtype;
  v_limit integer := coalesce(p_limit, 25);
  v_offset integer := coalesce(p_offset, 0);
  v_items jsonb;
  v_total bigint;
begin
  if v_coach is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if v_limit < 1 or v_limit > 100 then
    raise exception 'Exercise progress page limit must be between 1 and 100';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception 'Exercise progress page offset is invalid';
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
     )
     and coalesce(
       (relationship.permissions ->> 'view_workouts')::boolean,
       false
     );

  if not found then
    raise exception 'Exercise progress access unavailable';
  end if;

  with permitted as (
    select
      snapshot.client_user_id,
      snapshot.exercise_id,
      snapshot.exercise_name,
      snapshot.muscle_group,
      snapshot.last_performed_at,
      snapshot.generated_at,
      snapshot.sessions_30d,
      snapshot.working_sets_30d,
      snapshot.volume_30d,
      snapshot.average_rir_30d,
      snapshot.sessions_previous_30d,
      snapshot.working_sets_previous_30d,
      snapshot.volume_previous_30d,
      snapshot.best_estimated_1rm_30d,
      snapshot.best_estimated_1rm_previous_30d,
      snapshot.best_weight,
      snapshot.best_weight_at,
      snapshot.best_estimated_1rm,
      snapshot.best_estimated_1rm_at,
      snapshot.best_set_volume,
      snapshot.best_set_volume_at
    from public.stk_client_exercise_progress_snapshots as snapshot
    where snapshot.client_user_id = v_relationship.client_user_id
  ), page as (
    select *
      from permitted
     order by last_performed_at desc, exercise_id
     limit v_limit
     offset v_offset
  )
  select
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.to_jsonb(item)
          order by item.last_performed_at desc, item.exercise_id
        )
        from page as item
      ),
      '[]'::jsonb
    ),
    (select count(*) from permitted)
  into v_items, v_total;

  return pg_catalog.jsonb_build_object(
    'relationship_id', p_relationship_id,
    'client_user_id', v_relationship.client_user_id,
    'items', v_items,
    'total_count', v_total
  );
end;
$$;

revoke all on function public.stk_sync_own_progress_v2(
  jsonb, jsonb, jsonb
) from public, anon, authenticated;
revoke all on function public.stk_list_coach_pro_client_exercise_progress(
  uuid, integer, integer
) from public, anon, authenticated;

grant execute on function public.stk_sync_own_progress_v2(
  jsonb, jsonb, jsonb
) to authenticated;
grant execute on function public.stk_list_coach_pro_client_exercise_progress(
  uuid, integer, integer
) to authenticated;

comment on table public.stk_client_exercise_progress_snapshots is
  'Bounded client-computed exercise aggregates for Coach Pro trends and PR context. Raw sets and notes are intentionally excluded; direct client/coach table access is disabled.';
comment on function public.stk_sync_own_progress_v2(jsonb, jsonb, jsonb) is
  'Backward-compatible progress sync extension that atomically replaces up to 100 aggregate exercise trend rows for the authenticated client.';
comment on function public.stk_list_coach_pro_client_exercise_progress(uuid, integer, integer) is
  'Paginated Coach Pro exercise aggregates. Requires Coach Pro plus active relationship permissions view_progress AND view_workouts; returns no raw sets or notes.';
