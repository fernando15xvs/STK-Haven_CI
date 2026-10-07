class CoachExerciseProgressSummary {
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final DateTime lastPerformedAt;
  final DateTime generatedAt;
  final int sessions30d;
  final int workingSets30d;
  final double volume30d;
  final double? averageRir30d;
  final int sessionsPrevious30d;
  final int workingSetsPrevious30d;
  final double volumePrevious30d;
  final double? bestEstimated1Rm30d;
  final double? bestEstimated1RmPrevious30d;
  final double? bestWeight;
  final DateTime? bestWeightAt;
  final double? bestEstimated1Rm;
  final DateTime? bestEstimated1RmAt;
  final double? bestSetVolume;
  final DateTime? bestSetVolumeAt;

  const CoachExerciseProgressSummary({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.lastPerformedAt,
    required this.generatedAt,
    required this.sessions30d,
    required this.workingSets30d,
    required this.volume30d,
    required this.averageRir30d,
    required this.sessionsPrevious30d,
    required this.workingSetsPrevious30d,
    required this.volumePrevious30d,
    required this.bestEstimated1Rm30d,
    required this.bestEstimated1RmPrevious30d,
    required this.bestWeight,
    required this.bestWeightAt,
    required this.bestEstimated1Rm,
    required this.bestEstimated1RmAt,
    required this.bestSetVolume,
    required this.bestSetVolumeAt,
  });

  int get sessionsDelta30d => sessions30d - sessionsPrevious30d;
  int get workingSetsDelta30d => workingSets30d - workingSetsPrevious30d;
  double get volumeDelta30d => volume30d - volumePrevious30d;

  double? get estimated1RmDelta30d =>
      bestEstimated1Rm30d == null || bestEstimated1RmPrevious30d == null
          ? null
          : bestEstimated1Rm30d! - bestEstimated1RmPrevious30d!;

  Map<String, dynamic> toSyncJson() => <String, dynamic>{
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'muscle_group': muscleGroup,
        'last_performed_at': lastPerformedAt.toUtc().toIso8601String(),
        'generated_at': generatedAt.toUtc().toIso8601String(),
        'sessions_30d': sessions30d,
        'working_sets_30d': workingSets30d,
        'volume_30d': volume30d,
        'average_rir_30d': averageRir30d,
        'sessions_previous_30d': sessionsPrevious30d,
        'working_sets_previous_30d': workingSetsPrevious30d,
        'volume_previous_30d': volumePrevious30d,
        'best_estimated_1rm_30d': bestEstimated1Rm30d,
        'best_estimated_1rm_previous_30d': bestEstimated1RmPrevious30d,
        'best_weight': bestWeight,
        'best_weight_at': bestWeightAt?.toUtc().toIso8601String(),
        'best_estimated_1rm': bestEstimated1Rm,
        'best_estimated_1rm_at':
            bestEstimated1RmAt?.toUtc().toIso8601String(),
        'best_set_volume': bestSetVolume,
        'best_set_volume_at': bestSetVolumeAt?.toUtc().toIso8601String(),
      };

  factory CoachExerciseProgressSummary.fromJson(Map<String, dynamic> json) {
    int integer(String key, int max) {
      final value = json[key];
      if (value is! int || value < 0 || value > max) {
        throw const FormatException('Invalid exercise progress count');
      }
      return value;
    }

    double numeric(String key, num max) {
      final value = json[key];
      if (value is! num ||
          !value.isFinite ||
          value < 0 ||
          value > max) {
        throw const FormatException('Invalid exercise progress value');
      }
      return value.toDouble();
    }

    double? optionalNumeric(String key, num max) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num ||
          !value.isFinite ||
          value < 0 ||
          value > max) {
        throw const FormatException('Invalid exercise progress value');
      }
      return value.toDouble();
    }

    DateTime date(String key) {
      final parsed = DateTime.tryParse('${json[key]}');
      if (parsed == null) {
        throw const FormatException('Invalid exercise progress date');
      }
      return parsed;
    }

    DateTime? optionalDate(String key) {
      final value = json[key];
      if (value == null) return null;
      final parsed = DateTime.tryParse('$value');
      if (parsed == null) {
        throw const FormatException('Invalid exercise progress date');
      }
      return parsed;
    }

    final exerciseId = json['exercise_id'];
    final exerciseName = json['exercise_name'];
    final muscleGroup = json['muscle_group'];
    if (exerciseId is! String ||
        exerciseId.trim().isEmpty ||
        exerciseId.runes.length > 120 ||
        exerciseName is! String ||
        exerciseName.trim().isEmpty ||
        exerciseName.runes.length > 160 ||
        muscleGroup is! String ||
        muscleGroup.runes.length > 120) {
      throw const FormatException('Invalid exercise progress identity');
    }

    final averageRir30d = optionalNumeric('average_rir_30d', 10);
    final bestWeight = optionalNumeric('best_weight', 1000000);
    final bestEstimated1Rm =
        optionalNumeric('best_estimated_1rm', 1000000);
    final bestSetVolume =
        optionalNumeric('best_set_volume', 1000000000);
    final bestEstimated1Rm30d =
        optionalNumeric('best_estimated_1rm_30d', 1000000);
    final bestEstimated1RmPrevious30d =
        optionalNumeric('best_estimated_1rm_previous_30d', 1000000);

    final bestWeightAt = optionalDate('best_weight_at');
    final bestEstimated1RmAt = optionalDate('best_estimated_1rm_at');
    final bestSetVolumeAt = optionalDate('best_set_volume_at');

    if ((bestWeight == null) != (bestWeightAt == null) ||
        (bestEstimated1Rm == null) != (bestEstimated1RmAt == null) ||
        (bestSetVolume == null) != (bestSetVolumeAt == null)) {
      throw const FormatException('Invalid exercise PR timestamp');
    }

    return CoachExerciseProgressSummary(
      exerciseId: exerciseId.trim(),
      exerciseName: exerciseName.trim(),
      muscleGroup: muscleGroup.trim(),
      lastPerformedAt: date('last_performed_at'),
      generatedAt: date('generated_at'),
      sessions30d: integer('sessions_30d', 1000),
      workingSets30d: integer('working_sets_30d', 100000),
      volume30d: numeric('volume_30d', 1000000000000),
      averageRir30d: averageRir30d,
      sessionsPrevious30d: integer('sessions_previous_30d', 1000),
      workingSetsPrevious30d:
          integer('working_sets_previous_30d', 100000),
      volumePrevious30d:
          numeric('volume_previous_30d', 1000000000000),
      bestEstimated1Rm30d: bestEstimated1Rm30d,
      bestEstimated1RmPrevious30d: bestEstimated1RmPrevious30d,
      bestWeight: bestWeight,
      bestWeightAt: bestWeightAt,
      bestEstimated1Rm: bestEstimated1Rm,
      bestEstimated1RmAt: bestEstimated1RmAt,
      bestSetVolume: bestSetVolume,
      bestSetVolumeAt: bestSetVolumeAt,
    );
  }
}
