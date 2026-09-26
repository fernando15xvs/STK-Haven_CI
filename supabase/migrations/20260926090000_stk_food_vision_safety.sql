-- Roadmap 3.0 / Nutrition Intelligence safety gates.
-- No client can grant itself adult nutrition access or mutate quota/metrics.
create table if not exists public.stk_nutrition_adult_verifications (
  user_id uuid primary key references auth.users(id) on delete cascade,
  verified_at timestamptz not null,
  verification_method text not null check (char_length(btrim(verification_method)) between 2 and 80),
  revoked_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.stk_food_vision_rate_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  minute_window_start timestamptz not null default now(),
  minute_count integer not null default 0 check (minute_count >= 0),
  day_window_start date not null default current_date,
  day_count integer not null default 0 check (day_count >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.stk_food_vision_daily_metrics (
  metric_date date not null default current_date,
  numeric_mode boolean not null default false,
  confidence text not null default 'unknown'
    check (confidence in ('unknown','low','medium','high')),
  success_count integer not null default 0 check (success_count >= 0),
  error_count integer not null default 0 check (error_count >= 0),
  primary key (metric_date, numeric_mode, confidence)
);

alter table public.stk_nutrition_adult_verifications enable row level security;
alter table public.stk_food_vision_rate_limits enable row level security;
alter table public.stk_food_vision_daily_metrics enable row level security;

revoke all on public.stk_nutrition_adult_verifications from public, anon, authenticated;
revoke all on public.stk_food_vision_rate_limits from public, anon, authenticated;
revoke all on public.stk_food_vision_daily_metrics from public, anon, authenticated;
grant select, insert, update, delete on public.stk_nutrition_adult_verifications to service_role;
grant select, insert, update, delete on public.stk_food_vision_rate_limits to service_role;
grant select, insert, update, delete on public.stk_food_vision_daily_metrics to service_role;

create or replace function public.stk_has_adult_nutrition_access()
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null
     or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    return false;
  end if;
  return exists(
    select 1
      from public.stk_nutrition_adult_verifications v
     where v.user_id = auth.uid()
       and v.revoked_at is null
       and v.verified_at <= now()
  );
end;
$$;

create or replace function public.stk_set_adult_nutrition_verification(
  p_user_id uuid,
  p_verified boolean,
  p_method text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null then
    raise exception 'user required';
  end if;
  if p_verified then
    insert into public.stk_nutrition_adult_verifications(
      user_id, verified_at, verification_method, revoked_at, updated_at
    )
    values(
      p_user_id, now(), left(btrim(coalesce(p_method,'backend_verified')),80),
      null, now()
    )
    on conflict (user_id) do update
      set verified_at = excluded.verified_at,
          verification_method = excluded.verification_method,
          revoked_at = null,
          updated_at = now();
  else
    update public.stk_nutrition_adult_verifications
       set revoked_at = now(), updated_at = now()
     where user_id = p_user_id;
  end if;
end;
$$;

create or replace function public.consume_stk_food_vision_quota(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_row public.stk_food_vision_rate_limits%rowtype;
  v_minute_limit constant integer := 6;
  v_day_limit constant integer := 60;
begin
  if p_user_id is null then
    return jsonb_build_object('allowed',false,'reason','invalid_user');
  end if;

  insert into public.stk_food_vision_rate_limits(user_id)
  values(p_user_id)
  on conflict(user_id) do nothing;

  select * into v_row
    from public.stk_food_vision_rate_limits
   where user_id=p_user_id
   for update;

  if v_now >= v_row.minute_window_start + interval '1 minute' then
    v_row.minute_window_start := v_now;
    v_row.minute_count := 0;
  end if;
  if current_date > v_row.day_window_start then
    v_row.day_window_start := current_date;
    v_row.day_count := 0;
  end if;

  if v_row.minute_count >= v_minute_limit then
    update public.stk_food_vision_rate_limits
       set minute_window_start=v_row.minute_window_start,
           minute_count=v_row.minute_count,
           day_window_start=v_row.day_window_start,
           day_count=v_row.day_count,
           updated_at=v_now
     where user_id=p_user_id;
    return jsonb_build_object(
      'allowed',false,
      'reason','minute_limit',
      'retry_after_seconds',greatest(
        1,
        ceil(extract(epoch from (
          (v_row.minute_window_start + interval '1 minute') - v_now
        )))::integer
      )
    );
  end if;

  if v_row.day_count >= v_day_limit then
    return jsonb_build_object('allowed',false,'reason','day_limit');
  end if;

  update public.stk_food_vision_rate_limits
     set minute_window_start=v_row.minute_window_start,
         minute_count=v_row.minute_count + 1,
         day_window_start=v_row.day_window_start,
         day_count=v_row.day_count + 1,
         updated_at=v_now
   where user_id=p_user_id;

  return jsonb_build_object(
    'allowed',true,
    'remaining_minute',greatest(0,v_minute_limit-(v_row.minute_count+1)),
    'remaining_day',greatest(0,v_day_limit-(v_row.day_count+1))
  );
end;
$$;

create or replace function public.record_stk_food_vision_metric(
  p_numeric_mode boolean,
  p_confidence text,
  p_success boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_confidence text :=
    case when p_confidence in ('low','medium','high') then p_confidence
         else 'unknown' end;
begin
  insert into public.stk_food_vision_daily_metrics(
    metric_date,numeric_mode,confidence,success_count,error_count
  )
  values(
    current_date,coalesce(p_numeric_mode,false),v_confidence,
    case when p_success then 1 else 0 end,
    case when p_success then 0 else 1 end
  )
  on conflict(metric_date,numeric_mode,confidence) do update
    set success_count=public.stk_food_vision_daily_metrics.success_count+
        case when p_success then 1 else 0 end,
        error_count=public.stk_food_vision_daily_metrics.error_count+
        case when p_success then 0 else 1 end;
end;
$$;

revoke all on function public.stk_has_adult_nutrition_access() from public, anon;
grant execute on function public.stk_has_adult_nutrition_access() to authenticated;

revoke all on function public.stk_set_adult_nutrition_verification(uuid,boolean,text)
  from public, anon, authenticated;
grant execute on function public.stk_set_adult_nutrition_verification(uuid,boolean,text)
  to service_role;

revoke all on function public.consume_stk_food_vision_quota(uuid)
  from public, anon, authenticated;
grant execute on function public.consume_stk_food_vision_quota(uuid)
  to service_role;

revoke all on function public.record_stk_food_vision_metric(boolean,text,boolean)
  from public, anon, authenticated;
grant execute on function public.record_stk_food_vision_metric(boolean,text,boolean)
  to service_role;
