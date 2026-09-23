import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../database/hive/hive_boxes.dart';

enum RecoveryStatus { ready, moderate, low }

extension RecoveryStatusLabel on RecoveryStatus {
  String get label => switch (this) {
        RecoveryStatus.ready => 'Listo para entrenar',
        RecoveryStatus.moderate => 'Recuperación moderada',
        RecoveryStatus.low => 'Recuperación baja',
      };
}

class RecoveryCheckIn {
  final DateTime date;
  final int energy;
  final int sleep;
  final int stress;
  final int soreness;
  final DateTime updatedAt;

  const RecoveryCheckIn({
    required this.date,
    required this.energy,
    required this.sleep,
    required this.stress,
    required this.soreness,
    required this.updatedAt,
  });

  int get score {
    final positive = energy + sleep + (6 - stress) + (6 - soreness);
    final raw = ((positive / 20) * 100).round();
    return _bounded(raw, min: 0, max: 100);
  }

  RecoveryStatus get status {
    if (score >= 75) return RecoveryStatus.ready;
    if (score >= 55) return RecoveryStatus.moderate;
    return RecoveryStatus.low;
  }

  String get recommendation => switch (status) {
        RecoveryStatus.ready =>
          'Tu recuperación acompaña el plan. Mantén la sesión prevista y progresa si la técnica se siente sólida.',
        RecoveryStatus.moderate =>
          'Puedes entrenar, pero prioriza técnica y RIR. Evita forzar un PR si las primeras series se sienten pesadas.',
        RecoveryStatus.low =>
          'Conviene bajar la exigencia hoy: reduce volumen o intensidad y prioriza recuperación y buena ejecución.',
      };

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'energy': energy,
        'sleep': sleep,
        'stress': stress,
        'soreness': soreness,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory RecoveryCheckIn.fromMap(Map<dynamic, dynamic> map) {
    final rawDate = DateTime.tryParse('${map['date']}') ?? DateTime.now();
    return RecoveryCheckIn(
      date: DateTime(rawDate.year, rawDate.month, rawDate.day),
      energy: _rating(map['energy']),
      sleep: _rating(map['sleep']),
      stress: _rating(map['stress']),
      soreness: _rating(map['soreness']),
      updatedAt: DateTime.tryParse('${map['updatedAt']}') ?? DateTime.now(),
    );
  }

  static int _rating(dynamic value) {
    final parsed = value is int ? value : int.tryParse('$value') ?? 3;
    return _bounded(parsed, min: 1, max: 5);
  }

  static int _bounded(int value, {required int min, required int max}) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

final recoveryProvider =
    NotifierProvider<RecoveryNotifier, RecoveryCheckIn?>(RecoveryNotifier.new);

class RecoveryNotifier extends Notifier<RecoveryCheckIn?> {
  Box<dynamic> get _box => Hive.box(HiveBoxes.recovery);

  @override
  RecoveryCheckIn? build() => _readFor(DateTime.now());

  Future<void> save({
    required int energy,
    required int sleep,
    required int stress,
    required int soreness,
  }) async {
    final now = DateTime.now();
    final entry = RecoveryCheckIn(
      date: DateTime(now.year, now.month, now.day),
      energy: RecoveryCheckIn._bounded(energy, min: 1, max: 5),
      sleep: RecoveryCheckIn._bounded(sleep, min: 1, max: 5),
      stress: RecoveryCheckIn._bounded(stress, min: 1, max: 5),
      soreness: RecoveryCheckIn._bounded(soreness, min: 1, max: 5),
      updatedAt: now,
    );
    await _box.put(_key(entry.date), entry.toMap());
    state = entry;
  }

  Future<void> clearToday() async {
    final now = DateTime.now();
    await _box.delete(_key(now));
    state = null;
  }

  List<RecoveryCheckIn> recent({int limit = 14}) {
    final entries = <RecoveryCheckIn>[];
    for (final value in _box.values) {
      if (value is Map) {
        try {
          entries.add(RecoveryCheckIn.fromMap(value));
        } catch (_) {
          // Ignore malformed local values rather than breaking the dashboard.
        }
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries.take(limit).toList(growable: false);
  }

  RecoveryCheckIn? _readFor(DateTime date) {
    final value = _box.get(_key(date));
    if (value is! Map) return null;
    try {
      return RecoveryCheckIn.fromMap(value);
    } catch (_) {
      return null;
    }
  }

  String _key(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

final recoveryHistoryProvider = Provider<List<RecoveryCheckIn>>((ref) {
  ref.watch(recoveryProvider);
  return ref.read(recoveryProvider.notifier).recent(limit: 14);
});
