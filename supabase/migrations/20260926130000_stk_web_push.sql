-- Roadmap 3.0 / Web Push subscriptions.
-- Subscription endpoints and encryption keys are private backend data.
create table if not exists public.stk_web_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth_key text not null,
  user_agent text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  disabled_at timestamptz
);

create index if not exists stk_web_push_user_idx
  on public.stk_web_push_subscriptions(user_id, disabled_at);

alter table public.stk_web_push_subscriptions enable row level security;

revoke all on public.stk_web_push_subscriptions
  from public, anon, authenticated;
grant select, insert, update, delete on public.stk_web_push_subscriptions
  to service_role;

create or replace function public.stk_upsert_web_push_subscription(
  p_endpoint text,
  p_p256dh text,
  p_auth text,
  p_user_agent text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null
     or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;

  if char_length(btrim(coalesce(p_endpoint,''))) < 20
     or char_length(btrim(coalesce(p_p256dh,''))) < 20
     or char_length(btrim(coalesce(p_auth,''))) < 8 then
    raise exception 'Invalid Web Push subscription';
  end if;

  insert into public.stk_web_push_subscriptions(
    user_id, endpoint, p256dh, auth_key, user_agent, disabled_at, updated_at
  )
  values(
    v_user_id,
    btrim(p_endpoint),
    btrim(p_p256dh),
    btrim(p_auth),
    left(coalesce(p_user_agent,''),500),
    null,
    now()
  )
  on conflict(endpoint) do update
    set user_id = excluded.user_id,
        p256dh = excluded.p256dh,
        auth_key = excluded.auth_key,
        user_agent = excluded.user_agent,
        disabled_at = null,
        updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.stk_disable_web_push_subscription(
  p_endpoint text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_count integer;
begin
  if v_user_id is null
     or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    return false;
  end if;

  update public.stk_web_push_subscriptions
     set disabled_at = now(), updated_at = now()
   where user_id = v_user_id
     and endpoint = btrim(coalesce(p_endpoint,''))
     and disabled_at is null;

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

create or replace function public.stk_has_web_push_subscription()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when auth.uid() is null
      or coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
    then false
    else exists(
      select 1
        from public.stk_web_push_subscriptions s
       where s.user_id = auth.uid()
         and s.disabled_at is null
    )
  end;
$$;

revoke all on function public.stk_upsert_web_push_subscription(text,text,text,text)
  from public, anon;
revoke all on function public.stk_disable_web_push_subscription(text)
  from public, anon;
revoke all on function public.stk_has_web_push_subscription()
  from public, anon;

grant execute on function public.stk_upsert_web_push_subscription(text,text,text,text)
  to authenticated;
grant execute on function public.stk_disable_web_push_subscription(text)
  to authenticated;
grant execute on function public.stk_has_web_push_subscription()
  to authenticated;
