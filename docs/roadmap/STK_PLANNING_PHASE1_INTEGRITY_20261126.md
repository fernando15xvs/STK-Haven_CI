# STK Planning — consolidated phases 1–3 (26 Nov 2026)

## Phase 1
- Split allocation cursor and pending pointer, legacy conservative recovery, explicit repair of unresolved rolling slots by selected next routine (completed/omitted/pauses preserved; pending exchanges and deferrals replaced only with confirmation).
- Temporary civil-day unavailability, midnight credit to original occurrence with real completion timestamp, explicit binding, release of orphan reservations via launcher or user action, queued metadata read-modify-write for adaptation/reconciliation, compatible calendar mode changes preserve exceptions.
- Fixed recovery remains explicit; rolling carries unresolved slots bounded by the weekly goal; weekly resets. No historical workout rewrites.

## Phase 2
- Direct actions for absence today, temporary availability, swap, injury/routine pause, repair, reservation review and both next-week forecasts. Explicit selection can start a second program workout after a completed one, subject to weekly goal; no silent independent fallback. Plan closed below goal distinguished from goal reached.
- Existing mobile theme, no new medical inference or automatic exercise clearance.

## Phase 3
- Regression tests: old cursor, roundtrip, 52-week rotation, Tuesday injury / Friday swap / Saturday recovery, temporary availability, midnight, orphan release, concurrent metadata writes, UI source contract. Existing five-combination frequency matrix retained.
- CI gate 7/7 on mirror, compare Git blobs, physical iOS/Android verification and actual restored historical program remain pending. Source-contract tests do not replace device interaction. No production Supabase changes; no merge/release.

## Additional acceptance gates
- Structural change confirmation, guard against overlapping launch actions, retain previous-week recoverable rows and attribution after edits. Adapted insights exclude unresolved sessions that are already forecast for next week; label distinguishes horizon from legacy 14-day estimate.
- New actual widget interaction test (absence and scenario switch), plus compatible-edit test and exception matrix for all five combinations. Physical device test still required; no claim of completed CI before result.
