-- Read-only version metadata, isolated to the selected coach-owned plan and relationship.
create or replace function public.stk_list_coach_pro_nutrition_versions(
  p_relationship_id uuid,p_plan_id uuid,p_limit integer default 25,p_offset integer default 0
) returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  v_coach uuid:=auth.uid(); v_plan public.stk_nutrition_guidance_plans%rowtype;
  v_limit integer:=coalesce(p_limit,25); v_offset integer:=coalesce(p_offset,0);
  v_items jsonb; v_total bigint;
begin
  if v_coach is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists(select 1 from public.stk_user_capabilities where user_id=v_coach and capability='coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  select p.* into v_plan from public.stk_nutrition_guidance_plans p
    join public.stk_coach_client_relationships r on r.id=p.relationship_id
    where p.id=p_plan_id and r.id=p_relationship_id and r.coach_user_id=v_coach
      and p.coach_user_id=v_coach and p.client_user_id=r.client_user_id
      and r.status='active' and coalesce((r.permissions->>'view_nutrition')::boolean,false);
  if not found then raise exception 'Nutrition access unavailable'; end if;
  if v_limit<1 or v_limit>100 then raise exception 'Coach Pro page limit must be between 1 and 100'; end if;
  if v_offset<0 or v_offset>10000 then raise exception 'Coach Pro page offset is invalid'; end if;
  with permitted as (
    select v.version,v.title,v.created_at from public.stk_nutrition_guidance_versions v
      where v.plan_id=v_plan.id and v.created_by=v_coach and v.version<=v_plan.current_version
  ), page as (
    select * from permitted order by version desc limit v_limit offset v_offset
  )
  select coalesce((select jsonb_agg(to_jsonb(p) order by p.version desc) from page p),'[]'::jsonb),
    (select count(*) from permitted) into v_items,v_total;
  return jsonb_build_object('relationship_id',v_plan.relationship_id,'plan_id',v_plan.id,
    'client_user_id',v_plan.client_user_id,'current_version',v_plan.current_version,
    'items',v_items,'total_count',v_total);
end;
$$;
revoke all on function public.stk_list_coach_pro_nutrition_versions(uuid,uuid,integer,integer) from public,anon;
grant execute on function public.stk_list_coach_pro_nutrition_versions(uuid,uuid,integer,integer) to authenticated;
-- Reuses the plan/version index. No notes, meals, examples or writes are part of this endpoint.
