-- Professional, read-only nutrition pages. Preserve existing non-clinical, versioned contracts.
create or replace function public.stk_list_coach_pro_nutrition(
  p_relationship_id uuid,p_limit integer default 25,p_offset integer default 0
) returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  v_coach uuid:=auth.uid(); v_client uuid; v_items jsonb; v_total bigint;
  v_limit integer:=coalesce(p_limit,25); v_offset integer:=coalesce(p_offset,0);
begin
  if v_coach is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities where user_id=v_coach and capability='coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  select r.client_user_id into v_client from public.stk_coach_client_relationships r
  where r.id=p_relationship_id and r.coach_user_id=v_coach and r.status='active'
    and coalesce((r.permissions->>'view_nutrition')::boolean,false);
  if not found then raise exception 'Nutrition access unavailable'; end if;
  if v_limit<1 or v_limit>100 then raise exception 'Coach Pro page limit must be between 1 and 100'; end if;
  if v_offset<0 or v_offset>10000 then raise exception 'Coach Pro page offset is invalid'; end if;
  with permitted as (
    select p.id,p.relationship_id,p.coach_user_id,p.client_user_id,p.status,p.current_version,
      v.title,p.updated_at
    from public.stk_nutrition_guidance_plans p
    join public.stk_nutrition_guidance_versions v on v.plan_id=p.id and v.version=p.current_version
    where p.relationship_id=p_relationship_id and p.coach_user_id=v_coach
      and p.client_user_id=v_client and v.created_by=v_coach
  ), page as (
    select * from permitted order by updated_at desc,id limit v_limit offset v_offset
  )
  select coalesce((select jsonb_agg(to_jsonb(p) order by p.updated_at desc,p.id) from page p),'[]'::jsonb),
    (select count(*) from permitted) into v_items,v_total;
  return jsonb_build_object('relationship_id',p_relationship_id,'client_user_id',v_client,
    'items',v_items,'total_count',v_total);
end;
$$;
revoke all on function public.stk_list_coach_pro_nutrition(uuid,integer,integer) from public,anon;
grant execute on function public.stk_list_coach_pro_nutrition(uuid,integer,integer) to authenticated;

create or replace function public.stk_get_coach_pro_nutrition_page(
  p_relationship_id uuid,p_plan_id uuid,p_version integer,p_offset integer default 0
) returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  v_coach uuid:=auth.uid(); v_plan public.stk_nutrition_guidance_plans%rowtype;
  v_version public.stk_nutrition_guidance_versions%rowtype;
  v_meals jsonb; v_total bigint; v_offset integer:=coalesce(p_offset,0);
begin
  if v_coach is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise exception 'Permanent authenticated account required';
  end if;
  if not exists (select 1 from public.stk_user_capabilities where user_id=v_coach and capability='coach') then
    raise exception 'Coach capability required';
  end if;
  perform public.stk_assert_coach_pro_access(v_coach);
  select p.* into v_plan from public.stk_nutrition_guidance_plans p
  join public.stk_coach_client_relationships r on r.id=p.relationship_id
  where p.id=p_plan_id and r.id=p_relationship_id
    and p.coach_user_id=v_coach and r.coach_user_id=v_coach and p.client_user_id=r.client_user_id
    and r.status='active' and coalesce((r.permissions->>'view_nutrition')::boolean,false);
  if not found then raise exception 'Nutrition access unavailable'; end if;
  if p_version is null or p_version<1 or p_version>10000 then raise exception 'Nutrition version is invalid'; end if;
  if v_offset<0 or v_offset>10000 then raise exception 'Coach Pro page offset is invalid'; end if;
  select * into v_version from public.stk_nutrition_guidance_versions
  where plan_id=v_plan.id and version=p_version and created_by=v_coach;
  if not found then raise exception 'Nutrition version unavailable'; end if;
  with page as (
    select * from public.stk_nutrition_guidance_meals where version_id=v_version.id
    order by position,id limit 5 offset v_offset
  ), items as (
    select i.meal_id,jsonb_agg(jsonb_build_object('id',i.id,'position',i.position,
      'food_example',i.food_example,'serving_note',i.serving_note) order by i.position,i.id) as payload
    from public.stk_nutrition_guidance_items i join page p on p.id=i.meal_id group by i.meal_id
  )
  select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'position',p.position,'name',p.name,
    'timing_label',p.timing_label,'notes',p.notes,'items',coalesce(i.payload,'[]'::jsonb))
    order by p.position,p.id),'[]'::jsonb) into v_meals from page p left join items i on i.meal_id=p.id;
  select count(*) into v_total from public.stk_nutrition_guidance_meals where version_id=v_version.id;
  return jsonb_build_object('plan',jsonb_build_object('id',v_plan.id,'relationship_id',v_plan.relationship_id,
    'coach_user_id',v_plan.coach_user_id,'client_user_id',v_plan.client_user_id,'status',v_plan.status,
    'current_version',v_plan.current_version,'version',v_version.version,'title',v_version.title,
    'overview',v_version.overview,'hydration_notes',v_version.hydration_notes,'general_notes',v_version.general_notes,
    'scope_notice',v_version.scope_notice,'created_at',v_version.created_at,'meals',v_meals),'total_count',v_total);
end;
$$;
revoke all on function public.stk_get_coach_pro_nutrition_page(uuid,uuid,integer,integer) from public,anon;
grant execute on function public.stk_get_coach_pro_nutrition_page(uuid,uuid,integer,integer) to authenticated;
-- At most 5 meals x 50 existing items; no client-by-client or meal-by-meal network calls.
