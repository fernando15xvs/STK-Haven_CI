# STK Haven Public CI Snapshot

Canonical private repo: fernando15xvs/STK-Haven
Canonical PR: #45 (UX-01 Resumen and calendar legend responsive fix)
Source head: b0375a39028ed6e5834afc4f00bd27b3b9da1fc2
Source branch: feat/progress-summary-no-duplicate-metrics-20261103
Source files in scope (4): apps/app_mobile/lib/features/progress/presentation/pages/progress_page.dart, apps/app_mobile/lib/features/progress/presentation/widgets/calendar_heatmap_card.dart, apps/app_mobile/test/features/progress/progress_summary_scope_test.dart, docs/progress/PROGRESS_SUMMARY_OWNERSHIP_20261103.md

Previous mirror run #41764651282 found true 320px RenderFlex horizontal overflow in summary test. Retry after replacing fixed calendar legend Row with Wrap and stage-specific widget error assertions.

Public mirror only runs Actions on main. All product PRs stay in canonical. No signing material, Hive backups, private history or personal data.
