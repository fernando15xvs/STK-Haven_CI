-- Roadmap 3.0 / Fase E
-- Coach-assigned tasks, immutable completion history and append-only comments.
-- Reuses HabitTask semantics on the client while keeping collaborative data
-- normalized and authoritative in Supabase.
-- Intentionally not applied to any remote project by repository changes or CI.

create or replace function public.stk_valid_coach_permissions(
  p_permissions jsonb
)
returns boolean
language sql
immutable
security invoker
set search_path = ''
as $$
  select
    pg_catalog.jsonb_typeof(p_permissions) = 'object'
    and not exists (
      select 1
      from pg_catalog.jsonb_each(p_permissions) as entry
      where entry.key not in (
        'view_workouts',
        'view_progress',
        'view_measurements',
        'assign_programs',
        'assign_tasks',
        'view_checkins',
        'view_nutrition',
        'comment'
      )
      or pg_catalog.jsonb_typeof(entry.value) <> 'boolean'
    );
$$;

create or replace function public.stk_coach_can_access(
  p_client_user_id uuid,
  p_permission text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_coach_user_id uuid := auth.uid();
begin
  if v_coach_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    return false;
  end if;

  if p_permission not in (
    'view_workouts',
    'view_progress',
    'view_measurements',
    'assign_programs',
    'assign_tasks',
    'view_checkins',
    'view_nutrition',
    'comment'
  ) then
    return false;
  end if;

  return exists (
    select 1
      from public.stk_coach_client_relationships
     where coach_user_id = v_coach_user_id
       and client_user_id = p_client_user_id
       and status = 'active'
       and coalesce((permissions ->> p_permission)::boolean, false)
  );
end;
$$;

create table if not exists public.stk_coach_tasks (
  id uuid primary key default gen_random_uuid(),
  relationship_id uuid not null
    references public.stk_coach_client_relationships(id) on delete cascade,
  coach_user_id uuid not null references auth.users(id) on delete cascade,
  client_user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  category text not null default 'General',
  task_type text not null default 'checklist',
  target_minutes integer not null default 0,
  recurrence_type text not null default 'once',
  weekdays smallint[] not null default '{}'::smallint[],
  starts_on date not null default current_date,
  due_at timestamptz,
  ends_on date,
  coach_instructions text not null default '',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint stk_coach_tasks_title
    check (char_length(btrim(title)) between 1 and 160),
  constraint stk_coach_tasks_category
    check (char_length(category) between 1 and 80),
  constraint stk_coach_tasks_type
    check (
      task_type in (
        'checklist',
        'readingTimer',
        'studySession',
        'reflection',
        'custom'
      )
    ),
  constraint stk_coach_tasks_target_minutes
    check (target_minutes between 0 and 1440),
  constraint stk_coach_tasks_recurrence
    check (recurrence_type in ('once', 'daily', 'weekly')),
  constraint stk_coach_tasks_weekdays
    check (
      weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
      and cardinality(weekdays) <= 7
      and (
        (recurrence_type = 'weekly' and cardinality(weekdays) >= 1)
        or (recurrence_type <> 'weekly' and cardinality(weekdays) = 0)
      )
    ),
  constraint stk_coach_tasks_dates
    check (ends_on is null or ends_on >= starts_on),
  constraint stk_coach_tasks_instructions
    check (char_length(coach_instructions) <= 4000),
  constraint stk_coach_tasks_status
    check (status in ('active', 'archived'))
);

create table if not exists public.stk_coach_task_occurrences (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null
    references public.stk_coach_tasks(id) on delete cascade,
  client_user_id uuid not null references auth.users(id) on delete cascade,
  occurrence_date date not null,
  status text not null,
  minutes_spent integer not null default 0,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (task_id, occurrence_date),
  constraint stk_coach_task_occurrences_status
    check (status in ('completed', 'skipped')),
  constraint stk_coach_task_occurrences_minutes
    check (minutes_spent between 0 and 1440)
);

create table if not exists public.stk_coach_task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null
    references public.stk_coach_tasks(id) on delete cascade,
  occurrence_date date,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint stk_coach_task_comments_body
    check (char_length(btrim(body)) between 1 and 2000)
);

create index if not exists stk_coach_tasks_client_status_idx
  on public.stk_coach_tasks (client_user_id, status, updated_at desc);

create index if not exists stk_coach_tasks_coach_status_idx
  on public.stk_coach_tasks (coach_user_id, status, updated_at desc);

create index if not exists stk_coach_task_occurrences_task_date_idx
  on public.stk_coach_task_occurrences (task_id, occurrence_date desc);

create index if not exists stk_coach_task_comments_task_created_idx
  on public.stk_coach_task_comments (task_id, created_at desc);

alter table public.stk_coach_tasks enable row level security;
alter table public.stk_coach_task_occurrences enable row level security;
alter table public.stk_coach_task_comments enable row level security;

revoke all on public.stk_coach_tasks from anon, authenticated;
revoke all on public.stk_coach_task_occurrences from anon, authenticated;
revoke all on public.stk_coach_task_comments from anon, authenticated;

grant select on public.stk_coach_tasks to authenticated;
grant select on public.stk_coach_task_occurrences to authenticated;
grant select on public.stk_coach_task_comments to authenticated;

create policy "STK clients and permitted coaches can read assigned tasks"
on public.stk_coach_tasks
for select
to authenticated
using (
  coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  and (
    auth.uid() = client_user_id
    or (
      auth.uid() = coach_user_id
      and public.stk_coach_can_access(client_user_id, 'assign_tasks')
    )
  )
);

create policy "STK clients and permitted coaches can read task occurrences"
on public.stk_coach_task_occurrences
for select
to authenticated
using (
  coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  and (
    auth.uid() = client_user_id
    or exists (
      select 1
      from public.stk_coach_tasks as task
      where task.id = task_id
        and task.coach_user_id = auth.uid()
        and public.stk_coach_can_access(task.client_user_id, 'assign_tasks')
    )
  )
);

create policy "STK task participants with comment consent can read comments"
on public.stk_coach_task_comments
for select
to authenticated
using (
  coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  and exists (
    select 1
    from public.stk_coach_tasks as task
    where task.id = task_id
      and (
        auth.uid() = task.client_user_id
        or (
          auth.uid() = task.coach_user_id
          and public.stk_coach_can_access(task.client_user_id, 'comment')
        )
      )
  )
);

create or replace function public.stk_task_due_on(
  p_task public.stk_coach_tasks,
  p_date date
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select
    p_date >= p_task.starts_on
    and (p_task.ends_on is null or p_date <= p_task.ends_on)
    and (
      p_task.archived_at is null
      or p_date <= p_task.archived_at::date
    )
    and (
      (
        p_task.recurrence_type = 'once'
        and p_date = coalesce(p_task.due_at::date, p_task.starts_on)
      )
      or p_task.recurrence_type = 'daily'
      or (
        p_task.recurrence_type = 'weekly'
        and extract(isodow from p_date)::smallint = any(p_task.weekdays)
      )
    );
$$;

create or replace function public.stk_assign_coach_task(
  p_client_user_id uuid,
  p_task jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coach_user_id uuid := auth.uid();
  v_relationship public.stk_coach_client_relationships%rowtype;
  v_task_id uuid;
  v_title text;
  v_category text;
  v_task_type text;
  v_target_minutes integer;
  v_recurrence_type text;
  v_weekdays smallint[];
  v_starts_on date;
  v_due_at timestamptz;
  v_ends_on date;
  v_instructions text;
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
     and coalesce((permissions ->> 'assign_tasks')::boolean, false)
   limit 1;

  if not found then
    raise exception 'Task assignment permission required';
  end if;

  if pg_catalog.jsonb_typeof(p_task) <> 'object' then
    raise exception 'Task payload must be an object';
  end if;

  v_title := btrim(coalesce(p_task ->> 'title', ''));
  v_category := btrim(coalesce(p_task ->> 'category', 'General'));
  v_task_type := coalesce(p_task ->> 'task_type', 'checklist');
  v_target_minutes := coalesce((p_task ->> 'target_minutes')::integer, 0);
  v_recurrence_type := coalesce(p_task ->> 'recurrence_type', 'once');
  select coalesce(array_agg(value::smallint order by value), '{}'::smallint[])
    into v_weekdays
    from pg_catalog.jsonb_array_elements_text(
      coalesce(p_task -> 'weekdays', '[]'::jsonb)
    ) as weekday(value);
  v_starts_on := coalesce((p_task ->> 'starts_on')::date, current_date);
  v_due_at := (p_task ->> 'due_at')::timestamptz;
  v_ends_on := (p_task ->> 'ends_on')::date;
  v_instructions := coalesce(p_task ->> 'coach_instructions', '');

  if char_length(v_title) < 1 or char_length(v_title) > 160 then
    raise exception 'Task title length is invalid';
  end if;
  if char_length(v_category) < 1 or char_length(v_category) > 80 then
    raise exception 'Task category length is invalid';
  end if;
  if v_task_type not in (
    'checklist',
    'readingTimer',
    'studySession',
    'reflection',
    'custom'
  ) then
    raise exception 'Task type is invalid';
  end if;
  if v_target_minutes < 0 or v_target_minutes > 1440 then
    raise exception 'Task duration is invalid';
  end if;
  if v_recurrence_type not in ('once', 'daily', 'weekly') then
    raise exception 'Task recurrence is invalid';
  end if;
  if exists (
    select 1 from unnest(v_weekdays) as day
    where day < 1 or day > 7
  ) then
    raise exception 'Task weekdays are invalid';
  end if;
  if v_recurrence_type = 'weekly' and cardinality(v_weekdays) = 0 then
    raise exception 'Weekly task requires at least one weekday';
  end if;
  if v_recurrence_type <> 'weekly' and cardinality(v_weekdays) <> 0 then
    raise exception 'Only weekly tasks may contain weekdays';
  end if;
  if v_ends_on is not null and v_ends_on < v_starts_on then
    raise exception 'Task end date is invalid';
  end if;
  if v_recurrence_type = 'once'
     and v_due_at is not null
     and v_due_at::date < v_starts_on then
    raise exception 'Task due date cannot be before its start date';
  end if;
  if v_recurrence_type = 'once'
     and v_due_at is not null
     and v_ends_on is not null
     and v_due_at::date > v_ends_on then
    raise exception 'Task due date cannot be after its end date';
  end if;
  if char_length(v_instructions) > 4000 then
    raise exception 'Task instructions are too long';
  end if;

  insert into public.stk_coach_tasks (
    relationship_id,
    coach_user_id,
    client_user_id,
    title,
    category,
    task_type,
    target_minutes,
    recurrence_type,
    weekdays,
    starts_on,
    due_at,
    ends_on,
    coach_instructions
  )
  values (
    v_relationship.id,
    v_coach_user_id,
    p_client_user_id,
    v_title,
    v_category,
    v_task_type,
    v_target_minutes,
    v_recurrence_type,
    v_weekdays,
    v_starts_on,
    v_due_at,
    v_ends_on,
    v_instructions
  )
  returning id into v_task_id;

  return v_task_id;
end;
$$;

create or replace function public.stk_set_coach_task_status(
  p_task_id uuid,
  p_occurrence_date date,
  p_status text,
  p_minutes_spent integer default 0
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_task public.stk_coach_tasks%rowtype;
  v_occurrence_id uuid;
  v_minutes integer := coalesce(p_minutes_spent, 0);
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select *
    into v_task
    from public.stk_coach_tasks
   where id = p_task_id
     and client_user_id = v_user_id
   limit 1;

  if not found then
    raise exception 'Assigned task not found';
  end if;

  if p_status not in ('completed', 'skipped') then
    raise exception 'Task occurrence status is invalid';
  end if;

  if not public.stk_task_due_on(v_task, p_occurrence_date) then
    raise exception 'Task is not due on that date';
  end if;

  if v_minutes < 0 or v_minutes > 1440 then
    raise exception 'Minutes spent are invalid';
  end if;

  if exists (
    select 1
      from public.stk_coach_task_occurrences
     where task_id = p_task_id
       and occurrence_date = p_occurrence_date
  ) then
    raise exception 'Task occurrence already has a final status';
  end if;

  insert into public.stk_coach_task_occurrences (
    task_id,
    client_user_id,
    occurrence_date,
    status,
    minutes_spent,
    completed_at
  )
  values (
    p_task_id,
    v_user_id,
    p_occurrence_date,
    p_status,
    v_minutes,
    case when p_status = 'completed' then now() else null end
  )
  returning id into v_occurrence_id;

  return v_occurrence_id;
end;
$$;

create or replace function public.stk_add_coach_task_comment(
  p_task_id uuid,
  p_occurrence_date date,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_task public.stk_coach_tasks%rowtype;
  v_comment_id uuid;
  v_body text := btrim(coalesce(p_body, ''));
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select *
    into v_task
    from public.stk_coach_tasks
   where id = p_task_id
   limit 1;

  if not found then
    raise exception 'Assigned task not found';
  end if;

  if v_user_id = v_task.coach_user_id then
    if not public.stk_coach_can_access(v_task.client_user_id, 'comment') then
      raise exception 'Comment permission required';
    end if;
  elsif v_user_id <> v_task.client_user_id then
    raise exception 'Task participant required';
  end if;

  if char_length(v_body) < 1 or char_length(v_body) > 2000 then
    raise exception 'Comment length is invalid';
  end if;

  if p_occurrence_date is not null
     and not public.stk_task_due_on(v_task, p_occurrence_date) then
    raise exception 'Comment occurrence date is invalid';
  end if;

  insert into public.stk_coach_task_comments (
    task_id,
    occurrence_date,
    author_user_id,
    body
  )
  values (
    p_task_id,
    p_occurrence_date,
    v_user_id,
    v_body
  )
  returning id into v_comment_id;

  return v_comment_id;
end;
$$;

create or replace function public.stk_archive_coach_task(
  p_task_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_task public.stk_coach_tasks%rowtype;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select *
    into v_task
    from public.stk_coach_tasks
   where id = p_task_id
   limit 1;

  if not found then
    raise exception 'Assigned task not found';
  end if;

  if v_user_id <> v_task.coach_user_id
     or not public.stk_coach_can_access(v_task.client_user_id, 'assign_tasks') then
    raise exception 'Task assignment permission required';
  end if;

  update public.stk_coach_tasks
     set status = 'archived',
         archived_at = now(),
         updated_at = now()
   where id = p_task_id
     and status = 'active';
end;
$$;

create or replace function public.stk_get_task_adherence(
  p_client_user_id uuid,
  p_days integer default 30
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_days integer := coalesce(p_days, 30);
  v_due integer := 0;
  v_completed integer := 0;
  v_skipped integer := 0;
  v_pending integer := 0;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if v_user_id <> p_client_user_id
     and not public.stk_coach_can_access(p_client_user_id, 'assign_tasks') then
    raise exception 'Task assignment permission required';
  end if;

  if v_days < 1 or v_days > 365 then
    raise exception 'Adherence window must be between 1 and 365 days';
  end if;

  with dates as (
    select day::date as occurrence_date
    from pg_catalog.generate_series(
      current_date - (v_days - 1),
      current_date,
      interval '1 day'
    ) as day
  ),
  due as (
    select task.id as task_id, dates.occurrence_date
    from public.stk_coach_tasks as task
    cross join dates
    where task.client_user_id = p_client_user_id
      and public.stk_task_due_on(task, dates.occurrence_date)
  ),
  statuses as (
    select
      due.task_id,
      due.occurrence_date,
      occurrence.status
    from due
    left join public.stk_coach_task_occurrences as occurrence
      on occurrence.task_id = due.task_id
     and occurrence.occurrence_date = due.occurrence_date
  )
  select
    count(*)::integer,
    count(*) filter (where status = 'completed')::integer,
    count(*) filter (where status = 'skipped')::integer,
    count(*) filter (where status is null)::integer
  into v_due, v_completed, v_skipped, v_pending
  from statuses;

  return pg_catalog.jsonb_build_object(
    'client_user_id', p_client_user_id,
    'days', v_days,
    'due_count', v_due,
    'completed_count', v_completed,
    'skipped_count', v_skipped,
    'pending_count', v_pending,
    'adherence_percent',
      case
        when v_due = 0 then 0
        else round((v_completed::numeric / v_due::numeric) * 100, 1)
      end
  );
end;
$$;

revoke all on function public.stk_assign_coach_task(uuid, jsonb)
  from public, anon;
revoke all on function public.stk_set_coach_task_status(uuid, date, text, integer)
  from public, anon;
revoke all on function public.stk_add_coach_task_comment(uuid, date, text)
  from public, anon;
revoke all on function public.stk_archive_coach_task(uuid)
  from public, anon;
revoke all on function public.stk_get_task_adherence(uuid, integer)
  from public, anon;
revoke all on function public.stk_task_due_on(public.stk_coach_tasks, date)
  from public, anon;

grant execute on function public.stk_assign_coach_task(uuid, jsonb)
  to authenticated;
grant execute on function public.stk_set_coach_task_status(uuid, date, text, integer)
  to authenticated;
grant execute on function public.stk_add_coach_task_comment(uuid, date, text)
  to authenticated;
grant execute on function public.stk_archive_coach_task(uuid)
  to authenticated;
grant execute on function public.stk_get_task_adherence(uuid, integer)
  to authenticated;
grant execute on function public.stk_task_due_on(public.stk_coach_tasks, date)
  to authenticated;

comment on table public.stk_coach_tasks is
  'Coach-assigned task definitions. Clients retain read access to their own assigned-task history after revocation.';
comment on table public.stk_coach_task_occurrences is
  'Immutable final occurrence states: completed or skipped.';
comment on table public.stk_coach_task_comments is
  'Append-only coach/client comments for assigned tasks and occurrences.';
