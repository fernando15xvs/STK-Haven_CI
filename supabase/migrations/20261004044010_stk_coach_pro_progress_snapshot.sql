-- Read one existing shared progress snapshot, without pulling adjacent protected datasets.
create or replace function public.stk_get_coach_pro_client_progress(p_relationship_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_coach uuid := auth.uid();
  v_client uuid;
  v_snapshot jsonb;
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
      and coalesce((r.permissions->>'view_progress')::boolean,false);
  if not found then raise exception 'Shared progress access unavailable'; end if;
  select jsonb_build_object('workouts_7d',s.workouts_7d,'workouts_30d',s.workouts_30d,
    'training_minutes_7d',s.training_minutes_7d,'completed_working_sets_7d',s.completed_working_sets_7d,
    'volume_7d',s.volume_7d,'average_rir_7d',s.average_rir_7d,
    'last_workout_at',s.last_workout_at,'generated_at',s.generated_at)
    into v_snapshot from public.stk_client_progress_snapshots s where s.client_user_id=v_client;
  return jsonb_build_object('relationship_id',p_relationship_id,'client_user_id',v_client,
    'snapshot',v_snapshot);
end;
$$;
revoke all on function public.stk_get_coach_pro_client_progress(uuid) from public,anon;
grant execute on function public.stk_get_coach_pro_client_progress(uuid) to authenticated;
-- Missing snapshot remains JSON null. Periods refer to generated_at; no live recomputation or invented trends.
