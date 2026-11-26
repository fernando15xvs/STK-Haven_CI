-- Source for CLI-generated migration. Do not edit previously applied migrations.
-- Fix legacy cross-coach reads without changing existing RPC signatures.
create or replace function public.stk_list_coach_checkins(p_client_user_id uuid)
returns table(id uuid,relationship_id uuid,coach_user_id uuid,client_user_id uuid,energy smallint,recovery smallint,note text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Permanent authenticated account required'; end if;
  if auth.uid()<>p_client_user_id and not public.stk_coach_can_access(p_client_user_id,'view_checkins') then raise exception 'Check-in permission required'; end if;
  return query select c.id,c.relationship_id,c.coach_user_id,c.client_user_id,c.energy,c.recovery,c.note,c.created_at
  from public.stk_coach_checkins c where c.client_user_id=p_client_user_id
    and (auth.uid()=c.client_user_id or (auth.uid()=c.coach_user_id and public.stk_coach_can_access(c.client_user_id,'view_checkins'))) order by c.created_at desc limit 100;
end $$;
create or replace function public.stk_list_coach_checkin_comments(p_checkin_id uuid)
returns table(id uuid,checkin_id uuid,author_user_id uuid,body text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare c public.stk_coach_checkins%rowtype;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Permanent authenticated account required'; end if;
  select * into c from public.stk_coach_checkins where id=p_checkin_id;
  if not found then raise exception 'Check-in not found'; end if;
  if auth.uid()<>c.client_user_id and (auth.uid()<>c.coach_user_id or not public.stk_coach_can_access(c.client_user_id,'view_checkins')) then raise exception 'Check-in permission required'; end if;
  return query select x.id,x.checkin_id,x.author_user_id,x.body,x.created_at from public.stk_coach_checkin_comments x where x.checkin_id=p_checkin_id order by x.created_at;
end $$;
create or replace function public.stk_add_coach_checkin_comment(p_checkin_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.stk_coach_checkins%rowtype; v_id uuid;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Permanent authenticated account required'; end if;
  select * into c from public.stk_coach_checkins where id=p_checkin_id;
  if not found then raise exception 'Check-in not found'; end if;
  if auth.uid()<>c.client_user_id and (auth.uid()<>c.coach_user_id or not public.stk_coach_can_access(c.client_user_id,'comment') or not public.stk_coach_can_access(c.client_user_id,'view_checkins')) then raise exception 'Comment permission required'; end if;
  if char_length(btrim(coalesce(p_body,''))) not between 1 and 2000 then raise exception 'Comment length invalid'; end if;
  insert into public.stk_coach_checkin_comments(checkin_id,author_user_id,body) values(c.id,auth.uid(),btrim(p_body)) returning id into v_id;
  return v_id;
end $$;
create or replace function public.stk_create_coach_checkin(
  p_relationship_id uuid, p_energy integer, p_recovery integer, p_note text default ''
) returns uuid language plpgsql security definer set search_path='' as $$
declare r public.stk_coach_client_relationships%rowtype; v_id uuid;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Permanent authenticated account required'; end if;
  select * into r from public.stk_coach_client_relationships where id=p_relationship_id and client_user_id=auth.uid() and status='active' for share;
  if not found or not coalesce((r.permissions->>'view_checkins')::boolean,false) then raise exception 'Check-in permission required'; end if;
  if p_energy not between 1 and 5 or p_recovery not between 1 and 5 then raise exception 'Check-in score out of range'; end if;
  insert into public.stk_coach_checkins(relationship_id,coach_user_id,client_user_id,energy,recovery,note)
  values(r.id,r.coach_user_id,r.client_user_id,p_energy,p_recovery,left(coalesce(p_note,''),2000)) returning id into v_id;
  return v_id;
end $$;
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
      and (v_user_id = task.client_user_id or task.coach_user_id = v_user_id)
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
-- Explicit relationship-scoped snapshot, not a copy of the user's Hive history.
create table stk_secure.stk_coach_measurement_shares (
  relationship_id uuid primary key references public.stk_coach_client_relationships(id) on delete cascade,
  measured_at timestamptz not null,
  shared_at timestamptz not null default now(),
  values_json jsonb not null check (jsonb_typeof(values_json)='object')
);
alter table stk_secure.stk_coach_measurement_shares enable row level security;
revoke all on stk_secure.stk_coach_measurement_shares from public,anon,authenticated,service_role;

-- Authenticated callers must have a live permanent identity. No user-editable
-- metadata, no arbitrary client id and no automatic sharing of body data.
create function stk_secure.stk_coach_qa_permanent_actor()
returns uuid language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
  if actor is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
    or not exists(select 1 from auth.users u where u.id=actor and not coalesce(u.is_anonymous,false))
  then raise exception 'Permanent authenticated account required'; end if;
  return actor;
end $$;
revoke all on function stk_secure.stk_coach_qa_permanent_actor() from public,anon,authenticated,service_role;

create function public.stk_share_coach_measurements(p_relationship_id uuid,p_measured_at timestamptz,p_values jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=stk_secure.stk_coach_qa_permanent_actor(); r public.stk_coach_client_relationships%rowtype; item record; n numeric;
begin
  select * into r from public.stk_coach_client_relationships
    where id=p_relationship_id and client_user_id=actor and status='active' for update;
  if not found or not coalesce((r.permissions->>'view_measurements')::boolean,false)
    then raise exception 'Measurement permission required'; end if;
  if p_measured_at is null or p_measured_at>now()+interval '1 day' or p_measured_at<timestamp '1900-01-01'
    or p_values is null or jsonb_typeof(p_values)<>'object' or p_values='{}'::jsonb
    or pg_column_size(p_values)>4096 then raise exception 'Invalid measurement snapshot'; end if;
  for item in select key,value from jsonb_each(p_values) loop
    if item.key not in ('weightKg','bodyFatPercentage','heightCm','shouldersCm','chestCm','waistCm','hipsCm','leftArmCm','rightArmCm','leftLegCm','rightLegCm','calvesCm','neckCm','leftForearmCm','rightForearmCm','leftCalfCm','rightCalfCm')
      or jsonb_typeof(item.value)<>'number' then raise exception 'Invalid measurement snapshot'; end if;
    n:=(item.value #>> '{}')::numeric;
    if (item.key='bodyFatPercentage' and (n<0 or n>100)) or (item.key<>'bodyFatPercentage' and (n<=0 or n>500))
      then raise exception 'Invalid measurement snapshot'; end if;
  end loop;
  insert into stk_secure.stk_coach_measurement_shares(relationship_id,measured_at,shared_at,values_json)
    values(r.id,p_measured_at,now(),p_values)
    on conflict(relationship_id) do update set measured_at=excluded.measured_at, shared_at=excluded.shared_at,values_json=excluded.values_json;
end $$;
create function public.stk_get_coach_measurements(p_relationship_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=stk_secure.stk_coach_qa_permanent_actor(); r public.stk_coach_client_relationships%rowtype; result jsonb;
begin
  select * into r from public.stk_coach_client_relationships
    where id=p_relationship_id and (client_user_id=actor or coach_user_id=actor) and status='active';
  if not found or not coalesce((r.permissions->>'view_measurements')::boolean,false)
    then raise exception 'Measurement permission required'; end if;
  if r.coach_user_id=actor then
    perform public.stk_assert_coach_pro_access(actor);
    if not exists(select 1 from public.stk_user_capabilities where user_id=actor and capability='coach')
      then raise exception 'Coach capability required'; end if;
  end if;
  select jsonb_build_object('relationship_id',s.relationship_id,'measured_at',s.measured_at,'shared_at',s.shared_at,'values',s.values_json)
    into result from stk_secure.stk_coach_measurement_shares s where s.relationship_id=r.id;
  return result;
end $$;
create function public.stk_clear_coach_measurements(p_relationship_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=stk_secure.stk_coach_qa_permanent_actor();
begin
  if not exists(select 1 from public.stk_coach_client_relationships r where r.id=p_relationship_id and r.client_user_id=actor)
    then raise exception 'Measurement permission required'; end if;
  delete from stk_secure.stk_coach_measurement_shares where relationship_id=p_relationship_id;
end $$;
revoke all on function public.stk_share_coach_measurements(uuid,timestamptz,jsonb) from public,anon,service_role;
revoke all on function public.stk_get_coach_measurements(uuid) from public,anon,service_role;
revoke all on function public.stk_clear_coach_measurements(uuid) from public,anon,service_role;
grant execute on function public.stk_share_coach_measurements(uuid,timestamptz,jsonb) to authenticated;
grant execute on function public.stk_get_coach_measurements(uuid) to authenticated;
grant execute on function public.stk_clear_coach_measurements(uuid) to authenticated;

create function stk_secure.stk_purge_revoked_coach_measurements()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.status<>'active' or not coalesce((new.permissions->>'view_measurements')::boolean,false) then
    delete from stk_secure.stk_coach_measurement_shares where relationship_id=new.id;
  end if;
  return new;
end $$;
revoke all on function stk_secure.stk_purge_revoked_coach_measurements() from public,anon,authenticated,service_role;
create trigger stk_purge_revoked_coach_measurements after update of status,permissions on public.stk_coach_client_relationships
for each row execute function stk_secure.stk_purge_revoked_coach_measurements();

-- Private administrator-only development grant. Does not activate any account
-- on deployment, does not overwrite commercial entitlements or bypass consent.
create function stk_secure.stk_grant_coach_development_trial(p_user_id uuid,p_days integer,p_client_limit integer,p_event_key text)
returns boolean language plpgsql security invoker set search_path='' as $$
begin
  if p_days is null or p_days not between 1 and 30 or p_client_limit is null or p_client_limit not between 1 and 5
    or p_event_key is null or length(btrim(p_event_key)) not between 12 and 160
    then raise exception 'Invalid development trial bounds'; end if;
  if not exists(select 1 from auth.users u where u.id=p_user_id and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false))
    or not exists(select 1 from public.stk_user_capabilities where user_id=p_user_id and capability='coach')
    then raise exception 'Confirmed coach account required'; end if;
  if exists(select 1 from public.stk_subscription_entitlements where user_id=p_user_id and product='coach_pro' and source<>'development_qa')
    then raise exception 'Existing non-development entitlement'; end if;
  return public.stk_set_subscription_entitlement(p_user_id,'coach_pro','trial','development_qa',p_client_limit,now(),now()+make_interval(days=>p_days),null,'development_qa',p_event_key);
end $$;
revoke all on function stk_secure.stk_grant_coach_development_trial(uuid,integer,integer,text) from public,anon,authenticated,service_role;

-- Private administrative cancellation; no client-callable access and no
-- deletion of personal records. Only development grants can be canceled here.
create function stk_secure.stk_revoke_coach_development_trial(p_user_id uuid,p_event_key text)
returns boolean language plpgsql security invoker set search_path='' as $$
declare grant_row public.stk_subscription_entitlements%rowtype;
begin
  if p_event_key is null or length(btrim(p_event_key)) not between 12 and 160 then raise exception 'Invalid development trial bounds'; end if;
  select * into grant_row from public.stk_subscription_entitlements where user_id=p_user_id and product='coach_pro' and source='development_qa' for update;
  if not found then raise exception 'Development trial not found'; end if;
  return public.stk_set_subscription_entitlement(p_user_id,'coach_pro','canceled',grant_row.tier,grant_row.client_limit,grant_row.starts_at,now(),null,'development_qa',p_event_key);
end $$;
revoke all on function stk_secure.stk_revoke_coach_development_trial(uuid,text) from public,anon,authenticated,service_role;

-- Adherence on a particular relationship for both participants.
create or replace function public.stk_get_coach_relationship_task_adherence(
  p_relationship_id uuid,
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
  r public.stk_coach_client_relationships%rowtype;
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

  select * into r from public.stk_coach_client_relationships where id=p_relationship_id and (client_user_id=v_user_id or coach_user_id=v_user_id);
  if not found or (r.client_user_id<>v_user_id and (r.status<>'active' or not coalesce((r.permissions->>'assign_tasks')::boolean,false))) then
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
    where task.relationship_id = r.id and task.client_user_id = r.client_user_id
      and (v_user_id = task.client_user_id or task.coach_user_id = v_user_id)
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
    'client_user_id', r.client_user_id,
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
revoke all on function public.stk_get_coach_relationship_task_adherence(uuid,integer) from public,anon;
grant execute on function public.stk_get_coach_relationship_task_adherence(uuid,integer) to authenticated;
