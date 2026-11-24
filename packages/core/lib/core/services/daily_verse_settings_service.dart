/// The stored user preference remains in Core; platform effects belong to Mobile.
abstract class DailyVerseSettingsBackend {
  Future<bool> configure(bool enable);
}

abstract final class DailyVerseSettingsService {
  static DailyVerseSettingsBackend? _backend;

  static void installBackend(DailyVerseSettingsBackend? backend) {
    _backend = backend;
  }

  static Future<bool> configure(bool enabled) =>
      _backend?.configure(enabled) ?? Future<bool>.value(false);
}

/// Legacy Core API used by Settings, retaining the effective bool contract.
Future<bool> configureDailyVerseNotifications(bool enable) =>
    DailyVerseSettingsService.configure(enable);
