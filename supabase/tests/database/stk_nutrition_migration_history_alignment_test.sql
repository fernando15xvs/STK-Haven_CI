-- Local CI only: ensure the already-deployed Nutrition SQL is not replayed
-- under obsolete timestamps. Hosted SQL bodies were compared byte-for-byte.
begin;
select plan(6);
select is((select count(*) from supabase_migrations.schema_migrations
  where version='20261126004841' and name='20261119210000_stk_15plus_legal_receipts_and_nutrition_capabilities'),
  1::bigint, 'Legal receipt history uses hosted version and name');
select is((select count(*) from supabase_migrations.schema_migrations
  where version='20261126004844' and name='20261119220000_stk_nutrition_dual_operator_review'),
  1::bigint, 'Operator review history uses hosted version and name');
select is((select count(*) from supabase_migrations.schema_migrations
  where version='20261126004951' and name='stk_private_development_nutrition_access'),
  1::bigint, 'Private Nutrition history uses hosted version and name');
select is((select count(*) from supabase_migrations.schema_migrations
  where version in ('20261119210000','20261119220000')),
  0::bigint, 'Obsolete versions are absent');
select ok(to_regprocedure('public.stk_get_development_nutrition_access()') is not null,
  'Private Nutrition access RPC exists after migration');
select ok(not public.stk_service_can_use_development_nutrition(
  '00000000-0000-0000-0000-000000000001'::uuid,
  '00000000-0000-0000-0000-000000000002'::uuid),
  'Unknown account has no private access');
select * from finish();
rollback;
