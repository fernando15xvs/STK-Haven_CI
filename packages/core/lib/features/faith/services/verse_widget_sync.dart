import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One-way, opt-in native snapshot for lock-screen/home-screen widgets.
/// The widget does not read Hive, the journal, the user's mood or account.
class VerseWidgetSync {
  VerseWidgetSync._();

  static const MethodChannel _channel =
      MethodChannel('stk_haven/verse_widget');

  static String dateKey(DateTime value) =>
      '${value.year}-${value.month}-${value.day}';

  static Future<void> publish({
    required String text,
    required String reference,
    required DateTime date,
  }) async {
    if (kIsWeb || !isSupportedPlatform) return;
    final cleanText = text.trim();
    final cleanReference = reference.trim();
    if (cleanText.isEmpty || cleanReference.isEmpty) return;
    await _channel.invokeMethod<bool>('publish', <String, String>{
      'text': cleanText.length <= 1200 ? cleanText : cleanText.substring(0, 1200),
      'reference': cleanReference.length <= 120
          ? cleanReference
          : cleanReference.substring(0, 120),
      'date': dateKey(date),
    });
  }

  static Future<void> clear() async {
    if (kIsWeb || !isSupportedPlatform) return;
    await _channel.invokeMethod<bool>('clear');
  }

  static bool get isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
