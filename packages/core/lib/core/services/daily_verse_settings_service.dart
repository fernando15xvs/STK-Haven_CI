import 'daily_verse_settings_service_stub.dart'
    if (dart.library.io) 'daily_verse_settings_service_mobile.dart'
    as implementation;

/// Applies the daily-verse preference only when the target platform supports it.
///
/// Returns the effective value that should be persisted in application state.
Future<bool> configureDailyVerseNotifications(bool enable) {
  return implementation.configureDailyVerseNotifications(enable);
}
