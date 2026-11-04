# STK Haven public CI snapshot

Canonical repo: fernando15xvs/STK-Haven (private)
PR: #48 UX-13/14 navigation, latest code head: 3144fb7aca53f7ad722fc2ff80a549b6f7df3063
Changed canonical files (5): apps/app_mobile/lib/features/exercises/presentation/pages/exercise_detail_page.dart, apps/app_mobile/lib/features/exercises/presentation/pages/exercise_history_page.dart, apps/app_mobile/lib/features/exercises/presentation/pages/exercise_library_page.dart, apps/app_mobile/test/features/progress/progress_context_navigation_test.dart, docs/progress/PROGRESS_NAVIGATION_CONTEXT_TESTS_20261104.md

CI-only runner fix: the Supabase job now checks that six selected local Docker ports are actually available, after prior run #41918330077 failed bind on 60772. No changes to Supabase hosted databases, migrations, credentials or RLS.

Latest mobile fix: scroll the lazy technical ListView to MIS REGISTROS, and align hit-test CENTER inside viewport before tapping. Previous run #41918330077 failed 5 mobile tests. No PR on mirror; run Actions only.
