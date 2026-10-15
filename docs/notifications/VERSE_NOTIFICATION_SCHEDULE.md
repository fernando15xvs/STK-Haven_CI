# Configurable verse notifications

This change replaces the single 08:00 reminder with user-selected local schedules.
The existing `dailyVerseNotifications` flag remains the consent authority; existing
users retain their 08:00 slot until they explicitly save different hours.

- Interval mode: every 30, 60, 120, 180, 240 or 360 minutes within a same-day window.
- Times mode: one or multiple unique local times, sorted and deduplicated.
- Each daily slot uses a different verse drawn from the installed Reina-Valera 1909
  Bible, independently of the dashboard's daily verse. No AI-generated scripture.
- The selected verses are embedded in native repeating notifications. They work
  offline and while the application is closed. Opening the app again or saving
  regenerates the selection. Without opening it, the same daily selection repeats.
  This is deliberately not a claim of unlimited background content rotation on iOS.
- The Bible must already be downloaded; an empty database reports an actionable
  error before replacing any existing notification. Opening the Bible initializes it.
- ID 1301 is retired when a new schedule is successfully prepared; IDs 1310–1357
  belong exclusively to verse schedules. ID 1302 is the one-off diagnostic.
- Permission, Bible availability and iOS pending capacity are checked before
  replacement. The native registered count is checked after scheduling. Partial
  failures clean up only this feature's IDs and are surfaced to the user.
- iOS preflight keeps four slots below its 64-request limit. Personal reminder
  scheduling also checks other families before replacing its own requests.
  Other features can still consume capacity later: the diagnostic exposes a
  missing/partial schedule and can be rerun after changing other reminders.
- Android uses inexact-allow-while-idle scheduling; battery policy may delay delivery.
- Disabling notifications cancels all verse slots and the diagnostic. Testing
  does not enable recurring notifications or change consent/hours.
- A scheduled 30-second test distinguishes immediate foreground banners from
  actual scheduling. The settings page rechecks permissions/count on resume.
- Native service initialization no longer happens before the per-service failure
  boundaries, so a workout plugin failure cannot prevent verse registration.

No Supabase migrations, remote configuration, push credentials or deployments are
needed. Local settings are kept on the device in `verse_notification_schedule_v1`.
Build 1.0.0+5 distinguishes this implementation from earlier build-4 iterations;
the iOS widget build number is incremented alongside the app.

## Validation

Automated tests cover old defaults, intervals, deduplication, invalid times,
persistence without opt-in, distinct verse bodies, local timezone, permission
rejection, iOS capacity, empty Bible, partial failures, diagnostic isolation,
cancellation, and coexistence with personal reminders.

Physical-device acceptance remains necessary: install the new build, download
Bible data, enable verses, save two nearby times, lock the device and verify both
arrive with different text. Test permission denial/re-enabling, disabled consent,
restart, app update and coexistence with personal messages. CI cannot demonstrate
that a specific user's OS settings allow delivery.
