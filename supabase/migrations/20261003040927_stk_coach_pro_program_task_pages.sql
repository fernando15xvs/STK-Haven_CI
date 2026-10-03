-- Coach Pro: bounded program and task summaries, scoped to one relationship.
create or replace function public.stk_list_coach_pro_client_programs(
  p_relationship_id uuid, p_limit integer default 25, p_offset integer default 0
)
returns table (
  id uuid, relationship_id uuid, coach_user_id uuid, client_user_id uuid,
  name text, duration_weeks integer, training_weekdays smallint[], starts_on date,
  status text, version integer, created_at timestamptz, accepted_at timestamptz,
  updated_at timestamptz, total_count bigint
)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_coach_user_id uuid := auth.uid();
  v_limit integer := coalesce(p_limit, 25);
  v_offset integer := coalesce(p_offset, 0);
  v_client_user_id uuid;
begin
  if v_coach_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities
      where user_id=v_coach_user_id and capability='coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach_user_id);
  select r.client_user_id into v_client_user_id
    from public.stk_coach_client_relationships r
    where r.id=p_relationship_id and r.coach_user_id=v_coach_user_id
      and r.status='active'
      and coalesce((r.permissions->>'assign_programs')::boolean, false);
  if v_client_user_id is null then
    raise exception 'Client programs access unavailable';
  end if;
  if v_limit < 1 or v_limit > 100 then
    raise exception 'Coach Pro page limit must be between 1 and 100';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception 'Coach Pro page offset is invalid';
  end if;
  return query
    select c.id, c.relationship_id, c.coach_user_id, c.client_user_id,
      c.name, c.duration_weeks, c.training_weekdays, c.starts_on,
      c.status, c.version, c.created_at, c.accepted_at, c.updated_at, count(*) over ()
    from public.stk_assigned_programs c
    where c.relationship_id=p_relationship_id
      and c.coach_user_id=v_coach_user_id and c.client_user_id=v_client_user_id
    order by c.updated_at desc, c.id
    limit v_limit offset v_offset;
end;
$$;
revoke all on function public.stk_list_coach_pro_client_programs(uuid, integer, integer)
  from public, anon;
grant execute on function public.stk_list_coach_pro_client_programs(uuid, integer, integer)
  to authenticated;

create index if not exists stk_assigned_programs_relationship_updated_idx
  on public.stk_assigned_programs (relationship_id, updated_at desc, id);

create or replace function public.stk_list_coach_pro_client_tasks(
  p_relationship_id uuid, p_limit integer default 25, p_offset integer default 0
)
returns table (
  id uuid, relationship_id uuid, title text, category text,
  status text, starts_on date, due_at timestamptz, updated_at timestamptz,
  total_count bigint
)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_coach_user_id uuid := auth.uid();
  v_limit integer := coalesce(p_limit, 25);
  v_offset integer := coalesce(p_offset, 0);
  v_client_user_id uuid;
begin
  if v_coach_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities
      where user_id=v_coach_user_id and capability='coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach_user_id);
  select r.client_user_id into v_client_user_id
    from public.stk_coach_client_relationships r
    where r.id=p_relationship_id and r.coach_user_id=v_coach_user_id
      and r.status='active'
      and coalesce((r.permissions->>'assign_tasks')::boolean, false);
  if v_client_user_id is null then
    raise exception 'Client tasks access unavailable';
  end if;
  if v_limit < 1 or v_limit > 100 then
    raise exception 'Coach Pro page limit must be between 1 and 100';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception 'Coach Pro page offset is invalid';
  end if;
  return query
    select c.id, c.relationship_id, c.title, c.category,
      c.status, c.starts_on, c.due_at, c.updated_at, count(*) over ()
    from public.stk_coach_tasks c
    where c.relationship_id=p_relationship_id
      and c.coach_user_id=v_coach_user_id and c.client_user_id=v_client_user_id
    order by c.updated_at desc, c.id
    limit v_limit offset v_offset;
end;
$$;
revoke all on function public.stk_list_coach_pro_client_tasks(uuid, integer, integer)
  from public, anon;
grant execute on function public.stk_list_coach_pro_client_tasks(uuid, integer, integer)
  to authenticated;

create index if not exists stk_coach_tasks_relationship_updated_idx
  on public.stk_coach_tasks (relationship_id, updated_at desc, id);

