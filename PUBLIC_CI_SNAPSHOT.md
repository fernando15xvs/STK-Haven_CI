# STK Haven CI-only snapshot

Canonical private repo: fernando15xvs/STK-Haven
PR: #48 UX-13/14
Exact source head: 3bee1898aa07eb389742b853edfb307cbf852257
Canonical files (5): apps/app_mobile/lib/features/exercises/presentation/pages/exercise_detail_page.dart, apps/app_mobile/lib/features/exercises/presentation/pages/exercise_history_page.dart, apps/app_mobile/lib/features/exercises/presentation/pages/exercise_library_page.dart, apps/app_mobile/test/features/progress/progress_context_navigation_test.dart, docs/progress/PROGRESS_NAVIGATION_CONTEXT_TESTS_20261104.md

Previous CI #41929958345 attempt 1 was canceled after navigation tests hit 10-minute Flutter FakeAsync timeouts due to awaiting Scrollable.ensureVisible with nonzero duration. The newest canonical head changes to Duration.zero for immediate scroll. Public mirror CI-only workflow now cancels old stale in-progress snapshots, allowing current evidence to run; CI-only port discovery remains intact. No PR or product code authored on mirror.
