-- Roadmap 3.0 / Coach 2.0 check-ins.
-- Shared only through an active relationship with view_checkins consent.
create table if not exists public.stk_coach_checkins (
  id uuid primary key default gen_random_uuid(),
  relationship_id uuid not null references public.stk_coach_client_relationships(id) on delete cascade,
  coach_user_id uuid not null references auth.users(id) on delete cascade,
  client_user_id uuid not null references auth.users(id) on delete cascade,
  energy smallint not null check (energy between 1 and 5),
  recovery smallint not null check (recovery between 1 and 5),
  note text not null default '' check (char_length(note) <= 2000),
  created_at timestamptz not null default now()
);
create table if not exists public.stk_coach_checkin_comments (
  id uuid primary key default gen_random_uuid(),
  checkin_id uuid not null references public.stk_coach_checkins(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists stk_coach_checkins_client_idx on public.stk_coach_checkins(client_user_id, created_at desc);
create index if not exists stk_coach_checkin_comments_idx on public.stk_coach_checkin_comments(checkin_id, created_at);

alter table public.stk_coach_checkins enable row level security;
alter table public.stk_coach_checkin_comments enable row level security;
revoke all on public.stk_coach_checkins from anon, authenticated;
revoke all on public.stk_coach_checkin_comments from anon, authenticated;
grant select on public.stk_coach_checkins to authenticated;
grant select on public.stk_coach_checkin_comments to authenticated;

create policy "checkins visible to owner and permitted coach"
on public.stk_coach_checkins for select to authenticated using (
  coalesce((auth.jwt()->>'is_anonymous')::boolean,false)=false
  and (auth.uid()=client_user_id or (auth.uid()=coach_user_id and public.stk_coach_can_access(client_user_id,'view_checkins')))
);
create policy "checkin comments visible through checkin"
on public.stk_coach_checkin_comments for select to authenticated using (
  exists(select 1 from public.stk_coach_checkins c where c.id=checkin_id and
    (auth.uid()=c.client_user_id or (auth.uid()=c.coach_user_id and public.stk_coach_can_access(c.client_user_id,'view_checkins')))
  )
);

create or replace function public.stk_create_coach_checkin(
  p_relationship_id uuid, p_energy integer, p_recovery integer, p_note text default ''
) returns uuid language plpgsql security definer set search_path='' as $$
declare r public.stk_coach_client_relationships%rowtype; v_id uuid;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Permanent authenticated account required'; end if;
  select * into r from public.stk_coach_client_relationships where id=p_relationship_id and client_user_id=auth.uid() and status='active';
  if not found or not coalesce((r.permissions->>'view_checkins')::boolean,false) then raise exception 'Check-in permission required'; end if;
  if p_energy not between 1 and 5 or p_recovery not between 1 and 5 then raise exception 'Check-in score out of range'; end if;
  insert into public.stk_coach_checkins(relationship_id,coach_user_id,client_user_id,energy,recovery,note)
  values(r.id,r.coach_user_id,r.client_user_id,p_energy,p_recovery,left(coalesce(p_note,''),2000)) returning id into v_id;
  return v_id;
end $$;

create or replace function public.stk_list_coach_checkins(p_client_user_id uuid)
returns table(id uuid,relationship_id uuid,coach_user_id uuid,client_user_id uuid,energy smallint,recovery smallint,note text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Permanent authenticated account required'; end if;
  if auth.uid()<>p_client_user_id and not public.stk_coach_can_access(p_client_user_id,'view_checkins') then raise exception 'Check-in permission required'; end if;
  return query select c.id,c.relationship_id,c.coach_user_id,c.client_user_id,c.energy,c.recovery,c.note,c.created_at
  from public.stk_coach_checkins c where c.client_user_id=p_client_user_id order by c.created_at desc limit 100;
end $$;

create or replace function public.stk_add_coach_checkin_comment(p_checkin_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.stk_coach_checkins%rowtype; v_id uuid;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Permanent authenticated account required'; end if;
  select * into c from public.stk_coach_checkins where id=p_checkin_id;
  if not found then raise exception 'Check-in not found'; end if;
  if auth.uid()<>c.client_user_id and (auth.uid()<>c.coach_user_id or not public.stk_coach_can_access(c.client_user_id,'comment')) then raise exception 'Comment permission required'; end if;
  if char_length(btrim(coalesce(p_body,''))) not between 1 and 2000 then raise exception 'Comment length invalid'; end if;
  insert into public.stk_coach_checkin_comments(checkin_id,author_user_id,body) values(c.id,auth.uid(),btrim(p_body)) returning id into v_id;
  return v_id;
end $$;

create or replace function public.stk_list_coach_checkin_comments(p_checkin_id uuid)
returns table(id uuid,checkin_id uuid,author_user_id uuid,body text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare c public.stk_coach_checkins%rowtype;
begin
  select * into c from public.stk_coach_checkins where id=p_checkin_id;
  if not found then raise exception 'Check-in not found'; end if;
  if auth.uid()<>c.client_user_id and (auth.uid()<>c.coach_user_id or not public.stk_coach_can_access(c.client_user_id,'view_checkins')) then raise exception 'Check-in permission required'; end if;
  return query select x.id,x.checkin_id,x.author_user_id,x.body,x.created_at from public.stk_coach_checkin_comments x where x.checkin_id=p_checkin_id order by x.created_at;
end $$;

revoke all on function public.stk_create_coach_checkin(uuid,integer,integer,text) from public,anon;
revoke all on function public.stk_list_coach_checkins(uuid) from public,anon;
revoke all on function public.stk_add_coach_checkin_comment(uuid,text) from public,anon;
revoke all on function public.stk_list_coach_checkin_comments(uuid) from public,anon;
grant execute on function public.stk_create_coach_checkin(uuid,integer,integer,text) to authenticated;
grant execute on function public.stk_list_coach_checkins(uuid) to authenticated;
grant execute on function public.stk_add_coach_checkin_comment(uuid,text) to authenticated;
grant execute on function public.stk_list_coach_checkin_comments(uuid) to authenticated;
