-- Coach Pro Phase 2: global, permission-scoped portfolio overview.
-- Deliberately independent from the paginated roster. Never aggregate a page.
-- Kept in source control only; deployment to a remote project is separate.
create or replace function public.stk_get_coach_pro_portfolio_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_coach uuid := auth.uid();
  v_overview jsonb;
begin
  if v_coach is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (
    select 1 from public.stk_user_capabilities
    where user_id = v_coach and capability = 'coach'
  ) then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);

  with authorized as (
    select
      relationship.id,
      relationship.client_user_id,
      relationship.status,
      (relationship.status = 'active'
       and coalesce((relationship.permissions ->> 'view_progress')::boolean, false)
      ) as can_view_progress,
      (relationship.status = 'active'
       and coalesce((relationship.permissions ->> 'view_checkins')::boolean, false)
      ) as can_view_checkins,
      (relationship.status = 'active'
       and coalesce((relationship.permissions ->> 'assign_tasks')::boolean, false)
      ) as can_assign_tasks
    from public.stk_coach_client_relationships as relationship
    where relationship.coach_user_id = v_coach
      and relationship.status in ('active', 'paused')
  ),
  visible as (
    select
      authorized.*,
      progress.client_user_id is not null as progress_available,
      (authorized.can_view_progress and (
        progress.client_user_id is null
        or progress.last_workout_at is null
        or progress.last_workout_at < now() - interval '7 days'
      )) as needs_review,
      coalesce(tasks.active_count, 0::bigint) as active_task_count,
      checkins.latest_at
    from authorized
    left join public.stk_client_progress_snapshots as progress
      on authorized.can_view_progress
     and progress.client_user_id = authorized.client_user_id
    left join lateral (
      select count(*)::bigint as active_count
      from public.stk_coach_tasks as task
      where authorized.can_assign_tasks
        and task.relationship_id = authorized.id
        and task.coach_user_id = v_coach
        and task.client_user_id = authorized.client_user_id
        and task.status = 'active'
    ) as tasks on true
    left join lateral (
      select max(checkin.created_at) as latest_at
      from public.stk_coach_checkins as checkin
      where authorized.can_view_checkins
        and checkin.relationship_id = authorized.id
        and checkin.coach_user_id = v_coach
        and checkin.client_user_id = authorized.client_user_id
    ) as checkins on true
  )
  select pg_catalog.jsonb_build_object(
    'total_clients', count(*),
    'active_clients', count(*) filter (where status = 'active'),
    'paused_clients', count(*) filter (where status = 'paused'),
    'clients_with_shared_progress', count(*) filter (where progress_available),
    'clients_requiring_review', count(*) filter (where needs_review),
    'visible_active_tasks', coalesce(sum(active_task_count), 0),
    'clients_with_task_backlog', count(*) filter (where active_task_count > 0),
    'clients_with_recent_checkins', count(*) filter (
      where latest_at >= now() - interval '7 days'
    )
  )
  into v_overview
  from visible;

  return v_overview;
end;
$$;

revoke all on function public.stk_get_coach_pro_portfolio_overview()
  from public, anon;
grant execute on function public.stk_get_coach_pro_portfolio_overview()
  to authenticated;

comment on function public.stk_get_coach_pro_portfolio_overview() is
  'Whole-portfolio Coach Pro aggregates, not a client page: scoped to the signed-in coach and active entitlement. Protected progress, check-in and task counts are included only when the matching relationship is active and individually authorized.';

-- Follow-on Phase 2 roster contract: permission-safe adherence sorting.
-- The existing RPC's result columns and legacy signature stay unchanged.
-- Roadmap 4 / Fase 2: server-side roster filters and permission-safe sorting.
-- Apply only through an explicitly authorized deployment; CI is ephemeral.
create or replace function public.stk_list_coach_pro_clients(
  p_search text,
  p_limit integer,
  p_offset integer,
  p_status text,
  p_needs_review boolean,
  p_sort text
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
  v_status text := coalesce(p_status, 'all');
  v_sort text := coalesce(p_sort, 'review');
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

  if v_status not in ('all', 'active', 'paused') then
    raise exception 'Coach Pro relationship filter is invalid';
  end if;
  if v_sort not in ('review', 'name', 'recent_workout', 'adherence') then
    raise exception 'Coach Pro sort is invalid';
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
      ) as can_assign_tasks,
      (
        relationship.status = 'active'
        and coalesce(
          (relationship.permissions ->> 'assign_programs')::boolean,
          false
        )
      ) as can_assign_programs
    from public.stk_coach_client_relationships as relationship
    left join public.stk_user_profiles as profile
      on profile.user_id = relationship.client_user_id
    where relationship.coach_user_id = v_coach_user_id
      and relationship.status in ('active', 'paused')
      and (v_status = 'all' or relationship.status = v_status)
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
      adherence.percent_7d as adherence_percent_7d,
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
        and checkin.coach_user_id = v_coach_user_id
        and checkin.relationship_id = base.relationship_id
    ) as checkin on true
    left join lateral (
      select count(*)::bigint as active_task_count
      from public.stk_coach_tasks as task
      where base.can_assign_tasks
        and task.coach_user_id = v_coach_user_id
        and task.client_user_id = base.client_user_id
        and task.status = 'active'
    ) as task_count on true
    left join lateral (
      -- Match the detail RPC: latest accepted assignment and most recent
      -- accepted revision's calendar. Unshared data cannot influence ranking.
      select case when schedule.scheduled_7d > 0 then least(
        100, round(
          100.0 * least(progress.workouts_7d, schedule.scheduled_7d)
          / schedule.scheduled_7d
        )::integer
      ) else null end as percent_7d
      from public.stk_assigned_programs as assignment
      left join lateral (
        select revision.training_weekdays, revision.starts_on,
               revision.duration_weeks
        from public.stk_assigned_program_revision_acceptances as acceptance
        join public.stk_assigned_program_revisions as revision
          on revision.id = acceptance.revision_id
         and revision.assignment_id = acceptance.assignment_id
        where acceptance.assignment_id = assignment.id
          and acceptance.client_user_id = base.client_user_id
        order by revision.revision_number desc, acceptance.accepted_at desc
        limit 1
      ) as accepted_revision on true
      cross join lateral (
        select count(*)::integer as scheduled_7d
        from pg_catalog.generate_series(
          greatest(
            coalesce(accepted_revision.starts_on, assignment.starts_on),
            progress.generated_at::date - 6
          ),
          least(
            coalesce(accepted_revision.starts_on, assignment.starts_on)
              + (coalesce(accepted_revision.duration_weeks, assignment.duration_weeks) * 7 - 1),
            progress.generated_at::date
          ),
          interval '1 day'
        ) as scheduled(day)
        where extract(isodow from scheduled.day)::smallint =
          any(coalesce(accepted_revision.training_weekdays, assignment.training_weekdays))
      ) as schedule
      where v_sort = 'adherence'
        and base.can_view_progress and base.can_assign_programs
        and progress.client_user_id is not null
        and assignment.relationship_id = base.relationship_id
        and assignment.coach_user_id = v_coach_user_id
        and assignment.client_user_id = base.client_user_id
        and assignment.status = 'accepted'
      order by coalesce(assignment.accepted_at, assignment.updated_at) desc,
               assignment.updated_at desc, assignment.id
      limit 1
    ) as adherence on true
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
      then visible.active_task_count else null::bigint end,
    visible.needs_review,
    count(*) over () as total_count
  from visible
  where p_needs_review is null or visible.needs_review = p_needs_review
  order by
    case when v_sort = 'review' then visible.needs_review end desc,
    case when v_sort = 'review' then visible.last_workout_at end asc nulls first,
    case when v_sort = 'recent_workout' then visible.last_workout_at end desc nulls last,
    case when v_sort = 'adherence' then visible.adherence_percent_7d end asc nulls last,
    pg_catalog.lower(visible.display_name),
    visible.client_user_id
  limit v_limit
  offset v_offset;
end;
$$;


comment on function public.stk_list_coach_pro_clients(text, integer, integer, text, boolean, text) is
  'Roster sorted before pagination. Adherence ordering compares the accepted program schedule with consented aggregate workout counts, requires view_progress and assign_programs, and puts unavailable values last.';
