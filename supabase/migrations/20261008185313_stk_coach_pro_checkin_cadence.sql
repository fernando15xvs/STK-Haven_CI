-- Roadmap 4 / Coach Pro Phase 3: proposed check-in cadence.
-- This is a consented preference only: no push, alarms, task occurrences or
-- compulsory check-ins. Existing client check-in history remains independent.
create table public.stk_coach_pro_checkin_cadences (
  relationship_id uuid primary key
    references public.stk_coach_client_relationships(id) on delete cascade,
  coach_user_id uuid not null references auth.users(id) on delete cascade,
  client_user_id uuid not null references auth.users(id) on delete cascade,
  weekdays smallint[] not null,
  status text not null default 'proposed'
    check (status in ('proposed', 'accepted', 'declined')),
  revision integer not null default 1 check (revision between 1 and 10000),
  proposed_at timestamptz not null default now(),
  responded_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint stk_coach_pro_checkin_cadence_days check (
    cardinality(weekdays) between 1 and 3
    and weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
  )
);
create index stk_coach_pro_cadence_coach_idx
  on public.stk_coach_pro_checkin_cadences(coach_user_id, status);
alter table public.stk_coach_pro_checkin_cadences enable row level security;
revoke all on public.stk_coach_pro_checkin_cadences from public, anon, authenticated;

-- Coach proposes on an active relationship with both explicit view_checkins
-- and assign_tasks consent. Updating invalidates previous acceptance.
create or replace function public.stk_propose_coach_pro_checkin_cadence(
  p_relationship_id uuid,
  p_weekdays smallint[],
  p_expected_revision integer default null
)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_coach uuid := auth.uid();
  v_relationship public.stk_coach_client_relationships%rowtype;
  v_existing public.stk_coach_pro_checkin_cadences%rowtype;
  v_revision integer;
begin
  if v_coach is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities
                 where user_id=v_coach and capability='coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  select * into v_relationship from public.stk_coach_client_relationships
   where id=p_relationship_id and coach_user_id=v_coach and status='active'
     and coalesce((permissions->>'view_checkins')::boolean,false)
     and coalesce((permissions->>'assign_tasks')::boolean,false)
   for update;
  if not found then raise exception 'Active check-in scheduling permission required'; end if;
  if p_weekdays is null or cardinality(p_weekdays) not between 1 and 3
     or not (p_weekdays <@ array[1,2,3,4,5,6,7]::smallint[])
     or (select count(distinct day) from pg_catalog.unnest(p_weekdays) as day)
        <> cardinality(p_weekdays) then
    raise exception 'Invalid check-in weekdays';
  end if;
  select * into v_existing from public.stk_coach_pro_checkin_cadences
    where relationship_id=p_relationship_id for update;
  if not found then
    if p_expected_revision is not null then
      raise exception 'Check-in cadence changed; refresh';
    end if;
    insert into public.stk_coach_pro_checkin_cadences
      (relationship_id,coach_user_id,client_user_id,weekdays)
    values
      (v_relationship.id,v_coach,v_relationship.client_user_id,p_weekdays);
    return 1;
  end if;
  if p_expected_revision is distinct from v_existing.revision
     or v_existing.revision >= 10000 then
    raise exception 'Check-in cadence changed; refresh';
  end if;
  v_revision := v_existing.revision + 1;
  update public.stk_coach_pro_checkin_cadences
     set weekdays=p_weekdays, status='proposed', revision=v_revision,
         proposed_at=now(), responded_at=null, updated_at=now()
   where relationship_id=p_relationship_id;
  return v_revision;
end;
$$;

-- Client explicitly accepts or declines a proposal; declining an accepted
-- cadence also acts as immediate opt-out. No automatic notifications.
create or replace function public.stk_respond_coach_pro_checkin_cadence(
  p_relationship_id uuid,
  p_expected_revision integer,
  p_accept boolean
)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_relationship public.stk_coach_client_relationships%rowtype;
  v_existing public.stk_coach_pro_checkin_cadences%rowtype;
begin
  if v_user is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if p_accept is null then raise exception 'Decision required'; end if;
  select * into v_relationship from public.stk_coach_client_relationships
   where id=p_relationship_id and client_user_id=v_user and status='active'
     and coalesce((permissions->>'view_checkins')::boolean,false)
     and coalesce((permissions->>'assign_tasks')::boolean,false)
   for update;
  if not found then raise exception 'Active check-in scheduling permission required'; end if;
  select * into v_existing from public.stk_coach_pro_checkin_cadences
    where relationship_id=p_relationship_id and client_user_id=v_user for update;
  if not found then raise exception 'Check-in cadence unavailable'; end if;
  if p_expected_revision is distinct from v_existing.revision
     or v_existing.revision >= 10000 then
    raise exception 'Check-in cadence changed; refresh';
  end if;
  if v_existing.status <> 'proposed' and
     not (v_existing.status = 'accepted' and p_accept = false) then
    raise exception 'Check-in cadence is not awaiting a response';
  end if;
  update public.stk_coach_pro_checkin_cadences
     set status=case when p_accept then 'accepted' else 'declined' end,
         revision=revision+1, responded_at=now(), updated_at=now()
   where relationship_id=p_relationship_id;
  return v_existing.revision+1;
end;
$$;

-- Read always reevaluates current relationship, permissions and coach plan.
-- Neither participant sees this preference after pause/revocation/expiry.
create or replace function public.stk_get_coach_pro_checkin_cadence(
  p_relationship_id uuid
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_relationship public.stk_coach_client_relationships%rowtype;
  v_row public.stk_coach_pro_checkin_cadences%rowtype;
begin
  if v_user is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  select * into v_relationship from public.stk_coach_client_relationships
   where id=p_relationship_id
     and (coach_user_id=v_user or client_user_id=v_user)
     and status='active'
     and coalesce((permissions->>'view_checkins')::boolean,false)
     and coalesce((permissions->>'assign_tasks')::boolean,false);
  if not found then raise exception 'Active check-in scheduling permission required'; end if;
  if v_user = v_relationship.coach_user_id then
    if not exists(select 1 from public.stk_user_capabilities
                  where user_id=v_user and capability='coach') then
      raise exception 'Coach capability required';
    end if;
    perform public.stk_assert_coach_pro_access(v_user);
  end if;
  select * into v_row from public.stk_coach_pro_checkin_cadences
    where relationship_id=v_relationship.id
      and coach_user_id=v_relationship.coach_user_id
      and client_user_id=v_relationship.client_user_id;
  if not found then return null; end if;
  return pg_catalog.jsonb_build_object(
    'relationship_id', v_row.relationship_id,
    'weekdays', pg_catalog.to_jsonb(v_row.weekdays),
    'status', v_row.status,
    'revision', v_row.revision,
    'proposed_at', v_row.proposed_at,
    'responded_at', v_row.responded_at
  );
end;
$$;

revoke all on function public.stk_propose_coach_pro_checkin_cadence(uuid,smallint[],integer) from public, anon, authenticated;
revoke all on function public.stk_respond_coach_pro_checkin_cadence(uuid,integer,boolean) from public, anon, authenticated;
revoke all on function public.stk_get_coach_pro_checkin_cadence(uuid) from public, anon, authenticated;
grant execute on function public.stk_propose_coach_pro_checkin_cadence(uuid,smallint[],integer) to authenticated;
grant execute on function public.stk_respond_coach_pro_checkin_cadence(uuid,integer,boolean) to authenticated;
grant execute on function public.stk_get_coach_pro_checkin_cadence(uuid) to authenticated;
