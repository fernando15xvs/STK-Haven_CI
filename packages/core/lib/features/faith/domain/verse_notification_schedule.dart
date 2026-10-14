enum VerseScheduleMode { interval, times }

/// Wall-clock minutes in the device timezone. Never changes notification consent.
class VerseNotificationSchedule {
  const VerseNotificationSchedule({
    this.mode = VerseScheduleMode.times,
    this.intervalMinutes = 120,
    this.startMinute = 480,
    this.endMinute = 1200,
    this.times = const [480],
  });

  final VerseScheduleMode mode;
  final int intervalMinutes;
  final int startMinute;
  final int endMinute;
  final List<int> times;
  static const intervals = [30, 60, 120, 180, 240, 360];
  static const maxSlots = 48;

  List<int> get minutes {
    if (mode == VerseScheduleMode.times) {
      if (times.isEmpty ||
          times.length > maxSlots ||
          times.any((t) => t < 0 || t >= 1440)) {
        throw const FormatException('Elige entre 1 y 48 horas válidas.');
      }
      return times.toSet().toList()..sort();
    }
    if (!intervals.contains(intervalMinutes) ||
        startMinute < 0 ||
        endMinute >= 1440 ||
        endMinute < startMinute) {
      throw const FormatException(
        'El horario final debe ser posterior al inicial.',
      );
    }
    return [for (var t = startMinute; t <= endMinute; t += intervalMinutes) t];
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'intervalMinutes': intervalMinutes,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'times': times,
  };

  factory VerseNotificationSchedule.fromJson(Map<String, dynamic> json) {
    final result = VerseNotificationSchedule(
      mode: json['mode'] == 'interval'
          ? VerseScheduleMode.interval
          : VerseScheduleMode.times,
      intervalMinutes: json['intervalMinutes'] as int? ?? 120,
      startMinute: json['startMinute'] as int? ?? 480,
      endMinute: json['endMinute'] as int? ?? 1200,
      times: (json['times'] as List?)?.cast<int>() ?? const [480],
    );
    result
        .minutes; // Reject corrupt preferences instead of silently scheduling.
    return result;
  }

  static String formatMinute(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
}
