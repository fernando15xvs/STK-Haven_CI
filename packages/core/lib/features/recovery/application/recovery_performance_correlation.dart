import 'dart:math' as math;

import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recovery_provider.dart';

enum RecoveryPerformanceAssociation {
  insufficient,
  positive,
  neutral,
  inverse,
}

class RecoveryPerformancePoint {
  final String sessionId;
  final String routineName;
  final DateTime date;
  final int recoveryScore;
  final RecoveryStatus recoveryStatus;
  final double currentVolume;
  final double previousVolume;
  final double volumeChangePercent;
  final int completedWorkingSets;
  final int durationSeconds;

  const RecoveryPerformancePoint({
    required this.sessionId,
    required this.routineName,
    required this.date,
    required this.recoveryScore,
    required this.recoveryStatus,
    required this.currentVolume,
    required this.previousVolume,
    required this.volumeChangePercent,
    required this.completedWorkingSets,
    required this.durationSeconds,
  });
}

class RecoveryPerformanceInsight {
  static const int minimumComparableSessions = 3;

  final List<RecoveryPerformancePoint> points;
  final int matchedWorkoutDays;
  final double? coefficient;
  final RecoveryPerformanceAssociation association;

  const RecoveryPerformanceInsight({
    required this.points,
    required this.matchedWorkoutDays,
    required this.coefficient,
    required this.association,
  });

  int get comparableSessions => points.length;
  bool get hasEnoughData =>
      comparableSessions >= minimumComparableSessions;

  int get missingComparisons {
    final missing = minimumComparableSessions - comparableSessions;
    return missing > 0 ? missing : 0;
  }

  double get averageVolumeChangePercent {
    if (points.isEmpty) return 0;
    final total = points.fold<double>(
      0,
      (sum, point) => sum + point.volumeChangePercent,
    );
    return total / points.length;
  }
}

/// Pairs a recovery check-in with a workout performed on the same local day.
///
/// Performance is the completed working-set volume change versus the previous
/// session of the same routine. This avoids comparing raw volume across
/// unrelated routines. The result describes association only, not causality.
class RecoveryPerformanceCorrelation {
  const RecoveryPerformanceCorrelation._();

  static RecoveryPerformanceInsight analyze({
    required Iterable<RecoveryCheckIn> checkIns,
    required Iterable<WorkoutSession> sessions,
  }) {
    final recoveryByDay = <String, RecoveryCheckIn>{};
    for (final entry in checkIns) {
      final key = _dateKey(entry.date);
      final current = recoveryByDay[key];
      if (current == null || entry.updatedAt.isAfter(current.updatedAt)) {
        recoveryByDay[key] = entry;
      }
    }

    final orderedSessions = sessions.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final previousVolumeByRoutine = <String, double>{};
    final matchedDays = <String>{};
    final points = <RecoveryPerformancePoint>[];

    for (final session in orderedSessions) {
      final routineKey = _routineKey(session);
      final currentVolume = _workingVolume(session);
      final previousVolume = previousVolumeByRoutine[routineKey];
      if (currentVolume > 0) {
        previousVolumeByRoutine[routineKey] = currentVolume;
      }

      final dayKey = _dateKey(session.startedAt);
      final recovery = recoveryByDay[dayKey];
      if (recovery == null) continue;
      matchedDays.add(dayKey);

      if (previousVolume == null ||
          previousVolume <= 0 ||
          currentVolume <= 0) {
        continue;
      }

      final rawChange =
          ((currentVolume - previousVolume) / previousVolume) * 100;
      final boundedChange = rawChange.clamp(-100.0, 100.0).toDouble();
      points.add(
        RecoveryPerformancePoint(
          sessionId: session.id,
          routineName: session.routineNameSnapshot,
          date: session.startedAt,
          recoveryScore: recovery.score,
          recoveryStatus: recovery.status,
          currentVolume: currentVolume,
          previousVolume: previousVolume,
          volumeChangePercent: boundedChange,
          completedWorkingSets: _completedWorkingSets(session),
          durationSeconds: session.durationSeconds,
        ),
      );
    }

    points.sort((a, b) => b.date.compareTo(a.date));
    final coefficient = _pearson(points);
    final association = _associationFor(points.length, coefficient);

    return RecoveryPerformanceInsight(
      points: List<RecoveryPerformancePoint>.unmodifiable(points),
      matchedWorkoutDays: matchedDays.length,
      coefficient: coefficient,
      association: association,
    );
  }

  static double _workingVolume(WorkoutSession session) {
    var volume = 0.0;
    for (final exercise in session.exercises) {
      for (final set in exercise.sets) {
        if (set.completed && !set.warmup) {
          volume += set.performedVolume;
        }
      }
    }
    return volume;
  }

  static int _completedWorkingSets(WorkoutSession session) {
    var completed = 0;
    for (final exercise in session.exercises) {
      completed += exercise.sets
          .where((set) => set.completed && !set.warmup)
          .length;
    }
    return completed;
  }

  static double? _pearson(List<RecoveryPerformancePoint> points) {
    if (points.length < RecoveryPerformanceInsight.minimumComparableSessions) {
      return null;
    }

    final meanRecovery = points
            .map((point) => point.recoveryScore)
            .reduce((a, b) => a + b) /
        points.length;
    final meanPerformance = points
            .map((point) => point.volumeChangePercent)
            .reduce((a, b) => a + b) /
        points.length;

    var numerator = 0.0;
    var recoverySquares = 0.0;
    var performanceSquares = 0.0;
    for (final point in points) {
      final recoveryDelta = point.recoveryScore - meanRecovery;
      final performanceDelta = point.volumeChangePercent - meanPerformance;
      numerator += recoveryDelta * performanceDelta;
      recoverySquares += recoveryDelta * recoveryDelta;
      performanceSquares += performanceDelta * performanceDelta;
    }

    final denominator = math.sqrt(recoverySquares * performanceSquares);
    if (denominator <= 0.000001) return 0;
    return (numerator / denominator).clamp(-1.0, 1.0).toDouble();
  }

  static RecoveryPerformanceAssociation _associationFor(
    int pointCount,
    double? coefficient,
  ) {
    if (pointCount < RecoveryPerformanceInsight.minimumComparableSessions) {
      return RecoveryPerformanceAssociation.insufficient;
    }
    final value = coefficient ?? 0;
    if (value >= 0.30) return RecoveryPerformanceAssociation.positive;
    if (value <= -0.30) return RecoveryPerformanceAssociation.inverse;
    return RecoveryPerformanceAssociation.neutral;
  }

  static String _routineKey(WorkoutSession session) {
    final routineId = session.routineId?.trim();
    if (routineId != null && routineId.isNotEmpty) {
      return 'id:$routineId';
    }
    return 'name:${session.routineNameSnapshot.trim().toLowerCase()}';
  }

  static String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

final recoveryPerformanceProvider =
    Provider<RecoveryPerformanceInsight>((ref) {
  final checkIns = ref.watch(recoveryHistoryProvider);
  final sessions = ref.watch(workoutHistoryProvider);
  return RecoveryPerformanceCorrelation.analyze(
    checkIns: checkIns,
    sessions: sessions,
  );
});
