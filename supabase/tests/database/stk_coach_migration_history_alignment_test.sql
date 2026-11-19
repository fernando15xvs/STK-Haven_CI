-- CI-only read of local Supabase migration history after migration up/reset.
-- Canonical versions were verified on 2026-11-19 against the deployed
-- STK-Haven migration log: all four historical SQL bodies match exactly.
-- Never run migration repair, db push or production writes from this test.
begin;
select plan(12);

select is(
  (select count(*) from supabase_migrations.schema_migrations
   where version = '20261008185301' and name = 'stk_coach_pro_templates'),
  1::bigint, 'Coach template history uses the deployed migration version'
);
select is(
  (select count(*) from supabase_migrations.schema_migrations
   where version = '20261008185313' and name = 'stk_coach_pro_checkin_cadence'),
  1::bigint, 'Check-in cadence history uses the deployed migration version'
);
select is(
  (select count(*) from supabase_migrations.schema_migrations
   where version = '20261008192311' and name = 'stk_coach_pro_task_schedule'),
  1::bigint, 'Task schedule history uses the deployed migration version'
);
select is(
  (select count(*) from supabase_migrations.schema_migrations
   where version = '20261008224753' and name = 'stk_coach_pro_reminder_opt_in'),
  1::bigint, 'Reminder opt-in history uses the deployed migration version'
);

select is(
  (select count(*) from supabase_migrations.schema_migrations
   where version = '20261008170000'),
  0::bigint, 'Obsolete coach template timestamp must not be reapplied'
);
select is(
  (select count(*) from supabase_migrations.schema_migrations
   where version = '20261008200000'),
  0::bigint, 'Obsolete check-in timestamp must not be reapplied'
);
select is(
  (select count(*) from supabase_migrations.schema_migrations
   where version = '20261008213000'),
  0::bigint, 'Obsolete task schedule timestamp must not be reapplied'
);
select is(
  (select count(*) from supabase_migrations.schema_migrations
   where version = '20261008233000'),
  0::bigint, 'Obsolete reminder timestamp must not be reapplied'
);

select is(
  (select md5(statements[1]) from supabase_migrations.schema_migrations
   where version = '20261008185301'),
  '98f18fa2cf1834985471414011dccb3c',
  'Coach template historical SQL matches deployed bytes'
);
select is(
  (select md5(statements[1]) from supabase_migrations.schema_migrations
   where version = '20261008185313'),
  'd5803411fde7dd1b46312c7130163b57',
  'Check-in cadence historical SQL matches deployed bytes'
);
select is(
  (select md5(statements[1]) from supabase_migrations.schema_migrations
   where version = '20261008192311'),
  '5ae7a85b3a7736795d8c7f45f2f3a17f',
  'Task schedule historical SQL matches deployed bytes'
);
select is(
  (select md5(statements[1]) from supabase_migrations.schema_migrations
   where version = '20261008224753'),
  '8de8b4b7b888583c661a5e9291134504',
  'Reminder historical SQL matches deployed bytes'
);

select * from finish();
rollback;
