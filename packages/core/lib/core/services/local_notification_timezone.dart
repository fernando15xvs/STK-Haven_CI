import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationTimezone {
  static const MethodChannel _channel =
      MethodChannel('stk_haven/timezone');
  static Future<void>? _initialization;

  static Future<void> ensureInitialized() {
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    if (kIsWeb) return;

    try {
      final zoneName = await _channel.invokeMethod<String>('getTimeZoneName');
      if (zoneName == null || zoneName.trim().isEmpty) return;
      tz.setLocalLocation(tz.getLocation(zoneName.trim()));
    } catch (_) {
      // Keep timezone package's default location if native resolution fails.
      // Mobile targets provide the channel; this fallback prevents scheduling
      // from crashing on unsupported/test platforms.
    }
  }
}
