import 'dart:math' as math;

import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:riverpod/riverpod.dart';

import 'recovery_provider.dart';
import 'recovery_session_snapshot.dart';

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
  final int? sleepMinutes;
  final double? rirChange;

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
    this.sleepMinutes,
    this.rirChange,
  });
}

class RecoveryPerformanceInsight {
  static const int minimumComparableSessions = 10;

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
      comparableSessions >= minimumComparableSessions && coefficient != null;

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
    RecoverySessionSnapshot? Function(String id)? snapshotFor,
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
    final previousByRoutine = <String, WorkoutSession>{};
    final matchedDays = <String>{};
    final points = <RecoveryPerformancePoint>[];

    for (final session in orderedSessions) {
      final context = snapshotFor?.call(session.id);
      if (context?.adapted == true) continue;
      final routineKey = _routineKey(session);
      if (routineKey == null) continue;
      final currentVolume = _workingVolume(session);
      final previous = previousByRoutine[routineKey];
      if (currentVolume > 0) previousByRoutine[routineKey] = session;
      final dayKey = _dateKey(session.startedAt);
      final recovery = recoveryByDay[dayKey];
      final score = context != null ? context.score :
          recovery != null && !recovery.updatedAt.isAfter(session.startedAt) ? recovery.score : null;
      if (score == null) continue;
      matchedDays.add(dayKey);
      if (previous == null || currentVolume <= 0) continue;
      final previousVolume = _workingVolume(previous);
      if (previousVolume <= 0) continue;
      final previousRir = _meanRir(previous);
      final currentRir = _meanRir(session);

      final rawChange =
          ((currentVolume - previousVolume) / previousVolume) * 100;
      final boundedChange = rawChange.clamp(-100.0, 100.0).toDouble();
      points.add(
        RecoveryPerformancePoint(
          sessionId: session.id,
          routineName: session.routineNameSnapshot,
          date: session.startedAt,
          recoveryScore: score,
          recoveryStatus: (context != null ? context.status : recovery?.status) ??
              (score >= 75 ? RecoveryStatus.ready : score >= 55 ? RecoveryStatus.moderate : RecoveryStatus.low),
          currentVolume: currentVolume,
          previousVolume: previousVolume,
          volumeChangePercent: boundedChange,
          completedWorkingSets: _completedWorkingSets(session),
          durationSeconds: session.durationSeconds,
          sleepMinutes: context?.sleepMinutes,
          rirChange: currentRir == null || previousRir == null ? null : currentRir - previousRir,
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
        if (set.completed && set.setType == WorkoutSetType.working) {
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
          .where((set) => set.completed && set.setType == WorkoutSetType.working)
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
    if (denominator <= 0.000001) return null;
    return (numerator / denominator).clamp(-1.0, 1.0).toDouble();
  }

  static RecoveryPerformanceAssociation _associationFor(
    int pointCount,
    double? coefficient,
  ) {
    if (pointCount < RecoveryPerformanceInsight.minimumComparableSessions || coefficient == null) {
      return RecoveryPerformanceAssociation.insufficient;
    }
    final value = coefficient;
    if (value >= 0.30) return RecoveryPerformanceAssociation.positive;
    if (value <= -0.30) return RecoveryPerformanceAssociation.inverse;
    return RecoveryPerformanceAssociation.neutral;
  }

  static String? _routineKey(WorkoutSession session) {
    final id = session.routineId?.trim();
    if (id == null || id.isEmpty) return null;
    // No comparisons across changed exercise selections or repetition/set
    // structures. Actual completed working sets only, no inferred targets.
    final signature = <String>[];
    for (final exercise in session.exercises) {
      final sets = exercise.sets.where((s) => s.completed &&
        s.setType == WorkoutSetType.working).toList();
      if (sets.isEmpty) continue;
      signature.add('${exercise.exerciseId}:${sets.map((s)=>s.performanceReps).join(",")}');
    }
    if (signature.isEmpty) return null;
    return '$id|${signature.join(";")}';
  }

  static double? _meanRir(WorkoutSession session) {
    final sets = session.exercises.expand((e) => e.sets)
        .where((s) => s.completed && s.setType == WorkoutSetType.working).toList();
    if (sets.isEmpty || sets.any((s) => s.performanceRir == null)) return null;
    return sets.fold<int>(0, (sum,s)=>sum+s.performanceRir!)/sets.length;
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
    snapshotFor: RecoverySessionSnapshot.read,
  );
});
