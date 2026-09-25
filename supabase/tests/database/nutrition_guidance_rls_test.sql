begin;

select plan(30);

select has_table('public', 'stk_nutrition_guidance_plans', 'nutrition plans table exists');
select has_table('public', 'stk_nutrition_guidance_versions', 'nutrition versions table exists');
select has_table('public', 'stk_nutrition_guidance_meals', 'nutrition meals table exists');
select has_table('public', 'stk_nutrition_guidance_items', 'nutrition items table exists');

select ok(
  (select relrowsecurity from pg_class where oid = 'public.stk_nutrition_guidance_plans'::regclass),
  'RLS is enabled on nutrition plans'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.stk_nutrition_guidance_versions'::regclass),
  'RLS is enabled on nutrition versions'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.stk_nutrition_guidance_meals'::regclass),
  'RLS is enabled on nutrition meals'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.stk_nutrition_guidance_items'::regclass),
  'RLS is enabled on nutrition items'
);

select ok(
  not exists(
    select 1 from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'stk_nutrition_guidance_plans'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ),
  'authenticated cannot mutate nutrition plans directly'
);
select ok(
  not exists(
    select 1 from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'stk_nutrition_guidance_versions'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ),
  'authenticated cannot mutate immutable nutrition versions directly'
);
select ok(
  not exists(
    select 1 from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'stk_nutrition_guidance_meals'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ),
  'authenticated cannot mutate nutrition meals directly'
);
select ok(
  not exists(
    select 1 from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'stk_nutrition_guidance_items'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ),
  'authenticated cannot mutate nutrition items directly'
);

select ok(
  public.stk_valid_coach_permissions('{"view_nutrition":true}'::jsonb),
  'view_nutrition is an explicit supported permission'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
)
values
(
  'a3000000-0000-0000-0000-000000000001',
  'authenticated', 'authenticated', 'nutrition-coach@example.com', '',
  now(), now(), now(), '{}'::jsonb, '{}'::jsonb
),
(
  'b3000000-0000-0000-0000-000000000001',
  'authenticated', 'authenticated', 'nutrition-client@example.com', '',
  now(), now(), now(), '{}'::jsonb, '{}'::jsonb
),
(
  'a3000000-0000-0000-0000-000000000002',
  'authenticated', 'authenticated', 'nutrition-stranger@example.com', '',
  now(), now(), now(), '{}'::jsonb, '{}'::jsonb
);

insert into public.stk_user_profiles (user_id, display_name)
values
  ('a3000000-0000-0000-0000-000000000001', 'Nutrition Coach'),
  ('b3000000-0000-0000-0000-000000000001', 'Nutrition Client'),
  ('a3000000-0000-0000-0000-000000000002', 'Nutrition Stranger');

insert into public.stk_user_capabilities (user_id, capability)
values
  ('a3000000-0000-0000-0000-000000000001', 'coach'),
  ('b3000000-0000-0000-0000-000000000001', 'athlete'),
  ('a3000000-0000-0000-0000-000000000002', 'coach');

insert into public.stk_coach_client_relationships (
  id, coach_user_id, client_user_id, status, permissions
)
values (
  'c3000000-0000-0000-0000-000000000001',
  'a3000000-0000-0000-0000-000000000001',
  'b3000000-0000-0000-0000-000000000001',
  'active',
  '{"view_nutrition":true}'::jsonb
);

create temporary table _nutrition_test (plan_id uuid);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a3000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $$insert into _nutrition_test(plan_id)
    select public.stk_save_nutrition_guidance(
      'b3000000-0000-0000-0000-000000000001',
      null,
      jsonb_build_object(
        'title', 'Guía base',
        'overview', 'Organización general de comidas.',
        'hydration_notes', 'Hidratación según sed y contexto.',
        'general_notes', 'Ejemplos flexibles.',
        'scope_notice', 'Orientación alimentaria general que no sustituye atención profesional.',
        'meals', jsonb_build_array(
          jsonb_build_object(
            'name', 'Desayuno',
            'timing_label', 'Mañana',
            'notes', '',
            'items', jsonb_build_array(
              jsonb_build_object(
                'food_example', 'Avena con fruta',
                'serving_note', 'Ejemplo flexible'
              )
            )
          )
        )
      )
    )$$,
  'authorized coach can create nutrition guidance'
);

select is(
  (select count(*)::integer from public.stk_nutrition_guidance_plans),
  1,
  'authorized coach can read created nutrition plan'
);

select is(
  (
    select current_version
    from public.stk_nutrition_guidance_plans
    where id = (select plan_id from _nutrition_test limit 1)
  ),
  1,
  'new nutrition plan starts at version 1'
);

select is(
  (
    public.stk_get_nutrition_guidance(
      (select plan_id from _nutrition_test limit 1),
      1
    ) ->> 'title'
  ),
  'Guía base',
  'coach can read immutable version 1'
);

select ok(
  not exists(
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name like 'stk_nutrition_guidance_%'
      and (
        column_name ilike '%calorie%'
        or column_name ilike '%macro%'
        or column_name ilike '%weight_target%'
        or column_name ilike '%deficit%'
      )
  ),
  'coach guidance schema contains no calorie, macro, weight-target or deficit fields'
);

select lives_ok(
  $$select public.stk_save_nutrition_guidance(
      'b3000000-0000-0000-0000-000000000001',
      (select plan_id from _nutrition_test limit 1),
      jsonb_build_object(
        'title', 'Guía actualizada',
        'overview', 'Segunda versión.',
        'hydration_notes', '',
        'general_notes', 'No modifica la versión anterior.',
        'scope_notice', 'Orientación alimentaria general que no sustituye atención profesional.',
        'meals', '[]'::jsonb
      )
    )$$,
  'authorized coach can create a new immutable version'
);

select is(
  (
    select current_version
    from public.stk_nutrition_guidance_plans
    where id = (select plan_id from _nutrition_test limit 1)
  ),
  2,
  'saving an existing plan advances current version exactly once'
);

select is(
  (
    public.stk_get_nutrition_guidance(
      (select plan_id from _nutrition_test limit 1),
      1
    ) ->> 'title'
  ),
  'Guía base',
  'version 1 remains unchanged after creating version 2'
);

select is(
  (
    public.stk_get_nutrition_guidance(
      (select plan_id from _nutrition_test limit 1),
      2
    ) ->> 'title'
  ),
  'Guía actualizada',
  'coach can read version 2'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b3000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_list_my_nutrition_guidance()),
  1,
  'client can list own nutrition guidance'
);

select is(
  (
    public.stk_get_nutrition_guidance(
      (select plan_id from _nutrition_test limit 1),
      null
    ) ->> 'title'
  ),
  'Guía actualizada',
  'client can read current guidance version'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a3000000-0000-0000-0000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_list_my_nutrition_guidance()),
  0,
  'unrelated coach cannot discover nutrition guidance'
);

select throws_ok(
  $$select public.stk_get_nutrition_guidance(
      (select plan_id from _nutrition_test limit 1),
      null
    )$$,
  'P0001',
  'Nutrition permission required',
  'unrelated coach cannot read a plan by guessed id'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b3000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select lives_ok(
  $$select public.stk_set_coach_permissions(
      'c3000000-0000-0000-0000-000000000001',
      '{}'::jsonb
    )$$,
  'client can revoke nutrition permission without deleting relationship'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a3000000-0000-0000-0000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select is(
  (select count(*)::integer from public.stk_list_my_nutrition_guidance()),
  0,
  'coach list immediately hides nutrition data after permission removal'
);

select throws_ok(
  $$select public.stk_get_nutrition_guidance(
      (select plan_id from _nutrition_test limit 1),
      null
    )$$,
  'P0001',
  'Nutrition permission required',
  'coach loses read access immediately after permission removal'
);

select throws_ok(
  $$select public.stk_save_nutrition_guidance(
      'b3000000-0000-0000-0000-000000000001',
      (select plan_id from _nutrition_test limit 1),
      jsonb_build_object(
        'title', 'No permitido',
        'scope_notice', 'Orientación alimentaria general que no sustituye atención profesional.',
        'meals', '[]'::jsonb
      )
    )$$,
  'P0001',
  'Nutrition permission required',
  'coach loses write access immediately after permission removal'
);

reset role;

select * from finish();
rollback;
