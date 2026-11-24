import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';

class MeasurementReminderSettings {
  final bool enabled;
  final int months;
  final int hour;
  final int minute;
  const MeasurementReminderSettings({
    this.enabled = false,
    this.months = 1,
    this.hour = 9,
    this.minute = 0,
  });
  Map<String, Object> toJson() => {
    'enabled': enabled,
    'months': months,
    'hour': hour,
    'minute': minute,
  };
  factory MeasurementReminderSettings.fromJson(Map<String, dynamic> json) =>
      MeasurementReminderSettings(
        enabled: json['enabled'] == true,
        months: ((json['months'] as num?)?.toInt() ?? 1).clamp(1, 3).toInt(),
        hour: ((json['hour'] as num?)?.toInt() ?? 9).clamp(0, 23).toInt(),
        minute: ((json['minute'] as num?)?.toInt() ?? 0).clamp(0, 59).toInt(),
      );
  DateTime? dueDate(List<BodyMeasurement> measurements) {
    if (measurements.isEmpty) return null;
    final latest = measurements.reduce(
      (a, b) => a.date.isAfter(b.date) ? a : b,
    );
    return nextMeasurementDate(latest.date, months, hour: hour, minute: minute);
  }
}

abstract class MeasurementReminderBackend {
  Future<MeasurementReminderSettings> read();
  Future<void> configure(
    MeasurementReminderSettings settings, List<BodyMeasurement> measurements,
  );
  Future<void> synchronize(List<BodyMeasurement> measurements);
}

class MeasurementReminderService {
  static const notificationId = 1601;
  static MeasurementReminderBackend? _backend;

  static void installBackend(MeasurementReminderBackend? backend) {
    _backend = backend;
  }

  static Future<MeasurementReminderSettings> read() =>
      _backend?.read() ?? Future<MeasurementReminderSettings>.value(
        const MeasurementReminderSettings(),
      );

  static Future<void> configure(
    MeasurementReminderSettings settings, List<BodyMeasurement> measurements,
  ) => _backend?.configure(settings, measurements)
      ?? Future<void>.error(StateError('Los avisos de medidas solo están disponibles en móvil.'));

  static Future<void> synchronize(List<BodyMeasurement> measurements) =>
      _backend?.synchronize(measurements) ?? Future<void>.value();
}
