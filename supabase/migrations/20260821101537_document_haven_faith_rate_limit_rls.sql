create policy "deny_client_access_to_haven_faith_rate_limits"
on public.haven_faith_rate_limits
for all
to anon, authenticated
using (false)
with check (false);
