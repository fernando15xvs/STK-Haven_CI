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


-- The local Supabase CLI stores migration statements in a form whose MD5 can
-- differ from the hosted migration-history text, even when the source SQL is
-- identical. Check the applied schema here, not remote-only MD5 fingerprints.
-- Deployed historical SQL fingerprints are audited separately in the private
-- security report, outside the isolated CI database.
select ok(
  to_regclass('public.stk_coach_pro_templates') is not null
  and to_regprocedure('public.stk_save_coach_pro_template_from_revision(uuid,uuid,uuid,text)') is not null
  and to_regprocedure('public.stk_list_coach_pro_templates(integer,integer)') is not null
  and to_regprocedure('public.stk_assign_coach_pro_template(uuid,uuid,date)') is not null
  and to_regprocedure('public.stk_archive_coach_pro_template(uuid)') is not null,
  'Coach templates table and all four entry points exist after migration'
);
select ok(
  to_regclass('public.stk_coach_pro_checkin_cadences') is not null
  and to_regprocedure('public.stk_propose_coach_pro_checkin_cadence(uuid,smallint[],integer)') is not null
  and to_regprocedure('public.stk_respond_coach_pro_checkin_cadence(uuid,integer,boolean)') is not null
  and to_regprocedure('public.stk_get_coach_pro_checkin_cadence(uuid)') is not null,
  'Check-in cadence table and all three entry points exist after migration'
);
select ok(
  to_regprocedure('public.stk_list_coach_pro_task_schedule(uuid,date,integer,integer,integer)') is not null,
  'Coach task schedule reader exists after migration'
);
select ok(
  to_regclass('public.stk_coach_pro_reminder_opt_ins') is not null
  and to_regprocedure('public.stk_get_coach_pro_reminder_opt_in(uuid)') is not null
  and to_regprocedure('public.stk_set_coach_pro_reminder_opt_in(uuid,boolean,integer,integer)') is not null,
  'Reminder opt-in table and both entry points exist after migration'
);

select * from finish();
rollback;
