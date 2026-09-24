-- Roadmap 3.0 / Fase D5-D6
-- Normalized coach program assignments.
-- The nested JSON accepted by the RPC is transport only; persisted data is
-- normalized into assignment, routine and exercise rows.

create table if not exists public.stk_assigned_programs (
  id uuid primary key default gen_random_uuid(),
  relationship_id uuid not null
    references public.stk_coach_client_relationships(id) on delete cascade,
  coach_user_id uuid not null references auth.users(id) on delete cascade,
  client_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  notes text not null default '',
  duration_weeks integer not null default 8,
  training_weekdays smallint[] not null default '{}'::smallint[],
  starts_on date not null default current_date,
  status text not null default 'assigned',
  version integer not null default 1,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint stk_assigned_programs_name
    check (char_length(btrim(name)) between 1 and 120),
  constraint stk_assigned_programs_notes
    check (char_length(notes) <= 4000),
  constraint stk_assigned_programs_duration
    check (duration_weeks between 1 and 104),
  constraint stk_assigned_programs_weekdays
    check (
      training_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
      and cardinality(training_weekdays) <= 7
    ),
  constraint stk_assigned_programs_status
    check (status in ('assigned', 'accepted', 'archived')),
  constraint stk_assigned_programs_version
    check (version > 0)
);

create table if not exists public.stk_assigned_program_routines (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null
    references public.stk_assigned_programs(id) on delete cascade,
  position integer not null,
  name text not null,
  notes text not null default '',
  constraint stk_assigned_program_routines_position
    check (position between 0 and 49),
  constraint stk_assigned_program_routines_name
    check (char_length(btrim(name)) between 1 and 120),
  constraint stk_assigned_program_routines_notes
    check (char_length(notes) <= 4000),
  unique (assignment_id, position)
);

create table if not exists public.stk_assigned_program_exercises (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null
    references public.stk_assigned_program_routines(id) on delete cascade,
  position integer not null,
  exercise_name text not null,
  muscle_group text not null default '',
  equipment text not null default '',
  target_sets integer not null,
  target_reps_min integer not null,
  target_reps_max integer not null,
  rest_seconds integer not null,
  warmup_sets integer not null default 0,
  approach_sets integer not null default 0,
  unilateral boolean not null default false,
  unilateral_target text not null default 'other',
  superset_key text,
  constraint stk_assigned_program_exercises_position
    check (position between 0 and 99),
  constraint stk_assigned_program_exercises_name
    check (char_length(btrim(exercise_name)) between 1 and 160),
  constraint stk_assigned_program_exercises_muscle
    check (char_length(muscle_group) <= 120),
  constraint stk_assigned_program_exercises_equipment
    check (char_length(equipment) <= 120),
  constraint stk_assigned_program_exercises_sets
    check (target_sets between 1 and 30),
  constraint stk_assigned_program_exercises_reps
    check (
      target_reps_min between 1 and 1000
      and target_reps_max between target_reps_min and 1000
    ),
  constraint stk_assigned_program_exercises_rest
    check (rest_seconds between 0 and 3600),
  constraint stk_assigned_program_exercises_warmup
    check (warmup_sets between 0 and 20),
  constraint stk_assigned_program_exercises_approach
    check (approach_sets between 0 and 20),
  constraint stk_assigned_program_exercises_unilateral_target
    check (
      unilateral_target in ('arm','leg','glute','back','chest','other')
    ),
  constraint stk_assigned_program_exercises_superset
    check (superset_key is null or char_length(superset_key) <= 80),
  unique (routine_id, position)
);

create index if not exists stk_assigned_programs_client_status_idx
  on public.stk_assigned_programs (client_user_id, status, updated_at desc);

create index if not exists stk_assigned_programs_coach_status_idx
  on public.stk_assigned_programs (coach_user_id, status, updated_at desc);

create index if not exists stk_assigned_program_routines_assignment_idx
  on public.stk_assigned_program_routines (assignment_id, position);

create index if not exists stk_assigned_program_exercises_routine_idx
  on public.stk_assigned_program_exercises (routine_id, position);

alter table public.stk_assigned_programs enable row level security;
alter table public.stk_assigned_program_routines enable row level security;
alter table public.stk_assigned_program_exercises enable row level security;

revoke all on public.stk_assigned_programs from anon, authenticated;
revoke all on public.stk_assigned_program_routines from anon, authenticated;
revoke all on public.stk_assigned_program_exercises from anon, authenticated;

grant select on public.stk_assigned_programs to authenticated;
grant select on public.stk_assigned_program_routines to authenticated;
grant select on public.stk_assigned_program_exercises to authenticated;

create policy "STK assignment members can read program"
on public.stk_assigned_programs
for select
to authenticated
using (
  (auth.uid() = coach_user_id or auth.uid() = client_user_id)
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

create policy "STK assignment members can read routines"
on public.stk_assigned_program_routines
for select
to authenticated
using (
  exists (
    select 1
      from public.stk_assigned_programs as assignment
     where assignment.id = assignment_id
       and (
         assignment.coach_user_id = auth.uid()
         or assignment.client_user_id = auth.uid()
       )
       and coalesce(
         (auth.jwt() ->> 'is_anonymous')::boolean,
         false
       ) = false
  )
);

create policy "STK assignment members can read exercises"
on public.stk_assigned_program_exercises
for select
to authenticated
using (
  exists (
    select 1
      from public.stk_assigned_program_routines as routine
      join public.stk_assigned_programs as assignment
        on assignment.id = routine.assignment_id
     where routine.id = routine_id
       and (
         assignment.coach_user_id = auth.uid()
         or assignment.client_user_id = auth.uid()
       )
       and coalesce(
         (auth.jwt() ->> 'is_anonymous')::boolean,
         false
       ) = false
  )
);

create or replace function public.stk_assign_program(
  p_client_user_id uuid,
  p_program jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coach_user_id uuid := auth.uid();
  v_relationship public.stk_coach_client_relationships%rowtype;
  v_assignment_id uuid;
  v_routine_id uuid;
  v_name text;
  v_notes text;
  v_duration_weeks integer;
  v_weekdays smallint[];
  v_starts_on date;
  v_routine jsonb;
  v_exercise jsonb;
  v_routine_ord bigint;
  v_exercise_ord bigint;
  v_routine_count integer;
  v_exercise_count integer;
begin
  if v_coach_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select *
    into v_relationship
    from public.stk_coach_client_relationships
   where coach_user_id = v_coach_user_id
     and client_user_id = p_client_user_id
     and status = 'active'
   limit 1;

  if not found then
    raise exception 'Active coach/client relationship required';
  end if;

  if not coalesce(
    (v_relationship.permissions ->> 'assign_programs')::boolean,
    false
  ) then
    raise exception 'Program assignment permission required';
  end if;

  if pg_catalog.jsonb_typeof(p_program) <> 'object' then
    raise exception 'Program payload must be an object';
  end if;

  v_name := btrim(coalesce(p_program ->> 'name', ''));
  v_notes := coalesce(p_program ->> 'notes', '');
  v_duration_weeks :=
    coalesce((p_program ->> 'duration_weeks')::integer, 8);
  v_starts_on :=
    coalesce((p_program ->> 'starts_on')::date, current_date);

  if char_length(v_name) < 1 or char_length(v_name) > 120 then
    raise exception 'Program name length is invalid';
  end if;

  if char_length(v_notes) > 4000 then
    raise exception 'Program notes are too long';
  end if;

  if v_duration_weeks < 1 or v_duration_weeks > 104 then
    raise exception 'Program duration is invalid';
  end if;

  if pg_catalog.jsonb_typeof(
       coalesce(p_program -> 'training_weekdays', '[]'::jsonb)
     ) <> 'array' then
    raise exception 'training_weekdays must be an array';
  end if;

  select coalesce(
           array_agg(distinct weekday::smallint order by weekday::smallint),
           '{}'::smallint[]
         )
    into v_weekdays
    from pg_catalog.jsonb_array_elements_text(
      coalesce(p_program -> 'training_weekdays', '[]'::jsonb)
    ) as value(weekday);

  if not (
    v_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
  ) then
    raise exception 'training_weekdays contains an invalid day';
  end if;

  if pg_catalog.jsonb_typeof(p_program -> 'routines') <> 'array' then
    raise exception 'Program routines must be an array';
  end if;

  v_routine_count := pg_catalog.jsonb_array_length(p_program -> 'routines');
  if v_routine_count < 1 or v_routine_count > 20 then
    raise exception 'Program must contain between 1 and 20 routines';
  end if;

  insert into public.stk_assigned_programs (
    relationship_id,
    coach_user_id,
    client_user_id,
    name,
    notes,
    duration_weeks,
    training_weekdays,
    starts_on
  )
  values (
    v_relationship.id,
    v_coach_user_id,
    p_client_user_id,
    v_name,
    v_notes,
    v_duration_weeks,
    v_weekdays,
    v_starts_on
  )
  returning id into v_assignment_id;

  for v_routine, v_routine_ord in
    select item.value, item.ordinality
      from pg_catalog.jsonb_array_elements(p_program -> 'routines')
           with ordinality as item(value, ordinality)
  loop
    if pg_catalog.jsonb_typeof(v_routine) <> 'object' then
      raise exception 'Routine payload must be an object';
    end if;

    if char_length(btrim(coalesce(v_routine ->> 'name', ''))) < 1
       or char_length(btrim(coalesce(v_routine ->> 'name', ''))) > 120 then
      raise exception 'Routine name length is invalid';
    end if;

    if char_length(coalesce(v_routine ->> 'notes', '')) > 4000 then
      raise exception 'Routine notes are too long';
    end if;

    if pg_catalog.jsonb_typeof(v_routine -> 'exercises') <> 'array' then
      raise exception 'Routine exercises must be an array';
    end if;

    v_exercise_count :=
      pg_catalog.jsonb_array_length(v_routine -> 'exercises');
    if v_exercise_count < 1 or v_exercise_count > 60 then
      raise exception 'Routine must contain between 1 and 60 exercises';
    end if;

    insert into public.stk_assigned_program_routines (
      assignment_id,
      position,
      name,
      notes
    )
    values (
      v_assignment_id,
      (v_routine_ord - 1)::integer,
      btrim(v_routine ->> 'name'),
      coalesce(v_routine ->> 'notes', '')
    )
    returning id into v_routine_id;

    for v_exercise, v_exercise_ord in
      select item.value, item.ordinality
        from pg_catalog.jsonb_array_elements(v_routine -> 'exercises')
             with ordinality as item(value, ordinality)
    loop
      if pg_catalog.jsonb_typeof(v_exercise) <> 'object' then
        raise exception 'Exercise payload must be an object';
      end if;

      insert into public.stk_assigned_program_exercises (
        routine_id,
        position,
        exercise_name,
        muscle_group,
        equipment,
        target_sets,
        target_reps_min,
        target_reps_max,
        rest_seconds,
        warmup_sets,
        approach_sets,
        unilateral,
        unilateral_target,
        superset_key
      )
      values (
        v_routine_id,
        (v_exercise_ord - 1)::integer,
        btrim(coalesce(v_exercise ->> 'name', '')),
        coalesce(v_exercise ->> 'muscle_group', ''),
        coalesce(v_exercise ->> 'equipment', ''),
        coalesce((v_exercise ->> 'target_sets')::integer, 3),
        coalesce((v_exercise ->> 'target_reps_min')::integer, 8),
        coalesce((v_exercise ->> 'target_reps_max')::integer, 12),
        coalesce((v_exercise ->> 'rest_seconds')::integer, 120),
        coalesce((v_exercise ->> 'warmup_sets')::integer, 0),
        coalesce((v_exercise ->> 'approach_sets')::integer, 0),
        coalesce((v_exercise ->> 'unilateral')::boolean, false),
        coalesce(v_exercise ->> 'unilateral_target', 'other'),
        nullif(v_exercise ->> 'superset_key', '')
      );
    end loop;
  end loop;

  return v_assignment_id;
end;
$$;

create or replace function public.stk_list_my_assigned_programs()
returns table (
  id uuid,
  relationship_id uuid,
  coach_user_id uuid,
  client_user_id uuid,
  name text,
  duration_weeks integer,
  training_weekdays smallint[],
  starts_on date,
  status text,
  version integer,
  created_at timestamptz,
  accepted_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  return query
  select
    assignment.id,
    assignment.relationship_id,
    assignment.coach_user_id,
    assignment.client_user_id,
    assignment.name,
    assignment.duration_weeks,
    assignment.training_weekdays,
    assignment.starts_on,
    assignment.status,
    assignment.version,
    assignment.created_at,
    assignment.accepted_at,
    assignment.updated_at
  from public.stk_assigned_programs as assignment
  where assignment.coach_user_id = v_user_id
     or assignment.client_user_id = v_user_id
  order by assignment.updated_at desc;
end;
$$;

create or replace function public.stk_get_assigned_program(
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
  v_result jsonb;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select pg_catalog.jsonb_build_object(
    'id', assignment.id,
    'relationship_id', assignment.relationship_id,
    'coach_user_id', assignment.coach_user_id,
    'client_user_id', assignment.client_user_id,
    'name', assignment.name,
    'notes', assignment.notes,
    'duration_weeks', assignment.duration_weeks,
    'training_weekdays', assignment.training_weekdays,
    'starts_on', assignment.starts_on,
    'status', assignment.status,
    'version', assignment.version,
    'created_at', assignment.created_at,
    'accepted_at', assignment.accepted_at,
    'updated_at', assignment.updated_at,
    'routines', coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'id', routine.id,
            'position', routine.position,
            'name', routine.name,
            'notes', routine.notes,
            'exercises', coalesce(
              (
                select pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'id', exercise.id,
                    'position', exercise.position,
                    'name', exercise.exercise_name,
                    'muscle_group', exercise.muscle_group,
                    'equipment', exercise.equipment,
                    'target_sets', exercise.target_sets,
                    'target_reps_min', exercise.target_reps_min,
                    'target_reps_max', exercise.target_reps_max,
                    'rest_seconds', exercise.rest_seconds,
                    'warmup_sets', exercise.warmup_sets,
                    'approach_sets', exercise.approach_sets,
                    'unilateral', exercise.unilateral,
                    'unilateral_target', exercise.unilateral_target,
                    'superset_key', exercise.superset_key
                  )
                  order by exercise.position
                )
                from public.stk_assigned_program_exercises as exercise
                where exercise.routine_id = routine.id
              ),
              '[]'::jsonb
            )
          )
          order by routine.position
        )
        from public.stk_assigned_program_routines as routine
        where routine.assignment_id = assignment.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.stk_assigned_programs as assignment
  where assignment.id = p_assignment_id
    and (
      assignment.coach_user_id = v_user_id
      or assignment.client_user_id = v_user_id
    );

  if v_result is null then
    raise exception 'Assigned program not found';
  end if;

  return v_result;
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
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if exists (
    select 1
      from public.stk_assigned_programs
     where id = p_assignment_id
       and client_user_id = v_user_id
       and status = 'accepted'
  ) then
    return;
  end if;

  update public.stk_assigned_programs
     set status = 'accepted',
         accepted_at = coalesce(accepted_at, now()),
         updated_at = now()
   where id = p_assignment_id
     and client_user_id = v_user_id
     and status = 'assigned';

  if not found then
    raise exception 'Pending assigned program not found';
  end if;
end;
$$;

create or replace function public.stk_archive_assigned_program(
  p_assignment_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  update public.stk_assigned_programs
     set status = 'archived',
         updated_at = now()
   where id = p_assignment_id
     and (coach_user_id = v_user_id or client_user_id = v_user_id)
     and status <> 'archived';

  if not found then
    raise exception 'Assigned program not found or already archived';
  end if;
end;
$$;

revoke all on function public.stk_assign_program(uuid, jsonb)
  from public, anon;
revoke all on function public.stk_list_my_assigned_programs()
  from public, anon;
revoke all on function public.stk_get_assigned_program(uuid)
  from public, anon;
revoke all on function public.stk_accept_assigned_program(uuid)
  from public, anon;
revoke all on function public.stk_archive_assigned_program(uuid)
  from public, anon;

grant execute on function public.stk_assign_program(uuid, jsonb)
  to authenticated;
grant execute on function public.stk_list_my_assigned_programs()
  to authenticated;
grant execute on function public.stk_get_assigned_program(uuid)
  to authenticated;
grant execute on function public.stk_accept_assigned_program(uuid)
  to authenticated;
grant execute on function public.stk_archive_assigned_program(uuid)
  to authenticated;

comment on table public.stk_assigned_programs is
  'Versioned coach-assigned program snapshots. No workout history is copied from the coach.';
comment on table public.stk_assigned_program_routines is
  'Normalized routine snapshots belonging to a coach-assigned program.';
comment on table public.stk_assigned_program_exercises is
  'Normalized exercise prescriptions belonging to an assigned routine.';
