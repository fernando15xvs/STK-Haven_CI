const String dailyVerseTask = 'dailyVerseTask';

/// Pure Dart port; native Workmanager registration is Mobile-owned.
abstract class VerseBackgroundBackend {
  Future<void> initialize();
  Future<void> scheduleDailyVerse(int hour, int minute);
  Future<void> cancelDailyVerse();
}

abstract final class VerseBackgroundService {
  static VerseBackgroundBackend? _backend;

  static void installBackend(VerseBackgroundBackend? backend) {
    _backend = backend;
  }

  static Future<void> initialize() =>
      _backend?.initialize() ?? Future<void>.value();

  static Future<void> scheduleDailyVerse(int hour, int minute) =>
      _backend?.scheduleDailyVerse(hour, minute) ?? Future<void>.value();

  static Future<void> cancelDailyVerse() =>
      _backend?.cancelDailyVerse() ?? Future<void>.value();
}
