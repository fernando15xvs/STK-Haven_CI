/// A Dart-only boundary for the signed home/lock-screen verse widget.
abstract class VerseWidgetBackend {
  bool get isSupportedPlatform;
  Future<void> publish(Map<String, String> snapshot);
  Future<Map<String, bool>?> diagnostics();
  Future<void> clear();
}

abstract final class VerseWidgetSync {
  static VerseWidgetBackend? _backend;

  static void installBackend(VerseWidgetBackend? backend) {
    _backend = backend;
  }

  static bool get isSupportedPlatform =>
      _backend?.isSupportedPlatform ?? false;

  static String dateKey(DateTime value) =>
      '${value.year}-${value.month}-${value.day}';

  static Future<void> publish({
    required String text,
    required String reference,
    required DateTime date,
  }) async {
    final backend = _backend;
    if (backend == null || !backend.isSupportedPlatform) return;
    final cleanText = text.trim();
    final cleanReference = reference.trim();
    if (cleanText.isEmpty || cleanReference.isEmpty) return;
    await backend.publish(<String, String>{
      'text': cleanText.length <= 1200
          ? cleanText
          : cleanText.substring(0, 1200),
      'reference': cleanReference.length <= 120
          ? cleanReference
          : cleanReference.substring(0, 120),
      'date': dateKey(date),
    });
  }

  static Future<Map<String, bool>?> diagnostics() =>
      _backend?.diagnostics() ?? Future<Map<String, bool>?>.value();

  static Future<void> clear() =>
      _backend?.clear() ?? Future<void>.value();
}
