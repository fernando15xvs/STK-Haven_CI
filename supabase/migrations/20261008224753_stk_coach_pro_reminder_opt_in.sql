-- Coach Pro Phase 3 / private, voluntary local reminder consent.
-- A reminder opt-in is NOT implied by accepting the check-in cadence.
-- No push worker, messaging payloads, or automatic external delivery.
create table public.stk_coach_pro_reminder_opt_ins (
  relationship_id uuid primary key
    references public.stk_coach_client_relationships(id) on delete cascade,
  client_user_id uuid not null references auth.users(id) on delete cascade,
  enabled boolean not null default false,
  hour_local smallint not null default 19 check (hour_local between 7 and 22),
  accepted_cadence_revision integer,
  updated_at timestamptz not null default now(),
  constraint stk_reminder_revision_required
    check (not enabled or accepted_cadence_revision between 1 and 10000)
);
-- The native client uses three fixed notification IDs, so permit at most one
-- active Coach Pro reminder schedule per user across all coach relationships.
create unique index stk_coach_pro_reminder_one_active_per_user
  on public.stk_coach_pro_reminder_opt_ins(client_user_id) where enabled;
alter table public.stk_coach_pro_reminder_opt_ins enable row level security;
revoke all on public.stk_coach_pro_reminder_opt_ins from public, anon, authenticated;

create or replace function public.stk_get_coach_pro_reminder_opt_in(
  p_relationship_id uuid
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_relation public.stk_coach_client_relationships%rowtype;
  v_cadence public.stk_coach_pro_checkin_cadences%rowtype;
  v_opt public.stk_coach_pro_reminder_opt_ins%rowtype;
  v_allowed boolean := false;
begin
  if v_user is null or
     coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  select * into v_relation
  from public.stk_coach_client_relationships
  where id=p_relationship_id and client_user_id=v_user;
  if not found then raise exception 'Client relationship required'; end if;
  select * into v_cadence from public.stk_coach_pro_checkin_cadences
   where relationship_id=v_relation.id and client_user_id=v_user;
  select * into v_opt from public.stk_coach_pro_reminder_opt_ins
   where relationship_id=v_relation.id and client_user_id=v_user;
  v_allowed := v_relation.status='active'
    and coalesce((v_relation.permissions->>'view_checkins')::boolean,false)
    and coalesce((v_relation.permissions->>'assign_tasks')::boolean,false)
    and coalesce(v_cadence.status='accepted',false)
    and public.stk_entitlement_active_for_user(
      v_relation.coach_user_id,'coach_pro');
  return pg_catalog.jsonb_build_object(
    'enabled',coalesce(v_opt.enabled,false) and v_allowed
      and v_opt.accepted_cadence_revision=v_cadence.revision,
    'hour_local',coalesce(v_opt.hour_local,19),
    'weekdays',case when v_allowed
       then pg_catalog.to_jsonb(v_cadence.weekdays)
       else '[]'::jsonb end,
    'cadence_revision',case when v_allowed
       then v_cadence.revision else null end
  );
end;
$$;

create or replace function public.stk_set_coach_pro_reminder_opt_in(
  p_relationship_id uuid,
  p_enabled boolean,
  p_hour_local integer default 19,
  p_expected_cadence_revision integer default null
)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_relation public.stk_coach_client_relationships%rowtype;
  v_cadence public.stk_coach_pro_checkin_cadences%rowtype;
begin
  if v_user is null or
     coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if p_enabled is null then raise exception 'Explicit reminder decision required'; end if;
  -- Lock the client before touching relationship preferences. This makes
  -- single-active-consent transitions atomic across concurrent requests.
  perform 1 from auth.users where id=v_user for update;
  select * into v_relation
  from public.stk_coach_client_relationships
  where id=p_relationship_id and client_user_id=v_user
  for update;
  if not found then raise exception 'Client relationship required'; end if;
  if not p_enabled then
    update public.stk_coach_pro_reminder_opt_ins
      set enabled=false,accepted_cadence_revision=null,updated_at=now()
      where relationship_id=p_relationship_id and client_user_id=v_user;
    return false;
  end if;
  if p_hour_local is null or p_hour_local not between 7 and 22 then
    raise exception 'Invalid reminder hour';
  end if;
  if v_relation.status <> 'active'
     or not coalesce((v_relation.permissions->>'view_checkins')::boolean,false)
     or not coalesce((v_relation.permissions->>'assign_tasks')::boolean,false) then
    raise exception 'Active check-in scheduling permission required';
  end if;
  perform public.stk_assert_coach_pro_access(v_relation.coach_user_id);
  select * into v_cadence from public.stk_coach_pro_checkin_cadences
    where relationship_id=v_relation.id and client_user_id=v_user
      and status='accepted' for update;
  if not found or p_expected_cadence_revision is distinct from v_cadence.revision then
    raise exception 'Accepted check-in cadence changed; refresh';
  end if;

  -- Switching coach relationships turns off old preferences, never sends
  -- an event, and never modifies check-in history.
  update public.stk_coach_pro_reminder_opt_ins
     set enabled=false, accepted_cadence_revision=null,updated_at=now()
   where client_user_id=v_user and relationship_id<>p_relationship_id and enabled;
  insert into public.stk_coach_pro_reminder_opt_ins(
    relationship_id,client_user_id,enabled,hour_local,
    accepted_cadence_revision,updated_at
  ) values(p_relationship_id,v_user,true,p_hour_local,
           v_cadence.revision,now())
  on conflict(relationship_id) do update
    set enabled=true,hour_local=excluded.hour_local,
        accepted_cadence_revision=excluded.accepted_cadence_revision,
        updated_at=now();
  return true;
end;
$$;

revoke all on function public.stk_get_coach_pro_reminder_opt_in(uuid)
  from public,anon,authenticated;
revoke all on function public.stk_set_coach_pro_reminder_opt_in(uuid,boolean,integer,integer)
  from public,anon,authenticated;
grant execute on function public.stk_get_coach_pro_reminder_opt_in(uuid)
  to authenticated;
grant execute on function public.stk_set_coach_pro_reminder_opt_in(uuid,boolean,integer,integer)
  to authenticated;
