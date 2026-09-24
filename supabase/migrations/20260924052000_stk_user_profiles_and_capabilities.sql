-- Roadmap 3.0 / Fase C
-- Permanent STK Haven application identity and self-managed capabilities.
-- This migration is intentionally not applied by CI or by repository changes.

create table if not exists public.stk_user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stk_user_profiles_display_name_length
    check (display_name is null or char_length(display_name) <= 80)
);

create table if not exists public.stk_user_capabilities (
  user_id uuid not null references auth.users(id) on delete cascade,
  capability text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, capability),
  constraint stk_user_capabilities_allowed
    check (capability in ('athlete', 'coach'))
);

alter table public.stk_user_profiles enable row level security;
alter table public.stk_user_capabilities enable row level security;

revoke all on public.stk_user_profiles from anon;
revoke all on public.stk_user_capabilities from anon;

grant select, insert, update on public.stk_user_profiles to authenticated;
grant select, insert, delete on public.stk_user_capabilities to authenticated;

create policy "STK users can read own profile"
on public.stk_user_profiles
for select
to authenticated
using (
  auth.uid() = user_id
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

create policy "STK users can create own profile"
on public.stk_user_profiles
for insert
to authenticated
with check (
  auth.uid() = user_id
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

create policy "STK users can update own profile"
on public.stk_user_profiles
for update
to authenticated
using (
  auth.uid() = user_id
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
)
with check (
  auth.uid() = user_id
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

create policy "STK users can read own capabilities"
on public.stk_user_capabilities
for select
to authenticated
using (
  auth.uid() = user_id
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

create policy "STK users can add own capabilities"
on public.stk_user_capabilities
for insert
to authenticated
with check (
  auth.uid() = user_id
  and capability in ('athlete', 'coach')
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

create policy "STK users can remove own capabilities"
on public.stk_user_capabilities
for delete
to authenticated
using (
  auth.uid() = user_id
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

create or replace function public.stk_sync_own_profile(
  p_display_name text default null,
  p_capabilities text[] default array['athlete']::text[]
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_capability text;
  v_capabilities text[] := coalesce(p_capabilities, array['athlete']::text[]);
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if cardinality(v_capabilities) = 0 then
    v_capabilities := array['athlete']::text[];
  end if;

  foreach v_capability in array v_capabilities loop
    if v_capability not in ('athlete', 'coach') then
      raise exception 'Unsupported STK capability: %', v_capability;
    end if;
  end loop;

  insert into public.stk_user_profiles (
    user_id,
    display_name,
    updated_at
  )
  values (
    v_user_id,
    nullif(btrim(p_display_name), ''),
    now()
  )
  on conflict (user_id) do update
    set display_name = coalesce(
          excluded.display_name,
          public.stk_user_profiles.display_name
        ),
        updated_at = now();

  delete from public.stk_user_capabilities
   where user_id = v_user_id
     and capability <> all(v_capabilities);

  foreach v_capability in array v_capabilities loop
    insert into public.stk_user_capabilities (user_id, capability)
    values (v_user_id, v_capability)
    on conflict (user_id, capability) do nothing;
  end loop;
end;
$$;

revoke all on function public.stk_sync_own_profile(text, text[]) from public, anon;
grant execute on function public.stk_sync_own_profile(text, text[]) to authenticated;

comment on table public.stk_user_profiles is
  'Permanent STK Haven application profiles. Anonymous Haven Faith sessions are excluded by RLS.';

comment on table public.stk_user_capabilities is
  'Application capabilities for permanent STK Haven accounts. Capability alone never grants access to another user.';
