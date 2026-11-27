# Hábitos & Lectura — consolidated A–J — 2026-11-27

## Scope
- A: distinct-day completion, flexible weekly goals, dated tasks, quantity tracking, pause history, stable template IDs, explicit skip/undo, recurring weekly native notifications and archive cancellation.
- B: one mobile module with Hábitos, Lectura and Enfoque; PremiumCard and theme; no nested general task hub.
- C: native PDFKit/PdfRenderer page rendering, zoom, checkpoints, full local library, PDF thumbnail covers, duplicate detection, title/author, favorites, physical books, bookmarks, page notes, text search and search-match highlighting. Android text extraction requires API 35+ and compatible PDFs; scanned/password-protected files may not support it.
- D: local session IDs, foreground PDF timing, physical book timer/manual entry, custom finish target, weekly reading metrics and explicit linking without double-counted minutes; voluntary library export.
- E: persistent focus timers, explicit replacement consent, optional habit linking and break session; no change to workout timer.
- F: configurable guided night/breathing/personal pause stages, optional private reflection and intensity; no recovery competition.
- G: protected private journal, opt-in device authentication, search/edit/delete/export, migration copies before redaction. Android AES-GCM AndroidKeyStore in noBackupFilesDir; iOS protected file excluded from device backup. New general STK backups omit personal habit free text; previous backups are unchanged. Android journal UI lock requires API 30+ and configured authentication; iOS uses device owner auth.
- H: Home remains a quick view of the same habit store, Bible plans linked from Bible reader, Coach retains authority for assigned tasks.
- I: backwards-compatible JSON defaults; regression tests for recurrence/quantity/pause, privacy, read tracking, timer identity and mobile route/render bridge.
- J: one mirror snapshot and CI run; no Web/Supabase modification, no merge or release.

## Acceptance
CI is required. Native renderer and authentication require actual iOS and Android QA; source-contract tests and mocked native channels do not prove real-device behavior. No OCR/EPUB, no cloud PDF storage, no clinically interpreted intensity ratings. Optional native focus expiry alerts use the persistent deadline and are cancelled on pause or discard; Android may deliver inexactly under system restrictions. Flexible goal reminders use recurring local time rather than per-goal cancellation. History is reachable with undo; advanced historical filters and arbitrary annotation selection remain follow-up items.
