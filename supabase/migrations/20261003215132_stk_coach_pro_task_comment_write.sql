-- Professional write boundary. Reuses the existing append-only comment RPC.
-- Lock the authorized task/relationship until the insert commits to serialize revocation.
create or replace function public.stk_add_coach_pro_task_comment(
  p_relationship_id uuid, p_task_id uuid,
  p_body text
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_coach uuid := auth.uid();
  v_task public.stk_coach_tasks%rowtype;
begin
  if v_coach is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities
    where user_id=v_coach and capability='coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  select t.* into v_task
    from public.stk_coach_tasks t
    join public.stk_coach_client_relationships r on r.id=t.relationship_id
    where t.id=p_task_id and r.id=p_relationship_id
      and t.coach_user_id=v_coach and r.coach_user_id=v_coach
      and t.client_user_id=r.client_user_id and r.status='active'
      and coalesce((r.permissions->>'comment')::boolean,false)
    for share of t,r;
  if not found then raise exception 'Task comments access unavailable'; end if;
  return public.stk_add_coach_task_comment(v_task.id,null,p_body);
end;
$$;
revoke all on function public.stk_add_coach_pro_task_comment(uuid,uuid,text) from public,anon;
grant execute on function public.stk_add_coach_pro_task_comment(uuid,uuid,text) to authenticated;
-- General task comments only; no occurrence date inferred and no changes to client-side rights.
