-- Read-only Coach Pro task and finalized occurrence history, bounded by relationship.
create or replace function public.stk_get_coach_pro_task_page(
  p_relationship_id uuid, p_task_id uuid,
  p_limit integer default 25, p_offset integer default 0
)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_coach uuid := auth.uid();
  v_task public.stk_coach_tasks%rowtype;
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
  select t.* into v_task
    from public.stk_coach_tasks t
    join public.stk_coach_client_relationships r on r.id=t.relationship_id
    where t.id=p_task_id and r.id=p_relationship_id
      and t.coach_user_id=v_coach and r.coach_user_id=v_coach
      and t.client_user_id=r.client_user_id and r.status='active'
      and coalesce((r.permissions->>'assign_tasks')::boolean,false);
  if not found then raise exception 'Assigned task access unavailable'; end if;
  if v_limit < 1 or v_limit > 100 then
    raise exception 'Coach Pro page limit must be between 1 and 100';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception 'Coach Pro page offset is invalid';
  end if;
  with permitted as (
    select o.id,o.task_id,o.client_user_id,o.occurrence_date,o.status,
      o.minutes_spent,o.completed_at,o.created_at
    from public.stk_coach_task_occurrences o
    where o.task_id=v_task.id and o.client_user_id=v_task.client_user_id
  ), page as (
    select * from permitted order by occurrence_date desc,id limit v_limit offset v_offset
  )
  select coalesce((select jsonb_agg(to_jsonb(p) order by p.occurrence_date desc,p.id) from page p),'[]'::jsonb),
    (select count(*) from permitted) into v_items,v_total;
  return jsonb_build_object('task',jsonb_build_object(
    'id',v_task.id,'relationship_id',v_task.relationship_id,
    'coach_user_id',v_task.coach_user_id,'client_user_id',v_task.client_user_id,
    'title',v_task.title,'category',v_task.category,'task_type',v_task.task_type,
    'target_minutes',v_task.target_minutes,'recurrence_type',v_task.recurrence_type,
    'weekdays',v_task.weekdays,'starts_on',v_task.starts_on,'due_at',v_task.due_at,
    'ends_on',v_task.ends_on,'coach_instructions',v_task.coach_instructions,
    'status',v_task.status,'created_at',v_task.created_at,'updated_at',v_task.updated_at),
    'items',v_items,'total_count',v_total);
end;
$$;
revoke all on function public.stk_get_coach_pro_task_page(uuid,uuid,integer,integer) from public,anon;
grant execute on function public.stk_get_coach_pro_task_page(uuid,uuid,integer,integer) to authenticated;
-- Reuses stk_coach_task_occurrences_task_date_idx (task_id, occurrence_date desc).
-- Does not mutate history, infer missing days or return comments/private notes.
