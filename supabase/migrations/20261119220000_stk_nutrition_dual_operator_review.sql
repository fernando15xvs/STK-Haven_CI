-- STK Haven: no-provider, supervised nutrition authorizations.
-- SOURCE ONLY. DO NOT DEPLOY without approved policies, operator roster,
-- 15+/18+ review protocol, rollback plan and explicit owner authorization.
-- Both operators must be enrolled in Supabase Auth MFA (aal2). No roster seed.
-- No identity documents, photographs or raw evidence stored in this schema.
-- An editable DOB/terms checkbox is NEVER a privileged grant.

create table stk_secure.stk_nutrition_review_operators (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled_at timestamptz not null default now(),
  revoked_at timestamptz,
  approval_reference text not null check (length(btrim(approval_reference)) between 12 and 300)
);

create table stk_secure.stk_nutrition_review_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  capability text not null check (capability in
    ('personalizedAdultEnergy','informationalFoodEstimate')),
  reviewed_age_band text not null check (reviewed_age_band in ('15_17','18_plus')),
  release_id uuid not null references stk_secure.stk_legal_releases(id),
  receipt_accepted_at timestamptz not null,
  expires_at timestamptz not null,
  review_reference text not null check (length(btrim(review_reference)) between 12 and 300),
  requested_by uuid not null references auth.users(id),
  requested_at timestamptz not null default now(),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  consumed_at timestamptz,
  status text not null default 'pending'
    check (status in ('pending','approved','cancelled')),
  constraint stk_review_distinct_operators check (
    approved_by is null or approved_by <> requested_by),
  constraint stk_review_no_self_requested check (requested_by <> user_id),
  constraint stk_review_no_self_approved check (
    approved_by is null or approved_by <> user_id)
);

create index stk_pending_nutrition_review_requests
  on stk_secure.stk_nutrition_review_requests(user_id,capability,requested_at desc)
  where status = 'pending';

create table stk_secure.stk_nutrition_operator_audit (
  id bigint generated always as identity primary key,
  operator_user_id uuid not null references auth.users(id) on delete cascade,
  subject_user_id uuid not null references auth.users(id) on delete cascade,
  capability text not null,
  review_id uuid,
  event text not null check(event in ('requested','approved','revoked')),
  reason text not null,
  recorded_at timestamptz not null default now()
);

alter table stk_secure.stk_nutrition_review_operators enable row level security;
alter table stk_secure.stk_nutrition_review_requests enable row level security;
alter table stk_secure.stk_nutrition_operator_audit enable row level security;

revoke all on stk_secure.stk_nutrition_review_operators from public, anon, authenticated;
revoke all on stk_secure.stk_nutrition_review_requests from public, anon, authenticated;
revoke all on stk_secure.stk_nutrition_operator_audit from public, anon, authenticated;
grant select, insert, update, delete on
  stk_secure.stk_nutrition_review_operators,
  stk_secure.stk_nutrition_review_requests,
  stk_secure.stk_nutrition_operator_audit to service_role;
grant usage, select on sequence stk_secure.stk_nutrition_operator_audit_id_seq
  to service_role;

-- Security-definer helper is in an unexposed schema, never public.
-- Only public, specifically authorized RPCs may invoke it.
create or replace function stk_secure.stk_operator_is_current(p_uid uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select p_uid is not null
    and exists(
      select 1 from stk_secure.stk_nutrition_review_operators o
      where o.user_id = p_uid and o.revoked_at is null
    )
    and coalesce((auth.jwt()->>'is_anonymous')::boolean,false) = false
    and auth.jwt()->>'aal' = 'aal2'
    and auth.uid() = p_uid
    -- A signed JWT may survive sign-out briefly; check its live session.
    and exists(select 1 from auth.sessions s
      where s.user_id = p_uid
        and s.id::text = auth.jwt()->>'session_id'
        and (s.not_after is null or s.not_after > now()));
$$;
revoke all on function stk_secure.stk_operator_is_current(uuid)
  from public, anon, authenticated;
-- Function calls from other SECURITY DEFINER routines run with owner rights.

-- A reviewer proposes a *case reference*, not a claim of legal age. The
-- independent human review protocol is a deployment prerequisite.
create or replace function public.stk_operator_request_nutrition_review(
  p_user_id uuid, p_capability text, p_reviewed_age_band text,
  p_review_reference text, p_expires_at timestamptz
)
returns uuid
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_release stk_secure.stk_legal_releases%rowtype;
  v_band text;
  v_receipt_accepted_at timestamptz;
  v_id uuid;
begin
  if not stk_secure.stk_operator_is_current(v_actor) then
    raise exception 'Authorized MFA reviewer required';
  end if;
  if p_user_id is null or p_user_id = v_actor or
    p_capability not in ('personalizedAdultEnergy','informationalFoodEstimate') or
    p_reviewed_age_band not in ('15_17','18_plus') or
    length(btrim(coalesce(p_review_reference,''))) not between 12 and 300 or
    p_expires_at is null or p_expires_at <= now() or
    p_expires_at > now() + interval '180 days' then
    raise exception 'Invalid proposed nutrition review';
  end if;
  if p_capability = 'personalizedAdultEnergy'
     and p_reviewed_age_band <> '18_plus' then
    raise exception 'Adult energy requires trusted adult review';
  end if;
  select * into v_release from stk_secure.stk_legal_releases
    where is_current and published_at <= now() limit 1;
  if not found then raise exception 'No published legal release'; end if;
  if p_capability = 'informationalFoodEstimate'
    and not v_release.informational_estimates_clinically_approved then
    raise exception 'Clinical approval is not enabled';
  end if;
  select r.declared_age_band, r.accepted_at
    into v_band, v_receipt_accepted_at
    from stk_secure.stk_legal_receipts r
    where r.user_id = p_user_id and r.release_id = v_release.id
      and r.revoked_at is null;
  if not found or v_band <> p_reviewed_age_band then
    raise exception 'Current matching legal receipt required';
  end if;
  -- Avoid accumulating unbounded pending cases; stale ones are rejected at approval.
  if (select count(*) from stk_secure.stk_nutrition_review_requests
      where user_id = p_user_id and capability = p_capability
      and status = 'pending' and requested_at > now()-interval '1 day') >= 3 then
    raise exception 'Too many pending reviews';
  end if;
  insert into stk_secure.stk_nutrition_review_requests(
    user_id,capability,reviewed_age_band,release_id,receipt_accepted_at,
    expires_at,review_reference,requested_by
  ) values(
    p_user_id,p_capability,p_reviewed_age_band,v_release.id,v_receipt_accepted_at,
    p_expires_at,btrim(p_review_reference),v_actor
  ) returning id into v_id;
  insert into stk_secure.stk_nutrition_operator_audit(
    operator_user_id,subject_user_id,capability,review_id,event,reason
  ) values(v_actor,p_user_id,p_capability,v_id,'requested',p_review_reference);
  return v_id;
end;
$$;

-- The ONLY grant-writing workflow: a different enrolled MFA operator must
-- approve the current, unexpired case. All checks and the write are atomic.
create or replace function public.stk_operator_approve_nutrition_review(
  p_review_id uuid
)
returns boolean
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_review stk_secure.stk_nutrition_review_requests%rowtype;
  v_band text;
begin
  if not stk_secure.stk_operator_is_current(v_actor) then
    raise exception 'Authorized MFA reviewer required';
  end if;
  select * into v_review from stk_secure.stk_nutrition_review_requests
    where id = p_review_id for update;
  if not found or v_review.status <> 'pending' or
     v_review.approved_at is not null or
     v_review.requested_at < now()-interval '24 hours' or
     v_actor in (v_review.requested_by,v_review.user_id) or
     not exists(select 1 from stk_secure.stk_nutrition_review_operators
       where user_id = v_review.requested_by and revoked_at is null) then
    raise exception 'Independent current review required';
  end if;
  if not exists (
      select 1 from stk_secure.stk_legal_releases p
      where p.id = v_review.release_id and p.is_current and p.published_at <= now()
        and (v_review.capability <> 'informationalFoodEstimate'
          or p.informational_estimates_clinically_approved)
    ) or not exists (
      select 1 from stk_secure.stk_legal_receipts r
      where r.user_id = v_review.user_id and r.release_id = v_review.release_id
        and r.revoked_at is null
        and r.declared_age_band = v_review.reviewed_age_band
        and r.accepted_at = v_review.receipt_accepted_at
    ) or v_review.expires_at <= now() then
    raise exception 'Stale policy, consent or review';
  end if;
  if v_review.capability = 'personalizedAdultEnergy'
     and v_review.reviewed_age_band <> '18_plus' then
    raise exception 'Adult energy requires trusted adult review';
  end if;

  update stk_secure.stk_nutrition_review_requests
     set approved_by = v_actor, approved_at = now(),
         consumed_at = now(), status = 'approved'
    where id = p_review_id;
  insert into stk_secure.stk_nutrition_capability_grants (
    user_id,capability,release_id,reviewed_age_band,review_reference,expires_at
  ) values (
    v_review.user_id,v_review.capability,v_review.release_id,
    v_review.reviewed_age_band,p_review_id::text,v_review.expires_at
  )
  on conflict (user_id,capability) do update
    set release_id = excluded.release_id,
        reviewed_age_band = excluded.reviewed_age_band,
        review_reference = excluded.review_reference,
        expires_at = excluded.expires_at,
        granted_at = now(), revoked_at = null;
  insert into stk_secure.stk_nutrition_capability_audit (
    user_id,capability,decision,policy_release_id,review_reference
  ) values (v_review.user_id,v_review.capability,'grant',
    v_review.release_id,p_review_id::text);
  insert into stk_secure.stk_nutrition_operator_audit (
    operator_user_id,subject_user_id,capability,review_id,event,reason
  ) values (v_actor,v_review.user_id,v_review.capability,p_review_id,
    'approved','Independent MFA reviewer approved');
  return true;
end;
$$;

-- A single MFA operator may revoke immediately for safety. Revocation
-- never requires the affected user's consent or a second review.
create or replace function public.stk_operator_revoke_nutrition_capability(
  p_user_id uuid, p_capability text, p_reason text
)
returns boolean
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if not stk_secure.stk_operator_is_current(v_actor) then
    raise exception 'Authorized MFA reviewer required';
  end if;
  if p_user_id is null or p_user_id = v_actor or
     p_capability not in ('personalizedAdultEnergy','informationalFoodEstimate')
     or length(btrim(coalesce(p_reason,''))) not between 12 and 300 then
    raise exception 'Invalid revocation request';
  end if;
  update stk_secure.stk_nutrition_capability_grants
    set revoked_at = now()
    where user_id = p_user_id and capability = p_capability
      and revoked_at is null;
  update stk_secure.stk_nutrition_review_requests
    set status = 'cancelled'
    where user_id = p_user_id and capability = p_capability and status='pending';
  insert into stk_secure.stk_nutrition_capability_audit(
    user_id,capability,decision,review_reference
  ) values(p_user_id,p_capability,'revoke',p_reason);
  insert into stk_secure.stk_nutrition_operator_audit(
    operator_user_id,subject_user_id,capability,event,reason
  ) values(v_actor,p_user_id,p_capability,'revoked',p_reason);
  return true;
end;
$$;

-- Compatibility API: a bare service_role call may REVOKE an existing grant,
-- but cannot CREATE one without the independent two-operator workflow.
-- In particular: no unattended app, service key leak or caller-supplied
-- review_reference string may simulate approved adult eligibility.
create or replace function public.stk_service_set_nutrition_capability(
  p_user_id uuid, p_capability text, p_reviewed_age_band text,
  p_granted boolean, p_review_reference text, p_expires_at timestamptz
)
returns boolean
language plpgsql volatile security definer set search_path = ''
as $$
begin
  if p_granted is true then
    raise exception 'Use independent MFA nutrition review workflow';
  end if;
  if p_user_id is null or
     p_capability not in ('personalizedAdultEnergy','informationalFoodEstimate')
     or length(btrim(coalesce(p_review_reference,''))) not between 12 and 300 then
    raise exception 'Invalid revocation request';
  end if;
  update stk_secure.stk_nutrition_capability_grants
    set revoked_at = now()
    where user_id = p_user_id and capability = p_capability
      and revoked_at is null;
  update stk_secure.stk_nutrition_review_requests
    set status = 'cancelled'
    where user_id = p_user_id and capability = p_capability and status='pending';
  insert into stk_secure.stk_nutrition_capability_audit(
    user_id,capability,decision,review_reference
  ) values(p_user_id,p_capability,'revoke',p_review_reference);
  return true;
end;
$$;

revoke all on function public.stk_operator_request_nutrition_review(
  uuid,text,text,text,timestamptz) from public, anon, authenticated;
grant execute on function public.stk_operator_request_nutrition_review(
  uuid,text,text,text,timestamptz) to authenticated;
revoke all on function public.stk_operator_approve_nutrition_review(uuid)
  from public, anon, authenticated;
grant execute on function public.stk_operator_approve_nutrition_review(uuid)
  to authenticated;
revoke all on function public.stk_operator_revoke_nutrition_capability(
  uuid,text,text) from public, anon, authenticated;
grant execute on function public.stk_operator_revoke_nutrition_capability(
  uuid,text,text) to authenticated;
-- Explicitly preserve prior service-only emergency revoke boundary.
revoke all on function public.stk_service_set_nutrition_capability(
  uuid,text,text,boolean,text,timestamptz) from public, anon, authenticated;
grant execute on function public.stk_service_set_nutrition_capability(
  uuid,text,text,boolean,text,timestamptz) to service_role;
