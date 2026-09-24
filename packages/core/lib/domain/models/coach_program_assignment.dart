enum AssignedProgramStatus {
  assigned,
  accepted,
  archived,
}

class AssignedExerciseSnapshot {
  final String id;
  final int position;
  final String name;
  final String muscleGroup;
  final String equipment;
  final int targetSets;
  final int targetRepsMin;
  final int targetRepsMax;
  final int restSeconds;
  final int warmupSets;
  final int approachSets;
  final bool unilateral;
  final String unilateralTarget;
  final String? supersetKey;

  const AssignedExerciseSnapshot({
    required this.id,
    required this.position,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.targetSets,
    required this.targetRepsMin,
    required this.targetRepsMax,
    required this.restSeconds,
    required this.warmupSets,
    required this.approachSets,
    required this.unilateral,
    required this.unilateralTarget,
    this.supersetKey,
  });

  factory AssignedExerciseSnapshot.fromJson(Map<String, dynamic> json) {
    return AssignedExerciseSnapshot(
      id: '${json['id'] ?? ''}',
      position: (json['position'] as num?)?.toInt() ?? 0,
      name: '${json['name'] ?? ''}'.trim(),
      muscleGroup: '${json['muscle_group'] ?? ''}',
      equipment: '${json['equipment'] ?? ''}',
      targetSets: (json['target_sets'] as num?)?.toInt() ?? 3,
      targetRepsMin: (json['target_reps_min'] as num?)?.toInt() ?? 8,
      targetRepsMax: (json['target_reps_max'] as num?)?.toInt() ?? 12,
      restSeconds: (json['rest_seconds'] as num?)?.toInt() ?? 120,
      warmupSets: (json['warmup_sets'] as num?)?.toInt() ?? 0,
      approachSets: (json['approach_sets'] as num?)?.toInt() ?? 0,
      unilateral: json['unilateral'] as bool? ?? false,
      unilateralTarget: '${json['unilateral_target'] ?? 'other'}',
      supersetKey: json['superset_key']?.toString(),
    );
  }
}

class AssignedRoutineSnapshot {
  final String id;
  final int position;
  final String name;
  final String notes;
  final List<AssignedExerciseSnapshot> exercises;

  const AssignedRoutineSnapshot({
    required this.id,
    required this.position,
    required this.name,
    required this.notes,
    required this.exercises,
  });

  factory AssignedRoutineSnapshot.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'];
    return AssignedRoutineSnapshot(
      id: '${json['id'] ?? ''}',
      position: (json['position'] as num?)?.toInt() ?? 0,
      name: '${json['name'] ?? ''}'.trim(),
      notes: '${json['notes'] ?? ''}',
      exercises: rawExercises is List
          ? rawExercises
              .whereType<Map>()
              .map(
                (item) => AssignedExerciseSnapshot.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <AssignedExerciseSnapshot>[],
    );
  }
}

class CoachProgramAssignmentSummary {
  final String id;
  final String relationshipId;
  final String coachUserId;
  final String clientUserId;
  final String name;
  final int durationWeeks;
  final Set<int> trainingWeekdays;
  final DateTime startsOn;
  final AssignedProgramStatus status;
  final int version;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime updatedAt;

  const CoachProgramAssignmentSummary({
    required this.id,
    required this.relationshipId,
    required this.coachUserId,
    required this.clientUserId,
    required this.name,
    required this.durationWeeks,
    required this.trainingWeekdays,
    required this.startsOn,
    required this.status,
    required this.version,
    required this.createdAt,
    this.acceptedAt,
    required this.updatedAt,
  });

  factory CoachProgramAssignmentSummary.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse('${json['created_at']}') ?? DateTime.now();
    return CoachProgramAssignmentSummary(
      id: '${json['id'] ?? ''}',
      relationshipId: '${json['relationship_id'] ?? ''}',
      coachUserId: '${json['coach_user_id'] ?? ''}',
      clientUserId: '${json['client_user_id'] ?? ''}',
      name: '${json['name'] ?? ''}'.trim(),
      durationWeeks: (json['duration_weeks'] as num?)?.toInt() ?? 8,
      trainingWeekdays: (json['training_weekdays'] as List? ?? const [])
          .map((item) => (item as num?)?.toInt())
          .whereType<int>()
          .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
          .toSet(),
      startsOn:
          DateTime.tryParse('${json['starts_on']}') ?? DateTime.now(),
      status: _assignedProgramStatus(json['status']?.toString()),
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: createdAt,
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.tryParse('${json['accepted_at']}'),
      updatedAt:
          DateTime.tryParse('${json['updated_at']}') ?? createdAt,
    );
  }

  bool isClient(String? userId) => userId != null && clientUserId == userId;

  bool isCoach(String? userId) => userId != null && coachUserId == userId;
}

class CoachProgramAssignment {
  final CoachProgramAssignmentSummary summary;
  final String notes;
  final List<AssignedRoutineSnapshot> routines;

  const CoachProgramAssignment({
    required this.summary,
    required this.notes,
    required this.routines,
  });

  factory CoachProgramAssignment.fromJson(Map<String, dynamic> json) {
    final summary = CoachProgramAssignmentSummary.fromJson(json);
    final rawRoutines = json['routines'];
    return CoachProgramAssignment(
      summary: summary,
      notes: '${json['notes'] ?? ''}',
      routines: rawRoutines is List
          ? rawRoutines
              .whereType<Map>()
              .map(
                (item) => AssignedRoutineSnapshot.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <AssignedRoutineSnapshot>[],
    );
  }
}

AssignedProgramStatus _assignedProgramStatus(String? value) {
  for (final status in AssignedProgramStatus.values) {
    if (status.name == value) return status;
  }
  return AssignedProgramStatus.archived;
}
