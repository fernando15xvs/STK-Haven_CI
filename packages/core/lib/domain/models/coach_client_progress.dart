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

class CoachFrequencyAdherence {
  final String assignmentId;
  final String assignmentName;
  final DateTime startsOn;
  final DateTime endsOn;
  final int scheduledSessions7d;
  final int completedSessions7d;
  final int? percent7d;
  final int scheduledSessions30d;
  final int completedSessions30d;
  final int? percent30d;

  const CoachFrequencyAdherence({
    required this.assignmentId,
    required this.assignmentName,
    required this.startsOn,
    required this.endsOn,
    required this.scheduledSessions7d,
    required this.completedSessions7d,
    required this.percent7d,
    required this.scheduledSessions30d,
    required this.completedSessions30d,
    required this.percent30d,
  });

  factory CoachFrequencyAdherence.fromJson(Map<String, dynamic> json) {
    DateTime date(String key) {
      final value = DateTime.tryParse('${json[key]}');
      if (value == null) {
        throw const FormatException('Invalid adherence date');
      }
      return value;
    }

    int integer(String key, int max) {
      final value = json[key];
      if (value is! int || value < 0 || value > max) {
        throw const FormatException('Invalid adherence value');
      }
      return value;
    }

    int? percent(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! int || value < 0 || value > 100) {
        throw const FormatException('Invalid adherence percent');
      }
      return value;
    }

    final assignmentId = json['assignment_id'];
    final assignmentName = json['assignment_name'];
    if (assignmentId is! String ||
        assignmentId.isEmpty ||
        assignmentName is! String ||
        assignmentName.trim().isEmpty) {
      throw const FormatException('Invalid adherence assignment');
    }

    final scheduled7d = integer('scheduled_sessions_7d', 14);
    final completed7d = integer('completed_sessions_7d', 1000);
    final scheduled30d = integer('scheduled_sessions_30d', 60);
    final completed30d = integer('completed_sessions_30d', 4000);
    final percent7d = percent('percent_7d');
    final percent30d = percent('percent_30d');

    if ((scheduled7d == 0) != (percent7d == null) ||
        (scheduled30d == 0) != (percent30d == null)) {
      throw const FormatException('Invalid adherence denominator');
    }

    return CoachFrequencyAdherence(
      assignmentId: assignmentId,
      assignmentName: assignmentName.trim(),
      startsOn: date('starts_on'),
      endsOn: date('ends_on'),
      scheduledSessions7d: scheduled7d,
      completedSessions7d: completed7d,
      percent7d: percent7d,
      scheduledSessions30d: scheduled30d,
      completedSessions30d: completed30d,
      percent30d: percent30d,
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
  final bool trendBaselineAvailable;
  final int workoutsPrevious7d;
  final int trainingMinutesPrevious7d;
  final int completedWorkingSetsPrevious7d;
  final double volumePrevious7d;
  final CoachFrequencyAdherence? frequencyAdherence;
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
    this.trendBaselineAvailable = false,
    this.workoutsPrevious7d = 0,
    this.trainingMinutesPrevious7d = 0,
    this.completedWorkingSetsPrevious7d = 0,
    this.volumePrevious7d = 0,
    this.frequencyAdherence,
    this.recentWorkouts = const <CoachSharedWorkoutSummary>[],
  });

  int get workoutsTrendDelta7d => workouts7d - workoutsPrevious7d;
  int get trainingMinutesTrendDelta7d =>
      trainingMinutes7d - trainingMinutesPrevious7d;
  int get workingSetsTrendDelta7d =>
      completedWorkingSets7d - completedWorkingSetsPrevious7d;
  double get volumeTrendDelta7d => volume7d - volumePrevious7d;

  Map<String, dynamic> snapshotToJson() => <String, dynamic>{
        'workouts_7d': workouts7d,
        'workouts_30d': workouts30d,
        'training_minutes_7d': trainingMinutes7d,
        'completed_working_sets_7d': completedWorkingSets7d,
        'volume_7d': volume7d,
        'average_rir_7d': averageRir7d,
        'last_workout_at': lastWorkoutAt?.toUtc().toIso8601String(),
        'generated_at': generatedAt.toUtc().toIso8601String(),
        'trend_baseline_available': trendBaselineAvailable,
        'workouts_previous_7d': workoutsPrevious7d,
        'training_minutes_previous_7d': trainingMinutesPrevious7d,
        'completed_working_sets_previous_7d':
            completedWorkingSetsPrevious7d,
        'volume_previous_7d': volumePrevious7d,
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

    final adherenceRaw = json['adherence'];
    final adherence = adherenceRaw is Map
        ? CoachFrequencyAdherence.fromJson(
            Map<String, dynamic>.from(adherenceRaw),
          )
        : null;

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
      trendBaselineAvailable:
          progress['trend_baseline_available'] as bool? ?? false,
      workoutsPrevious7d:
          (progress['workouts_previous_7d'] as num?)?.toInt() ?? 0,
      trainingMinutesPrevious7d:
          (progress['training_minutes_previous_7d'] as num?)?.toInt() ?? 0,
      completedWorkingSetsPrevious7d:
          (progress['completed_working_sets_previous_7d'] as num?)?.toInt() ??
              0,
      volumePrevious7d:
          (progress['volume_previous_7d'] as num?)?.toDouble() ?? 0,
      frequencyAdherence: adherence,
      recentWorkouts: workouts,
    );
  }
}
