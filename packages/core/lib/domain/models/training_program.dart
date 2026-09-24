class ProgramCompletion {
  final String workoutSessionId;
  final String routineId;
  final DateTime completedAt;
  final int rotationIndex;
  final int programWeek;

  const ProgramCompletion({
    required this.workoutSessionId,
    required this.routineId,
    required this.completedAt,
    required this.rotationIndex,
    required this.programWeek,
  });

  Map<String, dynamic> toJson() => {
        'workoutSessionId': workoutSessionId,
        'routineId': routineId,
        'completedAt': completedAt.toIso8601String(),
        'rotationIndex': rotationIndex,
        'programWeek': programWeek,
      };

  factory ProgramCompletion.fromJson(Map<String, dynamic> json) {
    return ProgramCompletion(
      workoutSessionId: json['workoutSessionId'] as String,
      routineId: json['routineId'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      rotationIndex: (json['rotationIndex'] as num?)?.toInt() ?? 0,
      programWeek: (json['programWeek'] as num?)?.toInt() ?? 1,
    );
  }
}

/// User-owned training cycle made of existing global routines.
///
/// Routine order is the rotation source of truth. Calendar scheduling remains
/// optional context owned by each Routine; it never changes A→B→C sequencing.
class TrainingProgram {
  final String id;
  final String name;
  final List<String> routineIds;
  final DateTime createdAt;
  final DateTime startedAt;
  final int durationWeeks;
  final Set<int> trainingWeekdays;
  final Set<int> deloadWeeks;
  final int nextRotationIndex;
  final bool isActive;
  final String notes;
  final List<ProgramCompletion> completions;

  const TrainingProgram({
    required this.id,
    required this.name,
    required this.routineIds,
    required this.createdAt,
    required this.startedAt,
    this.durationWeeks = 8,
    this.trainingWeekdays = const <int>{},
    this.deloadWeeks = const <int>{},
    this.nextRotationIndex = 0,
    this.isActive = true,
    this.notes = '',
    this.completions = const <ProgramCompletion>[],
  });

  bool get hasRoutines => routineIds.isNotEmpty;

  int get normalizedNextRotationIndex {
    if (routineIds.isEmpty) return 0;
    return nextRotationIndex % routineIds.length;
  }

  String? get nextRoutineId {
    if (routineIds.isEmpty) return null;
    return routineIds[normalizedNextRotationIndex];
  }

  int weekAt(DateTime instant) {
    final elapsedDays = instant.difference(startedAt).inDays;
    if (elapsedDays <= 0) return 1;
    return (elapsedDays ~/ 7) + 1;
  }

  bool isDeloadWeekAt(DateTime instant) => deloadWeeks.contains(weekAt(instant));

  bool get isCycleComplete {
    if (durationWeeks <= 0) return false;
    return weekAt(DateTime.now()) > durationWeeks;
  }

  TrainingProgram recordCompletion({
    required String workoutSessionId,
    required String routineId,
    required DateTime completedAt,
  }) {
    if (routineIds.isEmpty) return this;

    final expectedIndex = normalizedNextRotationIndex;
    final expectedRoutine = routineIds[expectedIndex];

    // A workout belonging to another routine may still exist in history, but
    // it must not silently advance this program's rotation.
    if (routineId != expectedRoutine) return this;

    if (completions.any((item) => item.workoutSessionId == workoutSessionId)) {
      return this;
    }

    final nextIndex = (expectedIndex + 1) % routineIds.length;
    return copyWith(
      nextRotationIndex: nextIndex,
      completions: [
        ...completions,
        ProgramCompletion(
          workoutSessionId: workoutSessionId,
          routineId: routineId,
          completedAt: completedAt,
          rotationIndex: expectedIndex,
          programWeek: weekAt(completedAt),
        ),
      ],
    );
  }

  TrainingProgram duplicate({
    required String newId,
    required String newName,
    required DateTime now,
  }) {
    return TrainingProgram(
      id: newId,
      name: newName,
      routineIds: List<String>.from(routineIds),
      createdAt: now,
      startedAt: now,
      durationWeeks: durationWeeks,
      trainingWeekdays: Set<int>.from(trainingWeekdays),
      deloadWeeks: Set<int>.from(deloadWeeks),
      nextRotationIndex: 0,
      isActive: false,
      notes: notes,
      completions: const [],
    );
  }

  TrainingProgram copyWith({
    String? id,
    String? name,
    List<String>? routineIds,
    DateTime? createdAt,
    DateTime? startedAt,
    int? durationWeeks,
    Set<int>? trainingWeekdays,
    Set<int>? deloadWeeks,
    int? nextRotationIndex,
    bool? isActive,
    String? notes,
    List<ProgramCompletion>? completions,
  }) {
    return TrainingProgram(
      id: id ?? this.id,
      name: name ?? this.name,
      routineIds: routineIds ?? this.routineIds,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      trainingWeekdays: trainingWeekdays ?? this.trainingWeekdays,
      deloadWeeks: deloadWeeks ?? this.deloadWeeks,
      nextRotationIndex: nextRotationIndex ?? this.nextRotationIndex,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      completions: completions ?? this.completions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'routineIds': routineIds,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt.toIso8601String(),
        'durationWeeks': durationWeeks,
        'trainingWeekdays': trainingWeekdays.toList()..sort(),
        'deloadWeeks': deloadWeeks.toList()..sort(),
        'nextRotationIndex': nextRotationIndex,
        'isActive': isActive,
        'notes': notes,
        'completions': completions.map((item) => item.toJson()).toList(),
      };

  factory TrainingProgram.fromJson(Map<String, dynamic> json) {
    final rawCompletions = json['completions'];
    return TrainingProgram(
      id: json['id'] as String,
      name: json['name'] as String,
      routineIds: List<String>.from(json['routineIds'] as List? ?? const []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      durationWeeks: (json['durationWeeks'] as num?)?.toInt() ?? 8,
      trainingWeekdays: (json['trainingWeekdays'] as List? ?? const [])
          .map((value) => (value as num).toInt())
          .where((value) => value >= DateTime.monday && value <= DateTime.sunday)
          .toSet(),
      deloadWeeks: (json['deloadWeeks'] as List? ?? const [])
          .map((value) => (value as num).toInt())
          .where((value) => value > 0)
          .toSet(),
      nextRotationIndex: (json['nextRotationIndex'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
      completions: rawCompletions is List
          ? rawCompletions
              .whereType<Map>()
              .map((item) => ProgramCompletion.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const [],
    );
  }
}