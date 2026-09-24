class CoachSharedWorkoutSummary {
  final String workoutId;
  final DateTime startedAt;
  final String routineName;
  final int durationSeconds;
  final int plannedWorkingSets;
  final int completedWorkingSets;
  final int completionPercent;
  final double volume;
  final double? averageRir;

  const CoachSharedWorkoutSummary({
    required this.workoutId,
    required this.startedAt,
    required this.routineName,
    required this.durationSeconds,
    required this.plannedWorkingSets,
    required this.completedWorkingSets,
    required this.completionPercent,
    required this.volume,
    this.averageRir,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'workout_id': workoutId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'routine_name': routineName,
        'duration_seconds': durationSeconds,
        'planned_working_sets': plannedWorkingSets,
        'completed_working_sets': completedWorkingSets,
        'completion_percent': completionPercent,
        'volume': volume,
        'average_rir': averageRir,
      };

  factory CoachSharedWorkoutSummary.fromJson(Map<String, dynamic> json) {
    return CoachSharedWorkoutSummary(
      workoutId: '${json['workout_id'] ?? ''}',
      startedAt:
          DateTime.tryParse('${json['started_at']}') ?? DateTime.now(),
      routineName: '${json['routine_name'] ?? ''}',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      plannedWorkingSets:
          (json['planned_working_sets'] as num?)?.toInt() ?? 0,
      completedWorkingSets:
          (json['completed_working_sets'] as num?)?.toInt() ?? 0,
      completionPercent:
          (json['completion_percent'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
      averageRir: (json['average_rir'] as num?)?.toDouble(),
    );
  }
}

class CoachClientProgress {
  final String? clientUserId;
  final bool available;
  final bool workoutsVisible;
  final int workouts7d;
  final int workouts30d;
  final int trainingMinutes7d;
  final int completedWorkingSets7d;
  final double volume7d;
  final double? averageRir7d;
  final DateTime? lastWorkoutAt;
  final DateTime generatedAt;
  final List<CoachSharedWorkoutSummary> recentWorkouts;

  const CoachClientProgress({
    this.clientUserId,
    this.available = true,
    this.workoutsVisible = true,
    required this.workouts7d,
    required this.workouts30d,
    required this.trainingMinutes7d,
    required this.completedWorkingSets7d,
    required this.volume7d,
    this.averageRir7d,
    this.lastWorkoutAt,
    required this.generatedAt,
    this.recentWorkouts = const <CoachSharedWorkoutSummary>[],
  });

  Map<String, dynamic> snapshotToJson() => <String, dynamic>{
        'workouts_7d': workouts7d,
        'workouts_30d': workouts30d,
        'training_minutes_7d': trainingMinutes7d,
        'completed_working_sets_7d': completedWorkingSets7d,
        'volume_7d': volume7d,
        'average_rir_7d': averageRir7d,
        'last_workout_at': lastWorkoutAt?.toUtc().toIso8601String(),
        'generated_at': generatedAt.toUtc().toIso8601String(),
      };

  List<Map<String, dynamic>> recentWorkoutsToJson() =>
      recentWorkouts.map((item) => item.toJson()).toList(growable: false);

  factory CoachClientProgress.fromRpcJson(Map<String, dynamic> json) {
    final progressRaw = json['progress'];
    if (progressRaw is! Map) {
      throw const FormatException('Client progress payload was empty.');
    }
    final progress = Map<String, dynamic>.from(progressRaw);
    final workoutsRaw = json['recent_workouts'];
    final workouts = workoutsRaw is List
        ? workoutsRaw
            .whereType<Map>()
            .map(
              (item) => CoachSharedWorkoutSummary.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false)
        : const <CoachSharedWorkoutSummary>[];

    return CoachClientProgress(
      clientUserId: progress['client_user_id']?.toString(),
      available: progress['available'] as bool? ?? false,
      workoutsVisible: json['workouts_visible'] as bool? ?? false,
      workouts7d: (progress['workouts_7d'] as num?)?.toInt() ?? 0,
      workouts30d: (progress['workouts_30d'] as num?)?.toInt() ?? 0,
      trainingMinutes7d:
          (progress['training_minutes_7d'] as num?)?.toInt() ?? 0,
      completedWorkingSets7d:
          (progress['completed_working_sets_7d'] as num?)?.toInt() ?? 0,
      volume7d: (progress['volume_7d'] as num?)?.toDouble() ?? 0,
      averageRir7d: (progress['average_rir_7d'] as num?)?.toDouble(),
      lastWorkoutAt: progress['last_workout_at'] == null
          ? null
          : DateTime.tryParse('${progress['last_workout_at']}'),
      generatedAt:
          DateTime.tryParse('${progress['generated_at']}') ?? DateTime.now(),
      recentWorkouts: workouts,
    );
  }
}
