-- Roadmap 4.0 / Fase 2 foundation
-- Aggregated, paginated Coach Pro client dashboard.
-- No remote deployment is performed by this migration file.

create or replace function public.stk_list_coach_pro_clients(
  p_search text default null,
  p_limit integer default 25,
  p_offset integer default 0
)
returns table (
  relationship_id uuid,
  client_user_id uuid,
  display_name text,
  relationship_status text,
  permissions jsonb,
  relationship_updated_at timestamptz,
  progress_available boolean,
  workouts_7d integer,
  workouts_30d integer,
  average_rir_7d numeric,
  last_workout_at timestamptz,
  latest_checkin_at timestamptz,
  active_task_count bigint,
  needs_review boolean,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_coach_user_id uuid := auth.uid();
  v_search text := btrim(coalesce(p_search, ''));
  v_limit integer := coalesce(p_limit, 25);
  v_offset integer := coalesce(p_offset, 0);
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

  if char_length(v_search) > 80 then
    raise exception 'Coach Pro search is too long';
  end if;
  if v_limit < 1 or v_limit > 100 then
    raise exception 'Coach Pro page limit must be between 1 and 100';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception 'Coach Pro page offset is invalid';
  end if;

  return query
  with base as (
    select
      relationship.id as relationship_id,
      relationship.client_user_id,
      coalesce(nullif(btrim(profile.display_name), ''), 'Cliente') as display_name,
      relationship.status as relationship_status,
      relationship.permissions,
      relationship.updated_at as relationship_updated_at,
      (
        relationship.status = 'active'
        and coalesce(
          (relationship.permissions ->> 'view_progress')::boolean,
          false
        )
      ) as can_view_progress,
      (
        relationship.status = 'active'
        and coalesce(
          (relationship.permissions ->> 'view_checkins')::boolean,
          false
        )
      ) as can_view_checkins,
      (
        relationship.status = 'active'
        and coalesce(
          (relationship.permissions ->> 'assign_tasks')::boolean,
          false
        )
      ) as can_assign_tasks
    from public.stk_coach_client_relationships as relationship
    left join public.stk_user_profiles as profile
      on profile.user_id = relationship.client_user_id
    where relationship.coach_user_id = v_coach_user_id
      and relationship.status in ('active', 'paused')
      and (
        v_search = ''
        or pg_catalog.strpos(
          pg_catalog.lower(
            coalesce(nullif(btrim(profile.display_name), ''), 'Cliente')
          ),
          pg_catalog.lower(v_search)
        ) > 0
      )
  ),
  visible as (
    select
      base.*,
      progress.client_user_id is not null as progress_available,
      progress.workouts_7d,
      progress.workouts_30d,
      progress.average_rir_7d,
      progress.last_workout_at,
      checkin.latest_checkin_at,
      coalesce(task_count.active_task_count, 0::bigint) as active_task_count,
      (
        base.can_view_progress
        and (
          progress.client_user_id is null
          or progress.last_workout_at is null
          or progress.last_workout_at < now() - interval '7 days'
        )
      ) as needs_review
    from base
    left join public.stk_client_progress_snapshots as progress
      on progress.client_user_id = base.client_user_id
     and base.can_view_progress
    left join lateral (
      select max(checkin.created_at) as latest_checkin_at
      from public.stk_coach_checkins as checkin
      where base.can_view_checkins
        and checkin.client_user_id = base.client_user_id
    ) as checkin on true
    left join lateral (
      select count(*)::bigint as active_task_count
      from public.stk_coach_tasks as task
      where base.can_assign_tasks
        and task.coach_user_id = v_coach_user_id
        and task.client_user_id = base.client_user_id
        and task.status = 'active'
    ) as task_count on true
  )
  select
    visible.relationship_id,
    visible.client_user_id,
    visible.display_name,
    visible.relationship_status,
    visible.permissions,
    visible.relationship_updated_at,
    visible.progress_available,
    case when visible.can_view_progress
      then visible.workouts_7d else null end,
    case when visible.can_view_progress
      then visible.workouts_30d else null end,
    case when visible.can_view_progress
      then visible.average_rir_7d else null end,
    case when visible.can_view_progress
      then visible.last_workout_at else null end,
    case when visible.can_view_checkins
      then visible.latest_checkin_at else null end,
    case when visible.can_assign_tasks
      then visible.active_task_count else 0::bigint end,
    visible.needs_review,
    count(*) over () as total_count
  from visible
  order by
    visible.needs_review desc,
    visible.last_workout_at asc nulls first,
    pg_catalog.lower(visible.display_name),
    visible.client_user_id
  limit v_limit
  offset v_offset;
end;
$$;

revoke all on function public.stk_list_coach_pro_clients(text, integer, integer)
  from public, anon;
grant execute on function public.stk_list_coach_pro_clients(text, integer, integer)
  to authenticated;

comment on function public.stk_list_coach_pro_clients(text, integer, integer) is
  'Coach Pro paginated roster. Protected aggregates are emitted only when the active relationship grants the corresponding permission.';
