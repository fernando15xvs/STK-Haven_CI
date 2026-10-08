begin;
select plan(18);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values
('71000000-0000-0000-0000-000000000001','authenticated','authenticated','portfolio-coach@example.com','',now(),now(),now(),'{}','{}'),
('71000000-0000-0000-0000-000000000002','authenticated','authenticated','portfolio-other-coach@example.com','',now(),now(),now(),'{}','{}'),
('72000000-0000-0000-0000-000000000001','authenticated','authenticated','portfolio-client-a@example.com','',now(),now(),now(),'{}','{}'),
('72000000-0000-0000-0000-000000000002','authenticated','authenticated','portfolio-client-b@example.com','',now(),now(),now(),'{}','{}');

insert into public.stk_user_capabilities(user_id, capability) values
('71000000-0000-0000-0000-000000000001','coach'),
('71000000-0000-0000-0000-000000000002','coach'),
('72000000-0000-0000-0000-000000000001','athlete'),
('72000000-0000-0000-0000-000000000002','athlete');

insert into public.stk_subscription_entitlements(
  user_id, product, status, tier, client_limit, starts_at,
  current_period_end, source
) values
('71000000-0000-0000-0000-000000000001','coach_pro','active','test',10,
 now()-interval '1 day',now()+interval '30 days','pgTap'),
('71000000-0000-0000-0000-000000000002','coach_pro','active','test',10,
 now()-interval '1 day',now()+interval '30 days','pgTap');

insert into public.stk_coach_client_relationships(
 id, coach_user_id, client_user_id, status, permissions
) values
('73000000-0000-0000-0000-000000000001',
 '71000000-0000-0000-0000-000000000001',
 '72000000-0000-0000-0000-000000000001','active',
 '{"view_progress":true,"view_checkins":true,"assign_tasks":true}'),
('73000000-0000-0000-0000-000000000002',
 '71000000-0000-0000-0000-000000000001',
 '72000000-0000-0000-0000-000000000002','active','{}');

insert into public.stk_client_progress_snapshots(
 client_user_id, workouts_7d, workouts_30d, training_minutes_7d,
 completed_working_sets_7d, volume_7d, average_rir_7d, last_workout_at, generated_at
) values
('72000000-0000-0000-0000-000000000001',0,1,0,0,0,null,now()-interval '8 days',now()),
('72000000-0000-0000-0000-000000000002',5,12,200,30,5000,2,now(),now());

insert into public.stk_coach_tasks(
 id, relationship_id, coach_user_id, client_user_id, title, category,
 task_type, target_minutes, recurrence_type, weekdays, starts_on,
 coach_instructions, status
) values
('74000000-0000-0000-0000-000000000001',
 '73000000-0000-0000-0000-000000000001',
 '71000000-0000-0000-0000-000000000001',
 '72000000-0000-0000-0000-000000000001',
 'Mobility A','Recovery','checklist',10,'once','{}',current_date,'','active'),
('74000000-0000-0000-0000-000000000002',
 '73000000-0000-0000-0000-000000000002',
 '71000000-0000-0000-0000-000000000001',
 '72000000-0000-0000-0000-000000000002',
 'Mobility B','Recovery','checklist',10,'once','{}',current_date,'','active');

insert into public.stk_coach_checkins(
 id, relationship_id, coach_user_id, client_user_id, energy, recovery, note, created_at
) values
('75000000-0000-0000-0000-000000000001',
 '73000000-0000-0000-0000-000000000001',
 '71000000-0000-0000-0000-000000000001',
 '72000000-0000-0000-0000-000000000001',4,4,'A',now()-interval '1 hour'),
('75000000-0000-0000-0000-000000000002',
 '73000000-0000-0000-0000-000000000002',
 '71000000-0000-0000-0000-000000000001',
 '72000000-0000-0000-0000-000000000002',4,4,'Private',now()-interval '1 hour');

set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}', true);

select is((public.stk_get_coach_pro_portfolio_overview()->>'total_clients')::int,
  2, 'all linked clients counted globally');
select is((public.stk_get_coach_pro_portfolio_overview()->>'active_clients')::int,
  2, 'active relationships counted');
select is((public.stk_get_coach_pro_portfolio_overview()->>'paused_clients')::int,
  0, 'zero paused count');
select is((public.stk_get_coach_pro_portfolio_overview()->>'clients_with_shared_progress')::int,
  1, 'private progress not included');
select is((public.stk_get_coach_pro_portfolio_overview()->>'clients_requiring_review')::int,
  1, 'review status requires granted progress');
select is((public.stk_get_coach_pro_portfolio_overview()->>'visible_active_tasks')::int,
  1, 'private tasks not aggregated');
select is((public.stk_get_coach_pro_portfolio_overview()->>'clients_with_task_backlog')::int,
  1, 'task backlog only with permission');
select is((public.stk_get_coach_pro_portfolio_overview()->>'clients_with_recent_checkins')::int,
  1, 'private check-ins not aggregated');

select set_config('request.jwt.claims',
 '{"sub":"71000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}', true);
select is((public.stk_get_coach_pro_portfolio_overview()->>'total_clients')::int,
  0, 'another coach sees only own relationships');
select set_config('request.jwt.claims',
 '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":true}', true);
select throws_ok(
  $$ select public.stk_get_coach_pro_portfolio_overview() $$,
  'P0001', 'Permanent authenticated account required',
  'anonymous cannot use portfolio RPC');
reset role;

update public.stk_coach_client_relationships
  set status = 'paused'
  where id = '73000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}', true);
select is((public.stk_get_coach_pro_portfolio_overview()->>'active_clients')::int,
  1, 'active count excludes paused');
select is((public.stk_get_coach_pro_portfolio_overview()->>'paused_clients')::int,
  1, 'paused relationship remains in roster metadata');
select is((public.stk_get_coach_pro_portfolio_overview()->>'clients_requiring_review')::int,
  0, 'paused relationship cannot leak review status');
select is((public.stk_get_coach_pro_portfolio_overview()->>'clients_with_shared_progress')::int,
  0, 'paused relationship cannot leak shared progress');
select is((public.stk_get_coach_pro_portfolio_overview()->>'visible_active_tasks')::int,
  0, 'paused relationship cannot leak active tasks');
select is((public.stk_get_coach_pro_portfolio_overview()->>'clients_with_recent_checkins')::int,
  0, 'paused relationship cannot leak check-ins');
reset role;

update public.stk_coach_client_relationships
 set status = 'revoked', revoked_at = now()
 where id = '73000000-0000-0000-0000-000000000001';
set local role authenticated;
select is((public.stk_get_coach_pro_portfolio_overview()->>'total_clients')::int,
  1, 'revoked relationship is omitted immediately');
reset role;

update public.stk_subscription_entitlements
 set status='expired'
 where user_id='71000000-0000-0000-0000-000000000001'
 and product='coach_pro';
set local role authenticated;
select throws_ok(
  $$select public.stk_get_coach_pro_portfolio_overview()$$,
  'P0001','Coach Pro entitlement required',
  'expired Coach Pro cannot read portfolio');

select * from finish();
rollback;
