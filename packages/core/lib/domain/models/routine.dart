enum UnilateralTarget {
  arm,
  leg,
  glute,
  back,
  chest,
  other,
}

extension UnilateralTargetX on UnilateralTarget {
  String get label => switch (this) {
        UnilateralTarget.arm => 'Brazo',
        UnilateralTarget.leg => 'Pierna',
        UnilateralTarget.glute => 'Glúteo',
        UnilateralTarget.back => 'Dorsal / espalda',
        UnilateralTarget.chest => 'Pecho',
        UnilateralTarget.other => 'Otro',
      };
}

class RoutineExercise {
  final String exerciseId;
  final int order;
  final int targetSets;
  final int targetRepsMin;
  final int targetRepsMax;
  final int restSeconds;
  final int warmupSets;
  final int approachSets;
  final bool unilateral;
  final UnilateralTarget unilateralTarget;

  /// Stable identifier shared by the two exercises that form a superset.
  /// `null` means the exercise runs independently.
  final String? supersetGroupId;

  const RoutineExercise({
    required this.exerciseId,
    required this.order,
    required this.targetSets,
    required this.targetRepsMin,
    required this.targetRepsMax,
    required this.restSeconds,
    this.warmupSets = 0,
    this.approachSets = 0,
    this.unilateral = false,
    this.unilateralTarget = UnilateralTarget.other,
    this.supersetGroupId,
  });

  int get totalPlannedSets => targetSets + warmupSets + approachSets;
  bool get isInSuperset => supersetGroupId != null;

  RoutineExercise copyWith({
    String? exerciseId,
    int? order,
    int? targetSets,
    int? targetRepsMin,
    int? targetRepsMax,
    int? restSeconds,
    int? warmupSets,
    int? approachSets,
    bool? unilateral,
    UnilateralTarget? unilateralTarget,
    String? supersetGroupId,
    bool clearSupersetGroupId = false,
  }) {
    return RoutineExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      order: order ?? this.order,
      targetSets: targetSets ?? this.targetSets,
      targetRepsMin: targetRepsMin ?? this.targetRepsMin,
      targetRepsMax: targetRepsMax ?? this.targetRepsMax,
      restSeconds: restSeconds ?? this.restSeconds,
      warmupSets: warmupSets ?? this.warmupSets,
      approachSets: approachSets ?? this.approachSets,
      unilateral: unilateral ?? this.unilateral,
      unilateralTarget: unilateralTarget ?? this.unilateralTarget,
      supersetGroupId:
          clearSupersetGroupId ? null : (supersetGroupId ?? this.supersetGroupId),
    );
  }
}

class Routine {
  final String id;
  final String name;
  final List<int> scheduledDays; // 1=Mon, 2=Tue, ... 7=Sun
  final List<RoutineExercise> exercises;
  final DateTime createdAt;
  final String notes;

  /// In-memory signal used when updating an existing routine. It lets the
  /// repository distinguish "this editor never touched notes" from an
  /// intentional clear (`notes: ''`). It is not persisted.
  final bool notesWereProvided;

  Routine({
    required this.id,
    required this.name,
    required this.scheduledDays,
    required this.exercises,
    required this.createdAt,
    String? notes,
  })  : notes = notes ?? '',
        notesWereProvided = notes != null;

  bool get hasNotes => notes.trim().isNotEmpty;

  Routine copyWith({
    String? id,
    String? name,
    List<int>? scheduledDays,
    List<RoutineExercise>? exercises,
    DateTime? createdAt,
    String? notes,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      exercises: exercises ?? this.exercises,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }
}
