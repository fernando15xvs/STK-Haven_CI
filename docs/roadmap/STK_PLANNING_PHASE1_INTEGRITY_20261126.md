# Phase 1 — planning integrity (2026-11-26)

First implementation batch. Separate allocation and pending cursors, migrate legacy cursor from trusted completion identity only if no newer explicit edit exists, retain existing adapted occurrences to avoid guessing user intent, use distinct continuous opportunity days and share projected dates with the sheet, explicitly bind new mobile starts. Historical workouts are not rewritten.

Regression cases: cursor persistence/rollover, Thursday capacity, stale legacy cursor. Pending: CI, ambiguous existing adapted queue repair, reservation crash recovery, concurrent writes, midnight attribution, complete migration/edits and physical QA. No Supabase changes or merge.
