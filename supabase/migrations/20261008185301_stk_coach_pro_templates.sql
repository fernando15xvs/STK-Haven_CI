-- Coach Pro Phase 3 / professional programming: owner-scoped program templates.
-- No personally identifying client fields or coach/client relationship identifiers
-- are stored in a template. Each assignment creates fresh normalized rows.
create table if not exists public.stk_coach_pro_templates (
  id uuid primary key default gen_random_uuid(),
  coach_user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  program jsonb not null,
  status text not null default 'active'
    check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stk_coach_template_payload check (
    pg_catalog.jsonb_typeof(program) = 'object'
    and pg_catalog.jsonb_typeof(program -> 'routines') = 'array'
    and pg_catalog.jsonb_array_length(program -> 'routines') between 1 and 20
    and pg_catalog.octet_length(program::text) <= 300000
  )
);
create index if not exists stk_coach_templates_owner_idx
  on public.stk_coach_pro_templates (coach_user_id, status, created_at desc, id desc);
alter table public.stk_coach_pro_templates enable row level security;
-- Never expose raw snapshot data via PostgREST tables or default PUBLIC grants.
revoke all on public.stk_coach_pro_templates from public, anon, authenticated;

create or replace function public.stk_save_coach_pro_template_from_revision(
  p_relationship_id uuid,
  p_assignment_id uuid,
  p_revision_id uuid,
  p_title text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coach uuid := auth.uid();
  v_title text := btrim(coalesce(p_title, ''));
  v_revision public.stk_assigned_program_revisions%rowtype;
  v_program jsonb;
  v_template_id uuid;
begin
  if v_coach is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities
                 where user_id = v_coach and capability = 'coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  if char_length(v_title) not between 1 and 120 then
    raise exception 'Template title length is invalid';
  end if;
  if not exists (
    select 1
      from public.stk_coach_client_relationships relation
      join public.stk_assigned_programs assignment
        on assignment.relationship_id = relation.id
       and assignment.id = p_assignment_id
       and assignment.coach_user_id = v_coach
       and assignment.client_user_id = relation.client_user_id
     where relation.id = p_relationship_id
       and relation.coach_user_id = v_coach
       and relation.status = 'active'
       and coalesce((relation.permissions ->> 'assign_programs')::boolean, false)
  ) then
    raise exception 'Active program assignment permission required';
  end if;
  select revision.* into v_revision
    from public.stk_assigned_program_revisions revision
   where revision.id = p_revision_id and revision.assignment_id = p_assignment_id;
  if not found then
    raise exception 'Program revision unavailable';
  end if;

  -- Reconstruct the immutable prescription without copying client/private notes,
  -- original start date, relationship IDs, or acceptance/installation state.
  select pg_catalog.jsonb_build_object(
    'name', v_title,
    'notes', '',
    'duration_weeks', v_revision.duration_weeks,
    'training_weekdays', pg_catalog.to_jsonb(v_revision.training_weekdays),
    'routines', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'name', routine.name, 'notes', '',
          'exercises', coalesce((
            select pg_catalog.jsonb_agg(
              pg_catalog.jsonb_build_object(
                'name', exercise.exercise_name,
                'muscle_group', exercise.muscle_group,
                'equipment', exercise.equipment,
                'target_sets', exercise.target_sets,
                'target_reps_min', exercise.target_reps_min,
                'target_reps_max', exercise.target_reps_max,
                'rest_seconds', exercise.rest_seconds,
                'warmup_sets', exercise.warmup_sets,
                'approach_sets', exercise.approach_sets,
                'warmup_rest_seconds', exercise.warmup_rest_seconds,
                'approach_rest_seconds', exercise.approach_rest_seconds,
                'unilateral', exercise.unilateral,
                'unilateral_target', exercise.unilateral_target,
                'preparation_unilateral', exercise.preparation_unilateral,
                'unilateral_side_rest_seconds', exercise.unilateral_side_rest_seconds,
                'preferred_unilateral_start_side', exercise.preferred_unilateral_start_side,
                'superset_key', exercise.superset_key
              ) order by exercise.position, exercise.id
            )
            from public.stk_assigned_program_revision_exercises exercise
            where exercise.revision_routine_id = routine.id
          ), '[]'::jsonb)
        ) order by routine.position, routine.id
      )
      from public.stk_assigned_program_revision_routines routine
      where routine.revision_id = v_revision.id
    ), '[]'::jsonb)
  ) into v_program;

  if pg_catalog.jsonb_array_length(v_program -> 'routines') = 0 then
    raise exception 'Program revision has no routines';
  end if;
  -- Prevent unlimited library growth under concurrent saves for the same coach.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_coach::text, 0));
  if (select count(*) from public.stk_coach_pro_templates
      where coach_user_id = v_coach and status = 'active') >= 100 then
    raise exception 'Active template limit reached';
  end if;
  insert into public.stk_coach_pro_templates (coach_user_id, title, program)
  values (v_coach, v_title, v_program) returning id into v_template_id;
  return v_template_id;
end;
$$;

create or replace function public.stk_list_coach_pro_templates(
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
  v_limit integer := coalesce(p_limit, 25);
  v_offset integer := coalesce(p_offset, 0);
  v_items jsonb;
  v_total bigint;
begin
  if v_coach is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities
                 where user_id = v_coach and capability = 'coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  if v_limit not between 1 and 50 or v_offset not between 0 and 10000 then
    raise exception 'Invalid template page';
  end if;
  select count(*) into v_total from public.stk_coach_pro_templates t
    where t.coach_user_id = v_coach and t.status = 'active';
  select coalesce(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'id', page.id,
      'title', page.title,
      'duration_weeks', (page.program ->> 'duration_weeks')::integer,
      'routine_count', pg_catalog.jsonb_array_length(page.program -> 'routines'),
      'created_at', page.created_at
    ) order by page.created_at desc, page.id desc
  ), '[]'::jsonb) into v_items
  from (
    select t.id, t.title, t.program, t.created_at
    from public.stk_coach_pro_templates t
    where t.coach_user_id = v_coach and t.status = 'active'
    order by t.created_at desc, t.id desc
    limit v_limit offset v_offset
  ) page;
  return pg_catalog.jsonb_build_object('total_count', v_total, 'items', v_items);
end;
$$;

create or replace function public.stk_assign_coach_pro_template(
  p_template_id uuid,
  p_relationship_id uuid,
  p_starts_on date default current_date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coach uuid := auth.uid();
  v_program jsonb;
  v_client uuid;
begin
  if v_coach is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities
                 where user_id = v_coach and capability = 'coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  select t.program into v_program
    from public.stk_coach_pro_templates t
   where t.id = p_template_id and t.coach_user_id = v_coach and t.status = 'active';
  if not found then raise exception 'Template unavailable'; end if;
  select relation.client_user_id into v_client
    from public.stk_coach_client_relationships relation
   where relation.id = p_relationship_id
     and relation.coach_user_id = v_coach
     and relation.status = 'active'
     and coalesce((relation.permissions ->> 'assign_programs')::boolean, false)
   for update;
  if not found then
    raise exception 'Active program assignment permission required';
  end if;
  if p_starts_on is null then raise exception 'Program start date is required'; end if;
  -- Delegate to the existing versioned assignment contract. It creates fresh
  -- assignment/routine/exercise UUIDs and captures a new immutable baseline.
  return public.stk_assign_program(
    v_client,
    pg_catalog.jsonb_set(v_program, '{starts_on}',
      pg_catalog.to_jsonb(p_starts_on::text), true)
  );
end;
$$;

create or replace function public.stk_archive_coach_pro_template(p_template_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coach uuid := auth.uid();
begin
  if v_coach is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities
                 where user_id = v_coach and capability = 'coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  update public.stk_coach_pro_templates
  set status = 'archived', updated_at = now()
  where id = p_template_id and coach_user_id = v_coach and status = 'active';
  return found;
end;
$$;

revoke all on function public.stk_save_coach_pro_template_from_revision(uuid,uuid,uuid,text) from public, anon, authenticated;
revoke all on function public.stk_list_coach_pro_templates(integer,integer) from public, anon, authenticated;
revoke all on function public.stk_assign_coach_pro_template(uuid,uuid,date) from public, anon, authenticated;
revoke all on function public.stk_archive_coach_pro_template(uuid) from public, anon, authenticated;
grant execute on function public.stk_save_coach_pro_template_from_revision(uuid,uuid,uuid,text) to authenticated;
grant execute on function public.stk_list_coach_pro_templates(integer,integer) to authenticated;
grant execute on function public.stk_assign_coach_pro_template(uuid,uuid,date) to authenticated;
grant execute on function public.stk_archive_coach_pro_template(uuid) to authenticated;
