create table if not exists public.stk_haven_cloud_backups (
  user_id uuid primary key references auth.users(id) on delete cascade,
  backup_payload jsonb not null,
  schema_version integer not null,
  updated_at timestamptz not null default now()
);

alter table public.stk_haven_cloud_backups enable row level security;

grant select, insert, update on public.stk_haven_cloud_backups to authenticated;
revoke all on public.stk_haven_cloud_backups from anon;

create policy "Users can read their own STK Haven backup"
on public.stk_haven_cloud_backups
for select
to authenticated
using (
  auth.uid() = user_id
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

create policy "Users can insert their own STK Haven backup"
on public.stk_haven_cloud_backups
for insert
to authenticated
with check (
  auth.uid() = user_id
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

create policy "Users can update their own STK Haven backup"
on public.stk_haven_cloud_backups
for update
to authenticated
using (
  auth.uid() = user_id
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
)
with check (
  auth.uid() = user_id
  and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

comment on table public.stk_haven_cloud_backups is
  'Optional one-snapshot-per-user STK Haven backup used for manual cross-device sync.';
