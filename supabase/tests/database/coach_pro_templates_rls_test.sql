begin;
select plan(24);
select has_table('public','stk_coach_pro_templates','private template store exists');
select has_function('public','stk_save_coach_pro_template_from_revision',array['uuid','uuid','uuid','text'],'save RPC exists');
select has_function('public','stk_list_coach_pro_templates',array['integer','integer'],'paged list RPC exists');
select has_function('public','stk_assign_coach_pro_template',array['uuid','uuid','date'],'clone RPC exists');
select has_function('public','stk_archive_coach_pro_template',array['uuid'],'archive RPC exists');
select ok(not has_table_privilege('authenticated','public.stk_coach_pro_templates','SELECT'),'no direct table reading');
select ok(not has_function_privilege('anon','public.stk_list_coach_pro_templates(integer,integer)','EXECUTE'),'anonymous cannot invoke library');

insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values
('a1000000-0000-0000-0000-000000000001','authenticated','authenticated','template-coach-a@example.com','',now(),now(),now(),'{}','{}'),
('a1000000-0000-0000-0000-000000000002','authenticated','authenticated','template-coach-b@example.com','',now(),now(),now(),'{}','{}'),
('a2000000-0000-0000-0000-000000000001','authenticated','authenticated','template-client-a@example.com','',now(),now(),now(),'{}','{}'),
('a2000000-0000-0000-0000-000000000002','authenticated','authenticated','template-client-b@example.com','',now(),now(),now(),'{}','{}');

insert into public.stk_user_capabilities(user_id,capability) values
('a1000000-0000-0000-0000-000000000001','coach'),
('a1000000-0000-0000-0000-000000000002','coach'),
('a2000000-0000-0000-0000-000000000001','athlete'),
('a2000000-0000-0000-0000-000000000002','athlete');

insert into public.stk_subscription_entitlements(user_id,product,status,tier,client_limit,starts_at,current_period_end,source)
values
('a1000000-0000-0000-0000-000000000001','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap'),
('a1000000-0000-0000-0000-000000000002','coach_pro','active','test',10,now()-interval '1 day',now()+interval '30 days','pgTap');

insert into public.stk_coach_client_relationships(id,coach_user_id,client_user_id,status,permissions)
values
('a3000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','active','{"assign_programs":true}'::jsonb),
('a3000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000002','active','{}'::jsonb);

create temporary table _template_phase3_test(assignment_id uuid, revision_id uuid, template_id uuid, copied_id uuid);
grant select,insert,update on _template_phase3_test to authenticated;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is((public.stk_list_coach_pro_templates(25,0)->>'total_count')::int,0,'empty library');

insert into _template_phase3_test(assignment_id)
select public.stk_assign_program('a2000000-0000-0000-0000-000000000001',
jsonb_build_object(
 'name','Client A Program','notes','Private client notes',
 'duration_weeks',8,'training_weekdays',jsonb_build_array(1,3,5),
 'starts_on','2026-09-01',
 'routines',jsonb_build_array(jsonb_build_object(
   'name','Upper A','notes','Private routine notes','exercises',
   jsonb_build_array(jsonb_build_object(
     'name','Press','muscle_group','Chest','equipment','Dumbbell',
     'target_sets',3,'target_reps_min',8,'target_reps_max',12,'rest_seconds',120,
     'warmup_sets',1,'approach_sets',1,'warmup_rest_seconds',45,
     'approach_rest_seconds',70,'unilateral',true,'unilateral_target','arm',
     'preparation_unilateral',false,'unilateral_side_rest_seconds',20,
     'preferred_unilateral_start_side','left'
   ))
 ))));

reset role;
update _template_phase3_test t set revision_id=(
 select id from public.stk_assigned_program_revisions r
 where r.assignment_id = t.assignment_id and r.revision_number = 1);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
update _template_phase3_test set template_id = public.stk_save_coach_pro_template_from_revision(
 'a3000000-0000-0000-0000-000000000001',assignment_id,revision_id,'Plantilla Fuerza');
select ok((select template_id is not null from _template_phase3_test),'saves from permitted revision');
select is((public.stk_list_coach_pro_templates(25,0)->>'total_count')::int,1,'owner list returns count');
select is((public.stk_list_coach_pro_templates(25,0)->'items'->0->>'title'),'Plantilla Fuerza','list returns public metadata');
select is(pg_catalog.jsonb_array_length(public.stk_list_coach_pro_templates(25,100)->'items'),0,'offset beyond end is empty');

reset role;
select is((select program->>'notes' from public.stk_coach_pro_templates where id=(select template_id from _template_phase3_test)),'','client notes discarded');
select is((select program->'routines'->0->>'notes' from public.stk_coach_pro_templates where id=(select template_id from _template_phase3_test)),'','routine notes discarded');
select is((select program->'routines'->0->'exercises'->0->>'preparation_unilateral' from public.stk_coach_pro_templates where id=(select template_id from _template_phase3_test)),'false','unilateral preparation preserved');
select is((select program->'routines'->0->'exercises'->0->>'warmup_rest_seconds' from public.stk_coach_pro_templates where id=(select template_id from _template_phase3_test)),'45','warmup rest preserved');
select ok((select not (program ? 'starts_on') from public.stk_coach_pro_templates where id=(select template_id from _template_phase3_test)),'old client start date omitted');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
update _template_phase3_test set copied_id = public.stk_assign_coach_pro_template(
 template_id,'a3000000-0000-0000-0000-000000000001','2026-11-02'::date);
select ok((select copied_id <> assignment_id from _template_phase3_test),'clone has distinct assignment ID');
reset role;
select is((select starts_on::text from public.stk_assigned_programs where id=(select copied_id from _template_phase3_test)),'2026-11-02','clone uses supplied start date');
select is((select notes from public.stk_assigned_programs where id=(select copied_id from _template_phase3_test)),'','clone has no personal notes');
select is((select count(*)::integer from public.stk_assigned_programs where client_user_id='a2000000-0000-0000-0000-000000000001'),2,'clone does not mutate original assignment');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',true);
select is((public.stk_list_coach_pro_templates(25,0)->>'total_count')::int,0,'other coach cannot enumerate templates');
select throws_ok(
 $$ select public.stk_assign_coach_pro_template((select template_id from _template_phase3_test),'a3000000-0000-0000-0000-000000000001',current_date) $$,
 'P0001','Template unavailable','cross-coach template access denied');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok(
 $$ select public.stk_assign_coach_pro_template((select template_id from _template_phase3_test),'a3000000-0000-0000-0000-000000000002',current_date) $$,
 'P0001','Active program assignment permission required','no client consent means no clone');
select ok(public.stk_archive_coach_pro_template((select template_id from _template_phase3_test)),'coach can archive own template');
select is((public.stk_list_coach_pro_templates(25,0)->>'total_count')::int,0,'archived template no longer listed');
select throws_ok(
 $$ select public.stk_assign_coach_pro_template((select template_id from _template_phase3_test),'a3000000-0000-0000-0000-000000000001',current_date) $$,
 'P0001','Template unavailable','archived template cannot be cloned');
reset role;
update public.stk_subscription_entitlements set status='expired'
where user_id='a1000000-0000-0000-0000-000000000001' and product='coach_pro';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',true);
select throws_ok(
 $$ select public.stk_list_coach_pro_templates(25,0) $$,
 'P0001','Coach Pro entitlement required','expired entitlement cannot access template library');
select * from finish();
rollback;
