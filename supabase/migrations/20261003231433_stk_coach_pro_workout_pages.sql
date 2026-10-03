-- Paginated view of the client's existing shared recent summaries, not full workout history.
create or replace function public.stk_list_coach_pro_client_workouts(
  p_relationship_id uuid, p_limit integer default 25, p_offset integer default 0
)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_coach uuid := auth.uid();
  v_client uuid;
  v_limit integer := coalesce(p_limit,25);
  v_offset integer := coalesce(p_offset,0);
  v_items jsonb;
  v_total bigint;
begin
  if v_coach is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities
    where user_id=v_coach and capability='coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  select r.client_user_id into v_client
    from public.stk_coach_client_relationships r
    where r.id=p_relationship_id and r.coach_user_id=v_coach and r.status='active'
      and coalesce((r.permissions->>'view_workouts')::boolean,false);
  if not found then raise exception 'Shared workouts access unavailable'; end if;
  if v_limit < 1 or v_limit > 100 then
    raise exception 'Coach Pro page limit must be between 1 and 100';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception 'Coach Pro page offset is invalid';
  end if;
  with permitted as (
    select w.client_user_id,w.workout_id,w.started_at,w.routine_name,w.duration_seconds,
      w.planned_working_sets,w.completed_working_sets,w.completion_percent,w.volume,w.average_rir
    from public.stk_client_workout_summaries w where w.client_user_id=v_client
  ), page as (
    select * from permitted order by started_at desc,workout_id limit v_limit offset v_offset
  )
  select coalesce((select jsonb_agg(to_jsonb(p) order by p.started_at desc,p.workout_id) from page p),'[]'::jsonb),
    (select count(*) from permitted) into v_items,v_total;
  return jsonb_build_object('relationship_id',p_relationship_id,'client_user_id',v_client,
    'items',v_items,'total_count',v_total);
end;
$$;
revoke all on function public.stk_list_coach_pro_client_workouts(uuid,integer,integer) from public,anon;
grant execute on function public.stk_list_coach_pro_client_workouts(uuid,integer,integer) to authenticated;
-- Uses stk_client_workout_summaries_recent_idx. Does not change the 30-summary sync contract.
