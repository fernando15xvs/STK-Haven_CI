-- Roadmap 3.0 / Fase D
-- Coach/client invitations, explicit consent and active-relationship permissions.
-- Intentionally not applied to any remote project by repository changes or CI.

create extension if not exists pgcrypto with schema extensions;

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
        'view_checkins',
        'view_nutrition',
        'comment'
      )
      or pg_catalog.jsonb_typeof(entry.value) <> 'boolean'
    );
$$;

revoke all on function public.stk_valid_coach_permissions(jsonb)
  from public, anon;
grant execute on function public.stk_valid_coach_permissions(jsonb)
  to authenticated;

create table if not exists public.stk_coach_invitations (
  id uuid primary key default gen_random_uuid(),
  coach_user_id uuid not null references auth.users(id) on delete cascade,
  code_hash text not null unique,
  status text not null default 'pending',
  permissions jsonb not null default '{}'::jsonb,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id) on delete set null,
  constraint stk_coach_invitations_status
    check (status in ('pending', 'accepted', 'revoked', 'expired')),
  constraint stk_coach_invitations_permissions
    check (public.stk_valid_coach_permissions(permissions)),
  constraint stk_coach_invitations_expiry
    check (expires_at > created_at)
);

create table if not exists public.stk_coach_client_relationships (
  id uuid primary key default gen_random_uuid(),
  coach_user_id uuid not null references auth.users(id) on delete cascade,
  client_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active',
  permissions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  accepted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (coach_user_id, client_user_id),
  constraint stk_coach_client_relationships_distinct_users
    check (coach_user_id <> client_user_id),
  constraint stk_coach_client_relationships_status
    check (status in ('active', 'paused', 'revoked')),
  constraint stk_coach_client_relationships_permissions
    check (public.stk_valid_coach_permissions(permissions))
);

create index if not exists stk_coach_invitations_coach_status_idx
  on public.stk_coach_invitations (coach_user_id, status);

create index if not exists stk_coach_client_coach_status_idx
  on public.stk_coach_client_relationships (coach_user_id, status);

create index if not exists stk_coach_client_client_status_idx
  on public.stk_coach_client_relationships (client_user_id, status);

alter table public.stk_coach_invitations enable row level security;
alter table public.stk_coach_client_relationships enable row level security;

revoke all on public.stk_coach_invitations from anon;
revoke all on public.stk_coach_client_relationships from anon;

grant select on public.stk_coach_invitations to authenticated;
grant select on public.stk_coach_client_relationships to authenticated;

create policy "STK coaches can read own invitations"
on public.stk_coach_invitations
for select
to authenticated
using (
  auth.uid() = coach_user_id
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

create policy "STK relationship members can read relationship"
on public.stk_coach_client_relationships
for select
to authenticated
using (
  (auth.uid() = coach_user_id or auth.uid() = client_user_id)
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

create or replace function public.stk_create_coach_invitation(
  p_permissions jsonb default '{}'::jsonb,
  p_expires_in_hours integer default 168
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_code text;
  v_code_hash text;
  v_permissions jsonb := coalesce(p_permissions, '{}'::jsonb);
  v_hours integer := coalesce(p_expires_in_hours, 168);
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if not exists (
    select 1
      from public.stk_user_capabilities
     where user_id = v_user_id
       and capability = 'coach'
  ) then
    raise exception 'Coach capability required';
  end if;

  if not public.stk_valid_coach_permissions(v_permissions) then
    raise exception 'Invalid coach permissions';
  end if;

  if v_hours < 1 or v_hours > 720 then
    raise exception 'Invitation expiry must be between 1 and 720 hours';
  end if;

  v_code := upper(
    substr(
      pg_catalog.encode(extensions.gen_random_bytes(16), 'hex'),
      1,
      16
    )
  );
  v_code_hash := pg_catalog.encode(
    extensions.digest(v_code, 'sha256'),
    'hex'
  );

  insert into public.stk_coach_invitations (
    coach_user_id,
    code_hash,
    permissions,
    expires_at
  )
  values (
    v_user_id,
    v_code_hash,
    v_permissions,
    now() + pg_catalog.make_interval(hours => v_hours)
  );

  return v_code;
end;
$$;

create or replace function public.stk_preview_coach_invitation(
  p_code text
)
returns table (
  invitation_id uuid,
  coach_user_id uuid,
  coach_display_name text,
  permissions jsonb,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_hash text;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  v_hash := pg_catalog.encode(
    extensions.digest(upper(btrim(p_code)), 'sha256'),
    'hex'
  );

  return query
  select
    invitation.id,
    invitation.coach_user_id,
    profile.display_name,
    invitation.permissions,
    invitation.expires_at
  from public.stk_coach_invitations as invitation
  left join public.stk_user_profiles as profile
    on profile.user_id = invitation.coach_user_id
  where invitation.code_hash = v_hash
    and invitation.status = 'pending'
    and invitation.expires_at > now()
    and invitation.coach_user_id <> v_user_id
  limit 1;
end;
$$;

create or replace function public.stk_accept_coach_invitation(
  p_code text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_hash text;
  v_invitation public.stk_coach_invitations%rowtype;
  v_relationship_id uuid;
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  v_hash := pg_catalog.encode(
    extensions.digest(upper(btrim(p_code)), 'sha256'),
    'hex'
  );

  select *
    into v_invitation
    from public.stk_coach_invitations
   where code_hash = v_hash
     and status = 'pending'
     and expires_at > now()
   for update;

  if not found then
    raise exception 'Invitation is invalid or expired';
  end if;

  if v_invitation.coach_user_id = v_user_id then
    raise exception 'Coach cannot accept own invitation';
  end if;

  insert into public.stk_coach_client_relationships (
    coach_user_id,
    client_user_id,
    status,
    permissions,
    accepted_at,
    updated_at,
    revoked_at
  )
  values (
    v_invitation.coach_user_id,
    v_user_id,
    'active',
    v_invitation.permissions,
    now(),
    now(),
    null
  )
  on conflict (coach_user_id, client_user_id) do update
    set status = 'active',
        permissions = excluded.permissions,
        accepted_at = now(),
        updated_at = now(),
        revoked_at = null
  returning id into v_relationship_id;

  update public.stk_coach_invitations
     set status = 'accepted',
         accepted_at = now(),
         accepted_by = v_user_id
   where id = v_invitation.id;

  return v_relationship_id;
end;
$$;

create or replace function public.stk_list_my_coach_relationships()
returns table (
  id uuid,
  coach_user_id uuid,
  client_user_id uuid,
  status text,
  permissions jsonb,
  created_at timestamptz,
  accepted_at timestamptz,
  updated_at timestamptz,
  revoked_at timestamptz,
  counterpart_display_name text
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
    relationship.id,
    relationship.coach_user_id,
    relationship.client_user_id,
    relationship.status,
    relationship.permissions,
    relationship.created_at,
    relationship.accepted_at,
    relationship.updated_at,
    relationship.revoked_at,
    case
      when relationship.coach_user_id = v_user_id
        then client_profile.display_name
      else coach_profile.display_name
    end as counterpart_display_name
  from public.stk_coach_client_relationships as relationship
  left join public.stk_user_profiles as coach_profile
    on coach_profile.user_id = relationship.coach_user_id
  left join public.stk_user_profiles as client_profile
    on client_profile.user_id = relationship.client_user_id
  where relationship.coach_user_id = v_user_id
     or relationship.client_user_id = v_user_id
  order by relationship.updated_at desc;
end;
$$;

create or replace function public.stk_set_coach_permissions(
  p_relationship_id uuid,
  p_permissions jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_permissions jsonb := coalesce(p_permissions, '{}'::jsonb);
begin
  if v_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if not public.stk_valid_coach_permissions(v_permissions) then
    raise exception 'Invalid coach permissions';
  end if;

  update public.stk_coach_client_relationships
     set permissions = v_permissions,
         updated_at = now()
   where id = p_relationship_id
     and client_user_id = v_user_id
     and status = 'active';

  if not found then
    raise exception 'Active client relationship not found';
  end if;
end;
$$;

create or replace function public.stk_revoke_coach_relationship(
  p_relationship_id uuid
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

  update public.stk_coach_client_relationships
     set status = 'revoked',
         revoked_at = now(),
         updated_at = now()
   where id = p_relationship_id
     and (coach_user_id = v_user_id or client_user_id = v_user_id)
     and status <> 'revoked';

  if not found then
    raise exception 'Relationship not found or already revoked';
  end if;
end;
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

revoke all on function public.stk_create_coach_invitation(jsonb, integer)
  from public, anon;
revoke all on function public.stk_preview_coach_invitation(text)
  from public, anon;
revoke all on function public.stk_accept_coach_invitation(text)
  from public, anon;
revoke all on function public.stk_list_my_coach_relationships()
  from public, anon;
revoke all on function public.stk_set_coach_permissions(uuid, jsonb)
  from public, anon;
revoke all on function public.stk_revoke_coach_relationship(uuid)
  from public, anon;
revoke all on function public.stk_coach_can_access(uuid, text)
  from public, anon;

grant execute on function public.stk_create_coach_invitation(jsonb, integer)
  to authenticated;
grant execute on function public.stk_preview_coach_invitation(text)
  to authenticated;
grant execute on function public.stk_accept_coach_invitation(text)
  to authenticated;
grant execute on function public.stk_list_my_coach_relationships()
  to authenticated;
grant execute on function public.stk_set_coach_permissions(uuid, jsonb)
  to authenticated;
grant execute on function public.stk_revoke_coach_relationship(uuid)
  to authenticated;
grant execute on function public.stk_coach_can_access(uuid, text)
  to authenticated;

comment on table public.stk_coach_invitations is
  'Hashed, expiring coach invitation codes. Raw codes are returned once and never persisted.';
comment on table public.stk_coach_client_relationships is
  'Consent-backed coach/client relationships. Capability alone does not create access.';
comment on function public.stk_coach_can_access(uuid, text) is
  'Returns true only for an active relationship and an explicitly granted permission.';
