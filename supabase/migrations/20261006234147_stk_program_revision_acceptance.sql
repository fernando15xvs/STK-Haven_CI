-- Coach Pro explicit client acceptance for immutable program revisions.
-- Acceptance records consent only. It never rewrites the legacy assignment
-- prescription, never advances assignment.version, and never installs locally.

create table if not exists public.stk_assigned_program_revision_acceptances (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null
    references public.stk_assigned_programs(id) on delete cascade,
  revision_id uuid not null
    references public.stk_assigned_program_revisions(id) on delete cascade,
  client_user_id uuid not null
    references auth.users(id) on delete cascade,
  accepted_at timestamptz not null default now(),
  unique (assignment_id, revision_id)
);

create index if not exists stk_program_revision_acceptance_assignment_idx
  on public.stk_assigned_program_revision_acceptances
    (assignment_id, accepted_at desc);

alter table public.stk_assigned_program_revision_acceptances
  enable row level security;

revoke all on public.stk_assigned_program_revision_acceptances
  from anon, authenticated;

create or replace function public.stk_get_my_program_revision_state(
  p_assignment_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.stk_assigned_programs%rowtype;
  v_latest public.stk_assigned_program_revisions%rowtype;
  v_accepted_revision_id uuid;
  v_accepted_revision_number integer;
  v_accepted_at timestamptz;
  v_access_active boolean := false;
  v_pending boolean := false;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select assignment.*
    into v_assignment
    from public.stk_assigned_programs as assignment
   where assignment.id = p_assignment_id
     and assignment.client_user_id = v_user_id;

  if not found then
    raise exception 'Assigned program revision access unavailable';
  end if;

  select
    acceptance.revision_id,
    revision.revision_number,
    acceptance.accepted_at
  into
    v_accepted_revision_id,
    v_accepted_revision_number,
    v_accepted_at
  from public.stk_assigned_program_revision_acceptances as acceptance
  join public.stk_assigned_program_revisions as revision
    on revision.id = acceptance.revision_id
   and revision.assignment_id = acceptance.assignment_id
  where acceptance.assignment_id = v_assignment.id
    and acceptance.client_user_id = v_user_id
  order by revision.revision_number desc, acceptance.accepted_at desc
  limit 1;

  v_access_active :=
    v_assignment.status <> 'archived'
    and exists (
      select 1
        from public.stk_coach_client_relationships as relationship
       where relationship.id = v_assignment.relationship_id
         and relationship.coach_user_id = v_assignment.coach_user_id
         and relationship.client_user_id = v_user_id
         and relationship.status = 'active'
         and coalesce(
           (relationship.permissions ->> 'assign_programs')::boolean,
           false
         )
    )
    and public.stk_entitlement_active_for_user(
      v_assignment.coach_user_id,
      'coach_pro'
    );

  if v_access_active then
    select revision.*
      into v_latest
      from public.stk_assigned_program_revisions as revision
     where revision.assignment_id = v_assignment.id
     order by revision.revision_number desc, revision.id
     limit 1;
  elsif v_accepted_revision_id is not null then
    select revision.*
      into v_latest
      from public.stk_assigned_program_revisions as revision
     where revision.id = v_accepted_revision_id
       and revision.assignment_id = v_assignment.id;
  end if;

  v_pending :=
    v_access_active
    and v_latest.id is not null
    and v_latest.source_kind = 'coach_revision'
    and (
      v_accepted_revision_number is null
      or v_latest.revision_number > v_accepted_revision_number
    );

  return pg_catalog.jsonb_build_object(
    'assignment_id', v_assignment.id,
    'relationship_id', v_assignment.relationship_id,
    'assignment_status', v_assignment.status,
    'current_assignment_version', v_assignment.version,
    'accepted_revision_id', v_accepted_revision_id,
    'accepted_revision_number', v_accepted_revision_number,
    'accepted_at', v_accepted_at,
    'latest_revision_id', v_latest.id,
    'latest_revision_number', v_latest.revision_number,
    'latest_source_kind', v_latest.source_kind,
    'latest_recorded_at', v_latest.recorded_at,
    'latest_authored_at', v_latest.authored_at,
    'revision_access_active', v_access_active,
    'has_pending_revision', v_pending,
    'can_accept_latest', v_pending
  );
end;
$$;

create or replace function public.stk_get_my_program_revision_page(
  p_assignment_id uuid,
  p_revision_id uuid,
  p_revision_routine_id uuid default null,
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
  v_user_id uuid := auth.uid();
  v_assignment public.stk_assigned_programs%rowtype;
  v_revision public.stk_assigned_program_revisions%rowtype;
  v_latest_revision_id uuid;
  v_accepted_revision_id uuid;
  v_accepted_at timestamptz;
  v_access_active boolean := false;
  v_routine jsonb := null;
  v_limit integer := coalesce(p_limit, 25);
  v_offset integer := coalesce(p_offset, 0);
  v_items jsonb;
  v_total bigint;
  v_is_accepted boolean := false;
  v_can_accept boolean := false;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if v_limit < 1 or v_limit > 100 then
    raise exception 'Program revision page limit must be between 1 and 100';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception 'Program revision page offset is invalid';
  end if;

  select assignment.*
    into v_assignment
    from public.stk_assigned_programs as assignment
   where assignment.id = p_assignment_id
     and assignment.client_user_id = v_user_id;

  if not found then
    raise exception 'Assigned program revision access unavailable';
  end if;

  select
    acceptance.revision_id,
    acceptance.accepted_at
  into
    v_accepted_revision_id,
    v_accepted_at
  from public.stk_assigned_program_revision_acceptances as acceptance
  join public.stk_assigned_program_revisions as revision
    on revision.id = acceptance.revision_id
   and revision.assignment_id = acceptance.assignment_id
  where acceptance.assignment_id = v_assignment.id
    and acceptance.client_user_id = v_user_id
  order by revision.revision_number desc, acceptance.accepted_at desc
  limit 1;

  v_access_active :=
    v_assignment.status <> 'archived'
    and exists (
      select 1
        from public.stk_coach_client_relationships as relationship
       where relationship.id = v_assignment.relationship_id
         and relationship.coach_user_id = v_assignment.coach_user_id
         and relationship.client_user_id = v_user_id
         and relationship.status = 'active'
         and coalesce(
           (relationship.permissions ->> 'assign_programs')::boolean,
           false
         )
    )
    and public.stk_entitlement_active_for_user(
      v_assignment.coach_user_id,
      'coach_pro'
    );

  if v_access_active then
    select revision.id
      into v_latest_revision_id
      from public.stk_assigned_program_revisions as revision
     where revision.assignment_id = v_assignment.id
     order by revision.revision_number desc, revision.id
     limit 1;
  end if;

  if p_revision_id is distinct from v_accepted_revision_id
     and (
       not v_access_active
       or p_revision_id is distinct from v_latest_revision_id
     ) then
    raise exception 'Assigned program revision access unavailable';
  end if;

  select revision.*
    into v_revision
    from public.stk_assigned_program_revisions as revision
   where revision.id = p_revision_id
     and revision.assignment_id = v_assignment.id;

  if not found then
    raise exception 'Assigned program revision access unavailable';
  end if;

  v_is_accepted := p_revision_id = v_accepted_revision_id;
  v_can_accept :=
    v_access_active
    and p_revision_id = v_latest_revision_id
    and v_revision.source_kind = 'coach_revision'
    and not v_is_accepted;

  if p_revision_routine_id is null then
    with permitted as (
      select routine.id, routine.position, routine.name
        from public.stk_assigned_program_revision_routines as routine
       where routine.revision_id = v_revision.id
    ), page as (
      select *
        from permitted
       order by position, id
       limit v_limit
       offset v_offset
    )
    select
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.to_jsonb(item)
            order by item.position, item.id
          )
          from page as item
        ),
        '[]'::jsonb
      ),
      (select count(*) from permitted)
    into v_items, v_total;
  else
    select pg_catalog.jsonb_build_object(
      'id', routine.id,
      'name', routine.name,
      'position', routine.position
    )
    into v_routine
    from public.stk_assigned_program_revision_routines as routine
    where routine.id = p_revision_routine_id
      and routine.revision_id = v_revision.id;

    if not found then
      raise exception 'Assigned program revision access unavailable';
    end if;

    with permitted as (
      select
        exercise.id,
        exercise.position,
        exercise.exercise_name as name,
        exercise.muscle_group,
        exercise.equipment,
        exercise.target_sets,
        exercise.target_reps_min,
        exercise.target_reps_max,
        exercise.rest_seconds,
        exercise.warmup_sets,
        exercise.approach_sets,
        exercise.warmup_rest_seconds,
        exercise.approach_rest_seconds,
        exercise.unilateral,
        exercise.unilateral_target,
        exercise.preparation_unilateral,
        exercise.unilateral_side_rest_seconds,
        exercise.preferred_unilateral_start_side,
        exercise.superset_key
      from public.stk_assigned_program_revision_exercises as exercise
      where exercise.revision_routine_id = p_revision_routine_id
    ), page as (
      select *
        from permitted
       order by position, id
       limit v_limit
       offset v_offset
    )
    select
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.to_jsonb(item)
            order by item.position, item.id
          )
          from page as item
        ),
        '[]'::jsonb
      ),
      (select count(*) from permitted)
    into v_items, v_total;
  end if;

  return pg_catalog.jsonb_build_object(
    'assignment_id', v_assignment.id,
    'relationship_id', v_assignment.relationship_id,
    'revision_id', v_revision.id,
    'revision_number', v_revision.revision_number,
    'previous_revision_id', v_revision.previous_revision_id,
    'source_kind', v_revision.source_kind,
    'observed_assignment_version', v_revision.observed_assignment_version,
    'name', v_revision.name,
    'duration_weeks', v_revision.duration_weeks,
    'training_weekdays', v_revision.training_weekdays,
    'starts_on', v_revision.starts_on,
    'recorded_at', v_revision.recorded_at,
    'authored_at', v_revision.authored_at,
    'accepted_at', case when v_is_accepted then v_accepted_at else null end,
    'is_accepted', v_is_accepted,
    'can_accept', v_can_accept,
    'routine', v_routine,
    'items', v_items,
    'total_count', v_total
  );
end;
$$;

create or replace function public.stk_accept_program_revision(
  p_assignment_id uuid,
  p_revision_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.stk_assigned_programs%rowtype;
  v_latest public.stk_assigned_program_revisions%rowtype;
  v_existing public.stk_assigned_program_revision_acceptances%rowtype;
  v_accepted public.stk_assigned_program_revision_acceptances%rowtype;
  v_now timestamptz := now();
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select assignment.*
    into v_assignment
    from public.stk_assigned_programs as assignment
   where assignment.id = p_assignment_id
     and assignment.client_user_id = v_user_id
     and assignment.status <> 'archived'
   for update;

  if not found then
    raise exception 'Assigned program revision acceptance unavailable';
  end if;

  select acceptance.*
    into v_existing
    from public.stk_assigned_program_revision_acceptances as acceptance
   where acceptance.assignment_id = v_assignment.id
     and acceptance.revision_id = p_revision_id
     and acceptance.client_user_id = v_user_id;

  if found then
    select revision.*
      into v_latest
      from public.stk_assigned_program_revisions as revision
     where revision.id = p_revision_id
       and revision.assignment_id = v_assignment.id;

    return pg_catalog.jsonb_build_object(
      'assignment_id', v_assignment.id,
      'revision_id', v_existing.revision_id,
      'revision_number', v_latest.revision_number,
      'accepted_at', v_existing.accepted_at,
      'already_accepted', true,
      'current_assignment_version', v_assignment.version
    );
  end if;

  if not exists (
    select 1
      from public.stk_coach_client_relationships as relationship
     where relationship.id = v_assignment.relationship_id
       and relationship.coach_user_id = v_assignment.coach_user_id
       and relationship.client_user_id = v_user_id
       and relationship.status = 'active'
       and coalesce(
         (relationship.permissions ->> 'assign_programs')::boolean,
         false
       )
  ) then
    raise exception 'Assigned program revision acceptance unavailable';
  end if;

  perform public.stk_assert_coach_pro_access(v_assignment.coach_user_id);

  select revision.*
    into v_latest
    from public.stk_assigned_program_revisions as revision
   where revision.assignment_id = v_assignment.id
   order by revision.revision_number desc, revision.id
   limit 1;

  if not found
     or v_latest.id <> p_revision_id
     or v_latest.source_kind <> 'coach_revision' then
    raise exception 'Program revision changed; reload';
  end if;

  insert into public.stk_assigned_program_revision_acceptances (
    assignment_id,
    revision_id,
    client_user_id,
    accepted_at
  )
  values (
    v_assignment.id,
    v_latest.id,
    v_user_id,
    v_now
  )
  returning * into v_accepted;

  update public.stk_assigned_programs
     set status = 'accepted',
         accepted_at = coalesce(accepted_at, v_now),
         updated_at = v_now
   where id = v_assignment.id;

  return pg_catalog.jsonb_build_object(
    'assignment_id', v_assignment.id,
    'revision_id', v_accepted.revision_id,
    'revision_number', v_latest.revision_number,
    'accepted_at', v_accepted.accepted_at,
    'already_accepted', false,
    'current_assignment_version', v_assignment.version
  );
end;
$$;

create or replace function public.stk_accept_assigned_program(
  p_assignment_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.stk_assigned_programs%rowtype;
  v_baseline_revision_id uuid;
  v_accepted_at timestamptz;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select assignment.*
    into v_assignment
    from public.stk_assigned_programs as assignment
   where assignment.id = p_assignment_id
     and assignment.client_user_id = v_user_id
     and assignment.status in ('assigned', 'accepted')
   for update;

  if not found then
    raise exception 'Pending assigned program not found';
  end if;

  v_baseline_revision_id :=
    public.stk_capture_assigned_program_baseline(v_assignment.id);
  v_accepted_at := coalesce(v_assignment.accepted_at, now());

  insert into public.stk_assigned_program_revision_acceptances (
    assignment_id,
    revision_id,
    client_user_id,
    accepted_at
  )
  values (
    v_assignment.id,
    v_baseline_revision_id,
    v_user_id,
    v_accepted_at
  )
  on conflict (assignment_id, revision_id) do nothing;

  if v_assignment.status = 'assigned' then
    update public.stk_assigned_programs
       set status = 'accepted',
           accepted_at = v_accepted_at,
           updated_at = now()
     where id = v_assignment.id;
  end if;
end;
$$;

insert into public.stk_assigned_program_revision_acceptances (
  assignment_id,
  revision_id,
  client_user_id,
  accepted_at
)
select
  assignment.id,
  baseline.id,
  assignment.client_user_id,
  assignment.accepted_at
from public.stk_assigned_programs as assignment
join lateral (
  select revision.id
    from public.stk_assigned_program_revisions as revision
   where revision.assignment_id = assignment.id
   order by revision.revision_number, revision.id
   limit 1
) as baseline on true
where assignment.accepted_at is not null
on conflict (assignment_id, revision_id) do nothing;

revoke all on function public.stk_get_my_program_revision_state(uuid)
  from public, anon, authenticated;
revoke all on function public.stk_get_my_program_revision_page(
  uuid, uuid, uuid, integer, integer
) from public, anon, authenticated;
revoke all on function public.stk_accept_program_revision(uuid, uuid)
  from public, anon, authenticated;

grant execute on function public.stk_get_my_program_revision_state(uuid)
  to authenticated;
grant execute on function public.stk_get_my_program_revision_page(
  uuid, uuid, uuid, integer, integer
) to authenticated;
grant execute on function public.stk_accept_program_revision(uuid, uuid)
  to authenticated;

comment on table public.stk_assigned_program_revision_acceptances is
  'Append-only client consent for immutable assigned-program revisions. Direct client table access is intentionally disabled.';
comment on function public.stk_get_my_program_revision_state(uuid) is
  'Returns the client-visible accepted/latest revision state. Pending revisions are hidden after relationship/permission/Coach Pro access is lost, while an already accepted revision remains recoverable.';
comment on function public.stk_get_my_program_revision_page(uuid, uuid, uuid, integer, integer) is
  'Client read of the latest proposal or currently accepted revision. Accepted content remains readable for recovery after access changes.';
comment on function public.stk_accept_program_revision(uuid, uuid) is
  'Explicitly records client consent for the current latest coach revision without changing assignment.version or prescription rows and without local installation.';
