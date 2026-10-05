import 'package:flutter/services.dart';

enum DailyStepsAccessStatus {
  authorized,
  denied,
  restricted,
  notDetermined,
  unavailable,
  queryFailed,
}

class DailyStepsAccessResult {
  final DailyStepsAccessStatus status;
  final int? steps;
  final String? message;

  const DailyStepsAccessResult({
    required this.status,
    this.steps,
    this.message,
  });
}

class DailyStepsBridge {
  const DailyStepsBridge._();

  static const MethodChannel _channel =
      MethodChannel('stk_haven/daily_steps');

  static Future<DailyStepsAccessResult> requestAccess() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('requestAccess');
      if (raw == null) {
        return const DailyStepsAccessResult(
          status: DailyStepsAccessStatus.queryFailed,
        );
      }
      final status = switch (raw['status']?.toString()) {
        'authorized' => DailyStepsAccessStatus.authorized,
        'denied' => DailyStepsAccessStatus.denied,
        'restricted' => DailyStepsAccessStatus.restricted,
        'not_determined' => DailyStepsAccessStatus.notDetermined,
        'unavailable' => DailyStepsAccessStatus.unavailable,
        _ => DailyStepsAccessStatus.queryFailed,
      };
      final rawSteps = raw['steps'];
      final steps = rawSteps is num
          ? rawSteps.toInt().clamp(0, 250000).toInt()
          : null;
      return DailyStepsAccessResult(
        status: status,
        steps: steps,
        message: raw['message']?.toString(),
      );
    } on MissingPluginException {
      return const DailyStepsAccessResult(
        status: DailyStepsAccessStatus.unavailable,
      );
    } on PlatformException catch (error) {
      return DailyStepsAccessResult(
        status: DailyStepsAccessStatus.queryFailed,
        message: error.message,
      );
    }
  }

  static Future<int?> readTodaySteps() async {
    try {
      final value = await _channel.invokeMethod<int>('getTodaySteps');
      return value == null ? null : value.clamp(0, 250000);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
