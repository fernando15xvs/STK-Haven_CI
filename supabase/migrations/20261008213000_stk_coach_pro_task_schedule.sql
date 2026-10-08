-- Coach Pro Phase 3: bounded, permission-scoped schedule preview.
-- Virtual due dates do not create task occurrences or imply failure to train.
create or replace function public.stk_list_coach_pro_task_schedule(
  p_relationship_id uuid,
  p_start_on date default current_date,
  p_days integer default 14,
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
  v_client uuid;
  v_total bigint;
  v_items jsonb;
begin
  if v_coach is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (
    select 1 from public.stk_user_capabilities
    where user_id=v_coach and capability='coach'
  ) then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  if p_start_on is null
     or p_start_on < current_date - 30
     or p_start_on > current_date + 90
     or p_days is null or p_days not between 1 and 14
     or p_limit is null or p_limit not between 1 and 50
     or p_offset is null or p_offset not between 0 and 10000 then
    raise exception 'Invalid task schedule page';
  end if;

  select relation.client_user_id into v_client
  from public.stk_coach_client_relationships relation
  where relation.id=p_relationship_id
    and relation.coach_user_id=v_coach
    and relation.status='active'
    and coalesce((relation.permissions ->> 'assign_tasks')::boolean,false);
  if not found then
    raise exception 'Active task assignment permission required';
  end if;

  -- Only count authorized tasks for this exact relationship and coach.
  with due as (
    select task.id as task_id,
           task.title,
           task.task_type,
           task.target_minutes,
           calendar.day::date as due_on,
           occurrence.status,
           occurrence.minutes_spent
    from public.stk_coach_tasks task
    cross join lateral pg_catalog.generate_series(
      p_start_on::timestamp,
      (p_start_on + (p_days - 1))::timestamp,
      interval '1 day'
    ) as calendar(day)
    left join public.stk_coach_task_occurrences occurrence
      on occurrence.task_id=task.id
      and occurrence.client_user_id=v_client
      and occurrence.occurrence_date=calendar.day::date
    where task.relationship_id=p_relationship_id
      and task.coach_user_id=v_coach
      and task.client_user_id=v_client
      and task.status='active'
      and public.stk_task_due_on(task,calendar.day::date)
  ),
  total as (
    select count(*) as value from due
  ),
  page as (
    select * from due
    order by due_on, pg_catalog.lower(title), task_id
    limit p_limit offset p_offset
  )
  select total.value,
         coalesce(
           (select pg_catalog.jsonb_agg(
             pg_catalog.jsonb_build_object(
               'task_id',page.task_id,
               'title',page.title,
               'task_type',page.task_type,
               'target_minutes',page.target_minutes,
               'due_on',page.due_on,
               'status',page.status,
               'minutes_spent',page.minutes_spent
             ) order by page.due_on,pg_catalog.lower(page.title),page.task_id
           ) from page),
           '[]'::jsonb
         )
    into v_total,v_items
  from total;

  return pg_catalog.jsonb_build_object(
    'relationship_id',p_relationship_id,
    'start_on',p_start_on,
    'days',p_days,
    'total_count',coalesce(v_total,0),
    'items',v_items
  );
end;
$$;

revoke all on function public.stk_list_coach_pro_task_schedule(uuid,date,integer,integer,integer)
  from public,anon,authenticated;
grant execute on function public.stk_list_coach_pro_task_schedule(uuid,date,integer,integer,integer)
  to authenticated;
comment on function public.stk_list_coach_pro_task_schedule(uuid,date,integer,integer,integer)
  is 'Coach-only authorized 14-day maximum virtual task schedule, pages of 50 maximum; no inferred missed activity.';
