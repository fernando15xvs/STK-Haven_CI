-- Private development authorization. Never a published legal receipt or production grant.
create table stk_secure.stk_development_nutrition_config (
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false
);
insert into stk_secure.stk_development_nutrition_config(singleton,enabled) values(true,false);
create table stk_secure.stk_development_nutrition_testers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  reviewed_age_band text not null check(reviewed_age_band='18_plus'),
  reviewed_at timestamptz not null default now(),
  expires_at timestamptz not null,
  review_reference text not null check(length(btrim(review_reference)) between 12 and 300),
  revoked_at timestamptz,
  check(expires_at > reviewed_at and expires_at <= reviewed_at + interval '30 days')
);
alter table stk_secure.stk_development_nutrition_config enable row level security;
alter table stk_secure.stk_development_nutrition_testers enable row level security;
revoke all on stk_secure.stk_development_nutrition_config, stk_secure.stk_development_nutrition_testers from public,anon,authenticated,service_role;

-- Only the database administrator can enroll a reviewed adult tester.
-- The service role can check a particular authenticated session, not write grants.
create or replace function public.stk_service_can_use_development_nutrition(
  p_user_id uuid,p_session_id uuid
) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from stk_secure.stk_development_nutrition_config c
    where c.singleton and c.enabled)
  and not exists(select 1 from stk_secure.stk_legal_releases r
    where r.is_current and r.published_at <= now())
  and exists(select 1 from stk_secure.stk_development_nutrition_testers t
    join auth.users u on u.id=t.user_id
    join auth.sessions s on s.user_id=u.id
    where t.user_id=p_user_id and s.id=p_session_id
      and (s.not_after is null or s.not_after>now())
      and not coalesce(u.is_anonymous,false) and u.email_confirmed_at is not null
      and t.reviewed_age_band='18_plus' and t.reviewed_at<=now()
      and t.expires_at>now() and t.revoked_at is null);
$$;
revoke all on function public.stk_service_can_use_development_nutrition(uuid,uuid) from public,anon,authenticated;
grant execute on function public.stk_service_can_use_development_nutrition(uuid,uuid) to service_role;

create or replace function public.stk_get_development_nutrition_access()
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null
    and not coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
    and exists(select 1 from auth.sessions s where s.user_id=auth.uid()
      and s.id::text=auth.jwt()->>'session_id'
      and public.stk_service_can_use_development_nutrition(auth.uid(),s.id));
$$;
revoke all on function public.stk_get_development_nutrition_access() from public,anon,authenticated;
grant execute on function public.stk_get_development_nutrition_access() to authenticated;
