import 'package:flutter/services.dart';

class DailyStepsBridge {
  const DailyStepsBridge._();

  static const MethodChannel _channel =
      MethodChannel('stk_haven/daily_steps');

  static Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<int?> readTodaySteps() async {
    try {
      final value = await _channel.invokeMethod<int>('getTodaySteps');
      return value == null ? null : value.clamp(0, 250000);
    } on PlatformException {
      return null;
    }
  }
}
