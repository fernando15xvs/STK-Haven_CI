create table if not exists public.haven_faith_rate_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  minute_window_start timestamptz not null default now(),
  minute_count integer not null default 0 check (minute_count >= 0),
  day_window_start date not null default current_date,
  day_count integer not null default 0 check (day_count >= 0),
  updated_at timestamptz not null default now()
);

alter table public.haven_faith_rate_limits enable row level security;

revoke all on table public.haven_faith_rate_limits from public, anon, authenticated;
grant select, insert, update, delete on table public.haven_faith_rate_limits to service_role;

create or replace function public.consume_haven_faith_quota(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_row public.haven_faith_rate_limits%rowtype;
  v_minute_limit constant integer := 12;
  v_day_limit constant integer := 100;
begin
  if p_user_id is null then
    return jsonb_build_object('allowed', false, 'reason', 'invalid_user');
  end if;

  insert into public.haven_faith_rate_limits (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select *
    into v_row
    from public.haven_faith_rate_limits
   where user_id = p_user_id
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
    update public.haven_faith_rate_limits
       set minute_window_start = v_row.minute_window_start,
           minute_count = v_row.minute_count,
           day_window_start = v_row.day_window_start,
           day_count = v_row.day_count,
           updated_at = v_now
     where user_id = p_user_id;

    return jsonb_build_object(
      'allowed', false,
      'reason', 'minute_limit',
      'retry_after_seconds', greatest(
        1,
        ceil(extract(epoch from ((v_row.minute_window_start + interval '1 minute') - v_now)))::integer
      )
    );
  end if;

  if v_row.day_count >= v_day_limit then
    update public.haven_faith_rate_limits
       set minute_window_start = v_row.minute_window_start,
           minute_count = v_row.minute_count,
           day_window_start = v_row.day_window_start,
           day_count = v_row.day_count,
           updated_at = v_now
     where user_id = p_user_id;

    return jsonb_build_object('allowed', false, 'reason', 'day_limit');
  end if;

  v_row.minute_count := v_row.minute_count + 1;
  v_row.day_count := v_row.day_count + 1;

  update public.haven_faith_rate_limits
     set minute_window_start = v_row.minute_window_start,
         minute_count = v_row.minute_count,
         day_window_start = v_row.day_window_start,
         day_count = v_row.day_count,
         updated_at = v_now
   where user_id = p_user_id;

  return jsonb_build_object(
    'allowed', true,
    'remaining_minute', greatest(0, v_minute_limit - v_row.minute_count),
    'remaining_day', greatest(0, v_day_limit - v_row.day_count)
  );
end;
$$;

revoke all on function public.consume_haven_faith_quota(uuid) from public, anon, authenticated;
grant execute on function public.consume_haven_faith_quota(uuid) to service_role;
