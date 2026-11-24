import 'package:core/features/faith/services/verse_widget_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The only owner of the native `stk_haven/verse_widget` MethodChannel.
class MobileVerseWidgetBackend implements VerseWidgetBackend {
  const MobileVerseWidgetBackend();

  static const MethodChannel _channel = MethodChannel(
    'stk_haven/verse_widget',
  );

  @override
  bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> publish(Map<String, String> snapshot) async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod<bool>('publish', snapshot);
  }

  @override
  Future<Map<String, bool>?> diagnostics() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    try {
      return await _channel.invokeMapMethod<String, bool>('diagnostics');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod<bool>('clear');
  }
}
