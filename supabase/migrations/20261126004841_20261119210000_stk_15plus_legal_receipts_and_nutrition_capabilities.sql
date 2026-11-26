-- STK Haven P0/P1: staged 15+ legal receipts and independent capabilities.
-- Source-only migration. DO NOT deploy until legal/clinical review and approval.
-- No seed inserts: on migration the feature stays OFF for every real user.
-- No mandatory external identity-verification provider; a declared DOB alone
-- NEVER grants numeric nutrition access.

create schema if not exists stk_secure;
revoke all on schema stk_secure from public, anon, authenticated;
grant usage on schema stk_secure to service_role;

create table stk_secure.stk_legal_releases (
  id uuid primary key default gen_random_uuid(),
  terms_version text not null check (length(btrim(terms_version)) between 1 and 64),
  terms_sha256 text not null check (terms_sha256 ~ '^[a-f0-9]{64}$'),
  terms_https_url text not null check (terms_https_url ~ '^https://[^/ ]+'),
  privacy_version text not null check (length(btrim(privacy_version)) between 1 and 64),
  privacy_sha256 text not null check (privacy_sha256 ~ '^[a-f0-9]{64}$'),
  privacy_https_url text not null check (privacy_https_url ~ '^https://[^/ ]+'),
  approved_reference text not null check (length(btrim(approved_reference)) between 12 and 300),
  published_at timestamptz not null,
  informational_estimates_clinically_approved boolean not null default false,
  is_current boolean not null default false,
  created_at timestamptz not null default now()
);
create unique index stk_one_current_legal_release
  on stk_secure.stk_legal_releases(is_current) where is_current;

-- A receipt is server-stamped and tied to auth.uid(), the currently approved
-- document hashes, and the accepted age BAND. The age band is explicitly a
-- declaration, not proof of age or a privileged grant.
create table stk_secure.stk_legal_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  release_id uuid not null references stk_secure.stk_legal_releases(id),
  declared_age_band text not null
    check (declared_age_band in ('15_17', '18_plus')),
  accepted_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique(user_id, release_id)
);

-- Append-only receipt events preserve acceptance/revocation chronology even
-- when the current receipt row is updated after a later re-acceptance.
create table stk_secure.stk_legal_receipt_audit (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  release_id uuid not null references stk_secure.stk_legal_releases(id),
  event text not null check (event in ('accepted', 'revoked')),
  declared_age_band text not null,
  occurred_at timestamptz not null default now()
);

-- Every numeric capability requires an explicit privileged review decision.
-- Reviewed age band must come from a trusted operator workflow, NOT a field
-- supplied by the untrusted Flutter client.
create table stk_secure.stk_nutrition_capability_grants (
  user_id uuid not null references auth.users(id) on delete cascade,
  capability text not null check (capability in
    ('informationalFoodEstimate','personalizedAdultEnergy')),
  release_id uuid not null references stk_secure.stk_legal_releases(id),
  reviewed_age_band text not null
    check (reviewed_age_band in ('15_17', '18_plus')),
  review_reference text not null
    check (length(btrim(review_reference)) between 12 and 300),
  granted_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  primary key (user_id, capability)
);

create table stk_secure.stk_nutrition_capability_audit (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  capability text not null,
  decision text not null check (decision in ('grant','revoke','legal_withdrawn')),
  policy_release_id uuid,
  review_reference text not null,
  occurred_at timestamptz not null default now()
);

alter table stk_secure.stk_legal_releases enable row level security;
alter table stk_secure.stk_legal_receipts enable row level security;
alter table stk_secure.stk_legal_receipt_audit enable row level security;
alter table stk_secure.stk_nutrition_capability_grants enable row level security;
alter table stk_secure.stk_nutrition_capability_audit enable row level security;

revoke all on all tables in schema stk_secure from public, anon, authenticated;
grant select, insert, update, delete on all tables in schema stk_secure to service_role;
grant usage, select on all sequences in schema stk_secure to service_role;

-- Metadata read only. A build cannot claim terms are published if there is no
-- matching release created by an explicitly authorized service workflow.
create or replace function public.stk_get_current_legal_release()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_release stk_secure.stk_legal_releases%rowtype;
begin
  select * into v_release from stk_secure.stk_legal_releases
   where is_current = true and published_at <= now() limit 1;
  if not found then return null; end if;
  return pg_catalog.jsonb_build_object(
    'termsVersion',v_release.terms_version,
    'termsSha256',v_release.terms_sha256,
    'termsUrl',v_release.terms_https_url,
    'privacyVersion',v_release.privacy_version,
    'privacySha256',v_release.privacy_sha256,
    'privacyUrl',v_release.privacy_https_url
  );
end;
$$;

create or replace function public.stk_record_legal_acceptance(
  p_terms_version text, p_terms_sha256 text,
  p_privacy_version text, p_privacy_sha256 text,
  p_declared_age_band text
)
returns uuid
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_release stk_secure.stk_legal_releases%rowtype;
  v_receipt_id uuid;
begin
  if v_uid is null
     or coalesce((auth.jwt()->>'is_anonymous')::boolean, false)
     or not exists (
       select 1 from auth.sessions s
       where s.user_id = v_uid
         and s.id::text = auth.jwt()->>'session_id'
         and (s.not_after is null or s.not_after > now())
     ) then
    raise exception 'Permanent authenticated account required';
  end if;
  if p_declared_age_band not in ('15_17', '18_plus') then
    raise exception 'Eligible age declaration required';
  end if;
  select * into v_release from stk_secure.stk_legal_releases
    where is_current = true and published_at <= now() limit 1;
  if not found
    or p_terms_version is distinct from v_release.terms_version
    or lower(p_terms_sha256) is distinct from v_release.terms_sha256
    or p_privacy_version is distinct from v_release.privacy_version
    or lower(p_privacy_sha256) is distinct from v_release.privacy_sha256 then
    raise exception 'Current published legal documents required';
  end if;

  insert into stk_secure.stk_legal_receipts
    (user_id, release_id, declared_age_band)
  values (v_uid, v_release.id, p_declared_age_band)
  on conflict (user_id, release_id) do update
    set declared_age_band = excluded.declared_age_band,
        accepted_at = now(), revoked_at = null
  returning id into v_receipt_id;
  insert into stk_secure.stk_legal_receipt_audit
    (user_id,release_id,event,declared_age_band)
  values (v_uid,v_release.id,'accepted',p_declared_age_band);

  -- Renewing consent (even unchanged text/band) invalidates EVERY old
  -- review. Log every invalidation rather than silently revoking a grant.
  insert into stk_secure.stk_nutrition_capability_audit
    (user_id, capability, decision, policy_release_id, review_reference)
  select g.user_id, g.capability, 'revoke', g.release_id,
         'legal acceptance renewed: prior grant invalidated'
    from stk_secure.stk_nutrition_capability_grants g
   where g.user_id = v_uid and g.revoked_at is null;
  update stk_secure.stk_nutrition_capability_grants
     set revoked_at = now()
   where user_id = v_uid and revoked_at is null;
  return v_receipt_id;
end;
$$;

create or replace function public.stk_revoke_legal_acceptance()
returns boolean
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_capability text;
begin
  if v_uid is null
    or coalesce((auth.jwt()->>'is_anonymous')::boolean, false)
    or not exists (
      select 1 from auth.sessions s
      where s.user_id = v_uid
        and s.id::text = auth.jwt()->>'session_id'
        and (s.not_after is null or s.not_after > now())
    ) then
    return false;
  end if;
  insert into stk_secure.stk_legal_receipt_audit
    (user_id,release_id,event,declared_age_band)
  select user_id,release_id,'revoked',declared_age_band
    from stk_secure.stk_legal_receipts
    where user_id = v_uid and revoked_at is null;
  update stk_secure.stk_legal_receipts set revoked_at = now()
    where user_id = v_uid and revoked_at is null;
  for v_capability in
    select capability from stk_secure.stk_nutrition_capability_grants
    where user_id = v_uid and revoked_at is null for update
  loop
    insert into stk_secure.stk_nutrition_capability_audit
      (user_id, capability, decision, review_reference)
    values (v_uid, v_capability, 'legal_withdrawn', 'user revoked legal acceptance');
  end loop;
  update stk_secure.stk_nutrition_capability_grants
    set revoked_at = now() where user_id = v_uid and revoked_at is null;
  return true;
end;
$$;

-- Only the service role can call this. It is deliberately NOT an automatic
-- result of an accepted terms checkbox, a self-declared age, or profile data.
create or replace function public.stk_service_set_nutrition_capability(
  p_user_id uuid, p_capability text, p_reviewed_age_band text,
  p_granted boolean, p_review_reference text, p_expires_at timestamptz
)
returns boolean
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_release stk_secure.stk_legal_releases%rowtype;
  v_declared_age_band text;
begin
  if p_user_id is null
    or p_capability not in ('informationalFoodEstimate','personalizedAdultEnergy')
    or length(btrim(coalesce(p_review_reference, ''))) not between 12 and 300 then
    raise exception 'Invalid privileged capability review';
  end if;
  if not coalesce(p_granted, false) then
    update stk_secure.stk_nutrition_capability_grants
      set revoked_at = now()
      where user_id = p_user_id and capability = p_capability
        and revoked_at is null;
    insert into stk_secure.stk_nutrition_capability_audit
      (user_id,capability,decision,review_reference)
    values (p_user_id,p_capability,'revoke',p_review_reference);
    return true;
  end if;
  if p_reviewed_age_band not in ('15_17','18_plus')
    or p_expires_at is null or p_expires_at <= now()
    or p_expires_at > now() + interval '400 days' then
    raise exception 'Invalid age review or grant expiration';
  end if;
  if p_capability = 'personalizedAdultEnergy'
     and p_reviewed_age_band <> '18_plus' then
    raise exception 'Adult energy requires trusted adult review';
  end if;
  select * into v_release from stk_secure.stk_legal_releases
    where is_current = true and published_at <= now() limit 1;
  if not found then raise exception 'No published policy'; end if;
  if p_capability = 'informationalFoodEstimate'
      and not v_release.informational_estimates_clinically_approved then
    raise exception 'Clinical review has not approved informational estimates';
  end if;

  select declared_age_band into v_declared_age_band
    from stk_secure.stk_legal_receipts
    where user_id = p_user_id and release_id = v_release.id
      and revoked_at is null;
  if not found or v_declared_age_band <> p_reviewed_age_band then
    raise exception 'Current matching legal receipt required';
  end if;

  insert into stk_secure.stk_nutrition_capability_grants
    (user_id,capability,release_id,reviewed_age_band,review_reference,expires_at)
  values (p_user_id,p_capability,v_release.id,p_reviewed_age_band,
    p_review_reference,p_expires_at)
  on conflict (user_id,capability) do update
  set release_id = excluded.release_id,
      reviewed_age_band = excluded.reviewed_age_band,
      review_reference = excluded.review_reference,
      expires_at = excluded.expires_at,
      granted_at = now(),
      revoked_at = null;
  insert into stk_secure.stk_nutrition_capability_audit
    (user_id,capability,decision,policy_release_id,review_reference)
  values (p_user_id,p_capability,'grant',v_release.id,p_review_reference);
  return true;
end;
$$;

-- Service-only check used by the Food Vision Edge Function, with a subject
-- obtained from a verified JWT, never arbitrary user input from the app.
create or replace function public.stk_service_can_use_nutrition_capability(
  p_user_id uuid, p_capability text
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists(
    select 1
    from stk_secure.stk_nutrition_capability_grants g
    join stk_secure.stk_legal_releases p on p.id = g.release_id
    join stk_secure.stk_legal_receipts r on r.user_id = g.user_id
      and r.release_id = g.release_id and r.revoked_at is null
    where g.user_id = p_user_id and g.capability = p_capability
      and g.revoked_at is null and g.granted_at <= now()
      and g.expires_at > now() and p.is_current
      and p.published_at <= now()
      and g.reviewed_age_band = r.declared_age_band
      and (g.capability <> 'personalizedAdultEnergy'
        or g.reviewed_age_band = '18_plus')
      and (g.capability <> 'informationalFoodEstimate'
        or p.informational_estimates_clinically_approved)
  );
$$;

create or replace function public.stk_get_nutrition_capabilities()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null
    or coalesce((auth.jwt()->>'is_anonymous')::boolean, false) then
    return pg_catalog.jsonb_build_object(
      'personalizedAdultEnergy',false,
      'informationalFoodEstimate',false,
      'legalCurrent',false);
  end if;
  return pg_catalog.jsonb_build_object(
    'personalizedAdultEnergy',
      public.stk_service_can_use_nutrition_capability(
        v_uid,'personalizedAdultEnergy'),
    'informationalFoodEstimate',
      public.stk_service_can_use_nutrition_capability(
        v_uid,'informationalFoodEstimate'),
    'legalCurrent', exists(
      select 1 from stk_secure.stk_legal_receipts r
      join stk_secure.stk_legal_releases p on p.id = r.release_id
      where r.user_id = v_uid and r.revoked_at is null
        and p.is_current and p.published_at <= now()));
end;
$$;

-- Prevent default EXECUTE TO PUBLIC on definer functions.
revoke all on function public.stk_get_current_legal_release() from public, anon, authenticated;
grant execute on function public.stk_get_current_legal_release() to anon, authenticated;

revoke all on function public.stk_record_legal_acceptance(text,text,text,text,text)
  from public, anon, authenticated;
grant execute on function public.stk_record_legal_acceptance(text,text,text,text,text)
  to authenticated;
revoke all on function public.stk_revoke_legal_acceptance()
  from public, anon, authenticated;
grant execute on function public.stk_revoke_legal_acceptance() to authenticated;

revoke all on function public.stk_service_set_nutrition_capability(uuid,text,text,boolean,text,timestamptz)
  from public, anon, authenticated;
grant execute on function public.stk_service_set_nutrition_capability(uuid,text,text,boolean,text,timestamptz)
  to service_role;
revoke all on function public.stk_service_can_use_nutrition_capability(uuid,text)
  from public, anon, authenticated;
grant execute on function public.stk_service_can_use_nutrition_capability(uuid,text)
  to service_role;
revoke all on function public.stk_get_nutrition_capabilities()
  from public, anon, authenticated;
grant execute on function public.stk_get_nutrition_capabilities()
  to authenticated;
