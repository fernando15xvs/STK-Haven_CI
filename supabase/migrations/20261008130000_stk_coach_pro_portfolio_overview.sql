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
