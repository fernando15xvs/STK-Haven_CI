-- Coach Pro read-only program pages; one version and one selected routine per request.
create or replace function public.stk_get_coach_pro_program_page(
  p_relationship_id uuid, p_assignment_id uuid, p_version integer,
  p_routine_id uuid default null, p_limit integer default 25, p_offset integer default 0
)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_coach uuid := auth.uid();
  v_program public.stk_assigned_programs%rowtype;
  v_routine jsonb := null;
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
  select a.* into v_program
    from public.stk_assigned_programs a
    join public.stk_coach_client_relationships r on r.id=a.relationship_id
    where a.id=p_assignment_id and r.id=p_relationship_id
      and a.coach_user_id=v_coach and r.coach_user_id=v_coach
      and a.client_user_id=r.client_user_id and r.status='active'
      and coalesce((r.permissions->>'assign_programs')::boolean,false);
  if not found then raise exception 'Assigned program access unavailable'; end if;
  if p_version is distinct from v_program.version then
    raise exception 'Assigned program version changed; reload';
  end if;
  if v_limit < 1 or v_limit > 100 then
    raise exception 'Coach Pro page limit must be between 1 and 100';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception 'Coach Pro page offset is invalid';
  end if;
  if p_routine_id is null then
    with permitted as (
      select r.id,r.position,r.name
      from public.stk_assigned_program_routines r where r.assignment_id=v_program.id
    ), page as (select * from permitted order by position,id limit v_limit offset v_offset)
    select coalesce((select jsonb_agg(to_jsonb(p) order by p.position,p.id) from page p),'[]'::jsonb),
      (select count(*) from permitted) into v_items,v_total;
  else
    select jsonb_build_object('id',r.id,'name',r.name,'position',r.position)
      into v_routine from public.stk_assigned_program_routines r
      where r.id=p_routine_id and r.assignment_id=v_program.id;
    if not found then raise exception 'Assigned program access unavailable'; end if;
    with permitted as (
      select e.id,e.position,e.exercise_name as name,e.muscle_group,e.equipment,
        e.target_sets,e.target_reps_min,e.target_reps_max,e.rest_seconds,
        e.warmup_sets,e.approach_sets,e.unilateral,e.unilateral_target,e.superset_key
      from public.stk_assigned_program_exercises e
      join public.stk_assigned_program_routines r on r.id=e.routine_id
      where r.assignment_id=v_program.id and r.id=p_routine_id
    ), page as (select * from permitted order by position,id limit v_limit offset v_offset)
    select coalesce((select jsonb_agg(to_jsonb(p) order by p.position,p.id) from page p),'[]'::jsonb),
      (select count(*) from permitted) into v_items,v_total;
  end if;
  return jsonb_build_object('assignment_id',v_program.id,'relationship_id',v_program.relationship_id,
    'name',v_program.name,'version',v_program.version,'status',v_program.status,
    'routine',v_routine,'items',v_items,'total_count',v_total);
end;
$$;
revoke all on function public.stk_get_coach_pro_program_page(uuid,uuid,integer,uuid,integer,integer) from public,anon;
grant execute on function public.stk_get_coach_pro_program_page(uuid,uuid,integer,uuid,integer,integer) to authenticated;
-- Existing unique (assignment_id,position) and (routine_id,position) indexes support both pages.
