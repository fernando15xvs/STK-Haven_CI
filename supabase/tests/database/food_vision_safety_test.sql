begin;
select plan(17);

select has_table('public','stk_nutrition_adult_verifications','adult verification table exists');
select has_table('public','stk_food_vision_rate_limits','Food Vision quota table exists');
select has_table('public','stk_food_vision_daily_metrics','Food Vision metric table exists');

select ok((select relrowsecurity from pg_class where oid='public.stk_nutrition_adult_verifications'::regclass),'adult verification uses RLS');
select ok((select relrowsecurity from pg_class where oid='public.stk_food_vision_rate_limits'::regclass),'quota table uses RLS');
select ok((select relrowsecurity from pg_class where oid='public.stk_food_vision_daily_metrics'::regclass),'metrics table uses RLS');

select ok(
  not has_function_privilege('authenticated','public.stk_set_adult_nutrition_verification(uuid,boolean,text)','EXECUTE'),
  'authenticated cannot grant adult nutrition access'
);
select ok(
  not has_function_privilege('authenticated','public.consume_stk_food_vision_quota(uuid)','EXECUTE'),
  'authenticated cannot consume quota RPC directly'
);
select ok(
  not has_function_privilege('authenticated','public.record_stk_food_vision_metric(boolean,text,boolean)','EXECUTE'),
  'authenticated cannot write Food Vision metrics'
);

insert into auth.users(
  id,aud,role,email,encrypted_password,email_confirmed_at,
  created_at,updated_at,raw_app_meta_data,raw_user_meta_data
) values (
  'b4000000-0000-0000-0000-000000000001',
  'authenticated','authenticated','nutrition-access@example.com','',
  now(),now(),now(),'{}'::jsonb,'{}'::jsonb
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b4000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);
select is(
  public.stk_has_adult_nutrition_access(),
  false,
  'adult numeric nutrition is fail-closed by default'
);

reset role;
set local role service_role;
select lives_ok(
  $$select public.stk_set_adult_nutrition_verification(
    'b4000000-0000-0000-0000-000000000001',true,'ci_verified'
  )$$,
  'service role can record trusted adult verification'
);
select ok(
  (public.consume_stk_food_vision_quota(
    'b4000000-0000-0000-0000-000000000001'
  )->>'allowed')::boolean,
  'service-side quota permits first valid request'
);
select lives_ok(
  $$select public.record_stk_food_vision_metric(false,'medium',true)$$,
  'service role can record privacy-safe aggregate metric'
);
select ok(
  not exists(
    select 1 from information_schema.columns
     where table_schema='public'
       and table_name='stk_food_vision_daily_metrics'
       and column_name in ('user_id','image','image_bytes','dish_name','prompt','response')
  ),
  'aggregate metrics store no user, image, dish, prompt or response content'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b4000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);
select is(
  public.stk_has_adult_nutrition_access(),
  true,
  'verified user can read only the resulting access boolean'
);

reset role;
set local role service_role;
select lives_ok(
  $$select public.stk_set_adult_nutrition_verification(
    'b4000000-0000-0000-0000-000000000001',false,'ci_revoked'
  )$$,
  'service role can revoke verification'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b4000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);
select is(
  public.stk_has_adult_nutrition_access(),
  false,
  'revocation immediately disables adult numeric nutrition'
);

select * from finish();
rollback;
