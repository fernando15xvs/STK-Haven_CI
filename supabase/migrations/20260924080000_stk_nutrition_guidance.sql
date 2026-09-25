-- Roadmap 3.0 / Fase F
-- Versioned, non-clinical food guidance shared between an active coach/client
-- relationship. This module intentionally stores no calorie, macro, weight
-- target, diagnosis, treatment or therapeutic-diet fields.
-- Intentionally not applied to any remote project by repository changes or CI.

create table if not exists public.stk_nutrition_guidance_plans (
  id uuid primary key default gen_random_uuid(),
  relationship_id uuid not null
    references public.stk_coach_client_relationships(id) on delete cascade,
  coach_user_id uuid not null references auth.users(id) on delete cascade,
  client_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active',
  current_version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint stk_nutrition_guidance_plan_status
    check (status in ('active', 'archived')),
  constraint stk_nutrition_guidance_current_version
    check (current_version between 1 and 10000)
);

create table if not exists public.stk_nutrition_guidance_versions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null
    references public.stk_nutrition_guidance_plans(id) on delete cascade,
  version integer not null,
  title text not null,
  overview text not null default '',
  hydration_notes text not null default '',
  general_notes text not null default '',
  scope_notice text not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint stk_nutrition_guidance_version
    check (version between 1 and 10000),
  constraint stk_nutrition_guidance_title
    check (char_length(btrim(title)) between 1 and 120),
  constraint stk_nutrition_guidance_overview
    check (char_length(overview) <= 4000),
  constraint stk_nutrition_guidance_hydration
    check (char_length(hydration_notes) <= 2000),
  constraint stk_nutrition_guidance_notes
    check (char_length(general_notes) <= 6000),
  constraint stk_nutrition_guidance_scope
    check (char_length(scope_notice) between 20 and 1000),
  unique (plan_id, version)
);

create table if not exists public.stk_nutrition_guidance_meals (
  id uuid primary key default gen_random_uuid(),
  version_id uuid not null
    references public.stk_nutrition_guidance_versions(id) on delete cascade,
  position integer not null,
  name text not null,
  timing_label text not null default '',
  notes text not null default '',
  constraint stk_nutrition_guidance_meal_position
    check (position between 0 and 19),
  constraint stk_nutrition_guidance_meal_name
    check (char_length(btrim(name)) between 1 and 100),
  constraint stk_nutrition_guidance_meal_timing
    check (char_length(timing_label) <= 80),
  constraint stk_nutrition_guidance_meal_notes
    check (char_length(notes) <= 2000),
  unique (version_id, position)
);

create table if not exists public.stk_nutrition_guidance_items (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null
    references public.stk_nutrition_guidance_meals(id) on delete cascade,
  position integer not null,
  food_example text not null,
  serving_note text not null default '',
  constraint stk_nutrition_guidance_item_position
    check (position between 0 and 49),
  constraint stk_nutrition_guidance_food_example
    check (char_length(btrim(food_example)) between 1 and 160),
  constraint stk_nutrition_guidance_serving_note
    check (char_length(serving_note) <= 500),
  unique (meal_id, position)
);

create index if not exists stk_nutrition_guidance_client_idx
  on public.stk_nutrition_guidance_plans
  (client_user_id, status, updated_at desc);

create index if not exists stk_nutrition_guidance_coach_idx
  on public.stk_nutrition_guidance_plans
  (coach_user_id, status, updated_at desc);

create index if not exists stk_nutrition_guidance_versions_idx
  on public.stk_nutrition_guidance_versions (plan_id, version desc);

alter table public.stk_nutrition_guidance_plans enable row level security;
alter table public.stk_nutrition_guidance_versions enable row level security;
alter table public.stk_nutrition_guidance_meals enable row level security;
alter table public.stk_nutrition_guidance_items enable row level security;

revoke all on public.stk_nutrition_guidance_plans from anon, authenticated;
revoke all on public.stk_nutrition_guidance_versions from anon, authenticated;
revoke all on public.stk_nutrition_guidance_meals from anon, authenticated;
revoke all on public.stk_nutrition_guidance_items from anon, authenticated;

grant select on public.stk_nutrition_guidance_plans to authenticated;
grant select on public.stk_nutrition_guidance_versions to authenticated;
grant select on public.stk_nutrition_guidance_meals to authenticated;
grant select on public.stk_nutrition_guidance_items to authenticated;

create policy "STK clients and permitted coaches can read nutrition plans"
on public.stk_nutrition_guidance_plans
for select
to authenticated
using (
  coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  and (
    auth.uid() = client_user_id
    or (
      auth.uid() = coach_user_id
      and public.stk_coach_can_access(client_user_id, 'view_nutrition')
    )
  )
);

create policy "STK clients and permitted coaches can read nutrition versions"
on public.stk_nutrition_guidance_versions
for select
to authenticated
using (
  exists (
    select 1
    from public.stk_nutrition_guidance_plans as plan
    where plan.id = plan_id
      and (
        auth.uid() = plan.client_user_id
        or (
          auth.uid() = plan.coach_user_id
          and public.stk_coach_can_access(
            plan.client_user_id,
            'view_nutrition'
          )
        )
      )
      and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  )
);

create policy "STK clients and permitted coaches can read nutrition meals"
on public.stk_nutrition_guidance_meals
for select
to authenticated
using (
  exists (
    select 1
    from public.stk_nutrition_guidance_versions as version
    join public.stk_nutrition_guidance_plans as plan
      on plan.id = version.plan_id
    where version.id = version_id
      and (
        auth.uid() = plan.client_user_id
        or (
          auth.uid() = plan.coach_user_id
          and public.stk_coach_can_access(
            plan.client_user_id,
            'view_nutrition'
          )
        )
      )
      and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  )
);

create policy "STK clients and permitted coaches can read nutrition items"
on public.stk_nutrition_guidance_items
for select
to authenticated
using (
  exists (
    select 1
    from public.stk_nutrition_guidance_meals as meal
    join public.stk_nutrition_guidance_versions as version
      on version.id = meal.version_id
    join public.stk_nutrition_guidance_plans as plan
      on plan.id = version.plan_id
    where meal.id = meal_id
      and (
        auth.uid() = plan.client_user_id
        or (
          auth.uid() = plan.coach_user_id
          and public.stk_coach_can_access(
            plan.client_user_id,
            'view_nutrition'
          )
        )
      )
      and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  )
);

create or replace function public.stk_save_nutrition_guidance(
  p_client_user_id uuid,
  p_plan_id uuid,
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coach_user_id uuid := auth.uid();
  v_relationship public.stk_coach_client_relationships%rowtype;
  v_plan public.stk_nutrition_guidance_plans%rowtype;
  v_plan_id uuid;
  v_version integer;
  v_version_id uuid;
  v_title text;
  v_overview text;
  v_hydration text;
  v_notes text;
  v_scope text;
  v_meals jsonb;
  v_meal jsonb;
  v_items jsonb;
  v_item jsonb;
  v_meal_id uuid;
  v_meal_index integer := 0;
  v_item_index integer;
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
     and coalesce((permissions ->> 'view_nutrition')::boolean, false)
   limit 1;

  if not found then
    raise exception 'Nutrition permission required';
  end if;

  if pg_catalog.jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Nutrition payload must be an object';
  end if;

  v_title := btrim(coalesce(p_payload ->> 'title', ''));
  v_overview := coalesce(p_payload ->> 'overview', '');
  v_hydration := coalesce(p_payload ->> 'hydration_notes', '');
  v_notes := coalesce(p_payload ->> 'general_notes', '');
  v_scope := coalesce(
    nullif(btrim(p_payload ->> 'scope_notice'), ''),
    'Orientación alimentaria general. No sustituye atención médica o nutricional profesional.'
  );
  v_meals := coalesce(p_payload -> 'meals', '[]'::jsonb);

  if char_length(v_title) < 1 or char_length(v_title) > 120 then
    raise exception 'Nutrition plan title length is invalid';
  end if;
  if char_length(v_overview) > 4000
     or char_length(v_hydration) > 2000
     or char_length(v_notes) > 6000 then
    raise exception 'Nutrition plan text is too long';
  end if;
  if char_length(v_scope) < 20 or char_length(v_scope) > 1000 then
    raise exception 'Nutrition scope notice length is invalid';
  end if;
  if pg_catalog.jsonb_typeof(v_meals) <> 'array' then
    raise exception 'Nutrition meals must be an array';
  end if;
  if pg_catalog.jsonb_array_length(v_meals) > 20 then
    raise exception 'Nutrition plan supports at most 20 meals';
  end if;

  if p_plan_id is null then
    insert into public.stk_nutrition_guidance_plans (
      relationship_id,
      coach_user_id,
      client_user_id,
      current_version
    )
    values (
      v_relationship.id,
      v_coach_user_id,
      p_client_user_id,
      1
    )
    returning * into v_plan;

    v_plan_id := v_plan.id;
    v_version := 1;
  else
    select *
      into v_plan
      from public.stk_nutrition_guidance_plans
     where id = p_plan_id
       and coach_user_id = v_coach_user_id
       and client_user_id = p_client_user_id
       and status = 'active'
     for update;

    if not found then
      raise exception 'Active nutrition plan not found';
    end if;

    v_plan_id := v_plan.id;
    v_version := v_plan.current_version + 1;
    if v_version > 10000 then
      raise exception 'Nutrition plan version limit reached';
    end if;
  end if;

  insert into public.stk_nutrition_guidance_versions (
    plan_id,
    version,
    title,
    overview,
    hydration_notes,
    general_notes,
    scope_notice,
    created_by
  )
  values (
    v_plan_id,
    v_version,
    v_title,
    v_overview,
    v_hydration,
    v_notes,
    v_scope,
    v_coach_user_id
  )
  returning id into v_version_id;

  for v_meal in
    select value
      from pg_catalog.jsonb_array_elements(v_meals)
  loop
    if pg_catalog.jsonb_typeof(v_meal) <> 'object' then
      raise exception 'Nutrition meal must be an object';
    end if;

    if char_length(btrim(coalesce(v_meal ->> 'name', ''))) < 1
       or char_length(btrim(coalesce(v_meal ->> 'name', ''))) > 100 then
      raise exception 'Nutrition meal name length is invalid';
    end if;
    if char_length(coalesce(v_meal ->> 'timing_label', '')) > 80
       or char_length(coalesce(v_meal ->> 'notes', '')) > 2000 then
      raise exception 'Nutrition meal text is too long';
    end if;

    v_items := coalesce(v_meal -> 'items', '[]'::jsonb);
    if pg_catalog.jsonb_typeof(v_items) <> 'array' then
      raise exception 'Nutrition meal items must be an array';
    end if;
    if pg_catalog.jsonb_array_length(v_items) > 50 then
      raise exception 'Nutrition meal supports at most 50 items';
    end if;

    insert into public.stk_nutrition_guidance_meals (
      version_id,
      position,
      name,
      timing_label,
      notes
    )
    values (
      v_version_id,
      v_meal_index,
      btrim(v_meal ->> 'name'),
      coalesce(v_meal ->> 'timing_label', ''),
      coalesce(v_meal ->> 'notes', '')
    )
    returning id into v_meal_id;

    v_item_index := 0;
    for v_item in
      select value
        from pg_catalog.jsonb_array_elements(v_items)
    loop
      if pg_catalog.jsonb_typeof(v_item) <> 'object' then
        raise exception 'Nutrition food example must be an object';
      end if;

      if char_length(btrim(coalesce(v_item ->> 'food_example', ''))) < 1
         or char_length(btrim(coalesce(v_item ->> 'food_example', ''))) > 160 then
        raise exception 'Nutrition food example length is invalid';
      end if;
      if char_length(coalesce(v_item ->> 'serving_note', '')) > 500 then
        raise exception 'Nutrition serving note is too long';
      end if;

      insert into public.stk_nutrition_guidance_items (
        meal_id,
        position,
        food_example,
        serving_note
      )
      values (
        v_meal_id,
        v_item_index,
        btrim(v_item ->> 'food_example'),
        coalesce(v_item ->> 'serving_note', '')
      );

      v_item_index := v_item_index + 1;
    end loop;

    v_meal_index := v_meal_index + 1;
  end loop;

  update public.stk_nutrition_guidance_plans
     set current_version = v_version,
         updated_at = now()
   where id = v_plan_id;

  return v_plan_id;
end;
$$;

create or replace function public.stk_list_my_nutrition_guidance()
returns table (
  id uuid,
  relationship_id uuid,
  coach_user_id uuid,
  client_user_id uuid,
  status text,
  current_version integer,
  title text,
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
    plan.id,
    plan.relationship_id,
    plan.coach_user_id,
    plan.client_user_id,
    plan.status,
    plan.current_version,
    version.title,
    plan.updated_at
  from public.stk_nutrition_guidance_plans as plan
  join public.stk_nutrition_guidance_versions as version
    on version.plan_id = plan.id
   and version.version = plan.current_version
  where plan.client_user_id = v_user_id
     or (
       plan.coach_user_id = v_user_id
       and public.stk_coach_can_access(
         plan.client_user_id,
         'view_nutrition'
       )
     )
  order by plan.updated_at desc;
end;
$$;

create or replace function public.stk_get_nutrition_guidance(
  p_plan_id uuid,
  p_version integer default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_plan public.stk_nutrition_guidance_plans%rowtype;
  v_version integer;
  v_version_row public.stk_nutrition_guidance_versions%rowtype;
  v_meals jsonb;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select *
    into v_plan
    from public.stk_nutrition_guidance_plans
   where id = p_plan_id
   limit 1;

  if not found then
    raise exception 'Nutrition plan not found';
  end if;

  if v_user_id <> v_plan.client_user_id
     and (
       v_user_id <> v_plan.coach_user_id
       or not public.stk_coach_can_access(
         v_plan.client_user_id,
         'view_nutrition'
       )
     ) then
    raise exception 'Nutrition permission required';
  end if;

  v_version := coalesce(p_version, v_plan.current_version);

  select *
    into v_version_row
    from public.stk_nutrition_guidance_versions
   where plan_id = v_plan.id
     and version = v_version
   limit 1;

  if not found then
    raise exception 'Nutrition plan version not found';
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id', meal.id,
        'position', meal.position,
        'name', meal.name,
        'timing_label', meal.timing_label,
        'notes', meal.notes,
        'items', (
          select coalesce(
            pg_catalog.jsonb_agg(
              pg_catalog.jsonb_build_object(
                'id', item.id,
                'position', item.position,
                'food_example', item.food_example,
                'serving_note', item.serving_note
              )
              order by item.position
            ),
            '[]'::jsonb
          )
          from public.stk_nutrition_guidance_items as item
          where item.meal_id = meal.id
        )
      )
      order by meal.position
    ),
    '[]'::jsonb
  )
  into v_meals
  from public.stk_nutrition_guidance_meals as meal
  where meal.version_id = v_version_row.id;

  return pg_catalog.jsonb_build_object(
    'id', v_plan.id,
    'relationship_id', v_plan.relationship_id,
    'coach_user_id', v_plan.coach_user_id,
    'client_user_id', v_plan.client_user_id,
    'status', v_plan.status,
    'current_version', v_plan.current_version,
    'version', v_version_row.version,
    'title', v_version_row.title,
    'overview', v_version_row.overview,
    'hydration_notes', v_version_row.hydration_notes,
    'general_notes', v_version_row.general_notes,
    'scope_notice', v_version_row.scope_notice,
    'created_at', v_version_row.created_at,
    'meals', v_meals
  );
end;
$$;

create or replace function public.stk_archive_nutrition_guidance(
  p_plan_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_plan public.stk_nutrition_guidance_plans%rowtype;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  select *
    into v_plan
    from public.stk_nutrition_guidance_plans
   where id = p_plan_id
   limit 1;

  if not found then
    raise exception 'Nutrition plan not found';
  end if;

  if v_user_id <> v_plan.coach_user_id
     or not public.stk_coach_can_access(
       v_plan.client_user_id,
       'view_nutrition'
     ) then
    raise exception 'Nutrition permission required';
  end if;

  update public.stk_nutrition_guidance_plans
     set status = 'archived',
         archived_at = now(),
         updated_at = now()
   where id = p_plan_id
     and status = 'active';
end;
$$;

revoke all on function public.stk_save_nutrition_guidance(uuid, uuid, jsonb)
  from public, anon;
revoke all on function public.stk_list_my_nutrition_guidance()
  from public, anon;
revoke all on function public.stk_get_nutrition_guidance(uuid, integer)
  from public, anon;
revoke all on function public.stk_archive_nutrition_guidance(uuid)
  from public, anon;

grant execute on function public.stk_save_nutrition_guidance(uuid, uuid, jsonb)
  to authenticated;
grant execute on function public.stk_list_my_nutrition_guidance()
  to authenticated;
grant execute on function public.stk_get_nutrition_guidance(uuid, integer)
  to authenticated;
grant execute on function public.stk_archive_nutrition_guidance(uuid)
  to authenticated;

comment on table public.stk_nutrition_guidance_plans is
  'Versioned non-clinical food guidance. No calorie, macro, goal-weight, diagnosis or therapeutic-diet fields.';
comment on table public.stk_nutrition_guidance_versions is
  'Immutable revisions of food guidance written by the linked coach.';
