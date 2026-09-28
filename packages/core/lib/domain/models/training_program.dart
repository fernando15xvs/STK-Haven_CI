enum ProgramScheduleMode {
  continuous,
  fixed,
  flexible,
}

extension ProgramScheduleModeX on ProgramScheduleMode {
  String get label => switch (this) {
        ProgramScheduleMode.continuous => 'Rotación continua',
        ProgramScheduleMode.fixed => 'Semana fija',
        ProgramScheduleMode.flexible => 'Flexible',
      };
}

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

  /// How this plan owns scheduling while active.
  ///
  /// Routine.scheduledDays remains an optional standalone schedule. It never
  /// overrides an explicit plan schedule.
  final ProgramScheduleMode scheduleMode;

  /// User goal, independent from which weekdays are selected.
  ///
  /// A value of 0 is accepted only for migrated legacy data; callers should use
  /// [effectiveTargetSessionsPerWeek] when displaying the frequency.
  final int targetSessionsPerWeek;

  /// Habitual opportunity days for continuous plans.
  final Set<int> trainingWeekdays;

  /// Plan-owned weekday -> routine mapping for fixed-week plans.
  final Map<int, String> fixedWeekdayRoutineIds;

  final Set<int> deloadWeeks;
  final int nextRotationIndex;
  final bool isActive;
  final bool isTemplate;
  final String notes;
  final List<ProgramCompletion> completions;

  const TrainingProgram({
    required this.id,
    required this.name,
    required this.routineIds,
    required this.createdAt,
    required this.startedAt,
    this.durationWeeks = 8,
    this.scheduleMode = ProgramScheduleMode.continuous,
    this.targetSessionsPerWeek = 0,
    this.trainingWeekdays = const <int>{},
    this.fixedWeekdayRoutineIds = const <int, String>{},
    this.deloadWeeks = const <int>{},
    this.nextRotationIndex = 0,
    this.isActive = true,
    this.isTemplate = false,
    this.notes = '',
    this.completions = const <ProgramCompletion>[],
  });

  bool get hasRoutines => routineIds.isNotEmpty;

  int get effectiveTargetSessionsPerWeek {
    if (targetSessionsPerWeek > 0) {
      return targetSessionsPerWeek.clamp(1, 7).toInt();
    }
    if (scheduleMode == ProgramScheduleMode.fixed &&
        fixedWeekdayRoutineIds.isNotEmpty) {
      return fixedWeekdayRoutineIds.length.clamp(1, 7).toInt();
    }
    if (trainingWeekdays.isNotEmpty) {
      return trainingWeekdays.length.clamp(1, 7).toInt();
    }
    if (routineIds.isNotEmpty) {
      return routineIds.length.clamp(1, 7).toInt();
    }
    return 0;
  }

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

    if (completions.any((item) => item.workoutSessionId == workoutSessionId)) {
      return this;
    }

    if (scheduleMode == ProgramScheduleMode.fixed) {
      final expectedRoutine =
          fixedWeekdayRoutineIds[completedAt.toLocal().weekday];
      if (expectedRoutine == null || routineId != expectedRoutine) {
        return this;
      }
      final index = routineIds.indexOf(routineId);
      return copyWith(
        completions: [
          ...completions,
          ProgramCompletion(
            workoutSessionId: workoutSessionId,
            routineId: routineId,
            completedAt: completedAt,
            rotationIndex: index < 0 ? 0 : index,
            programWeek: weekAt(completedAt),
          ),
        ],
      );
    }

    final expectedIndex = normalizedNextRotationIndex;
    final expectedRoutine = routineIds[expectedIndex];

    // A workout belonging to another routine may still exist in history, but
    // it must not silently advance continuous/flexible sequencing.
    if (routineId != expectedRoutine) return this;

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
      scheduleMode: scheduleMode,
      targetSessionsPerWeek: targetSessionsPerWeek,
      trainingWeekdays: Set<int>.from(trainingWeekdays),
      fixedWeekdayRoutineIds: Map<int, String>.from(fixedWeekdayRoutineIds),
      deloadWeeks: Set<int>.from(deloadWeeks),
      nextRotationIndex: 0,
      isActive: false,
      isTemplate: isTemplate,
      notes: notes,
      completions: const [],
    );
  }

  TrainingProgram toTemplate({
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
      scheduleMode: scheduleMode,
      targetSessionsPerWeek: targetSessionsPerWeek,
      trainingWeekdays: Set<int>.from(trainingWeekdays),
      fixedWeekdayRoutineIds: Map<int, String>.from(fixedWeekdayRoutineIds),
      deloadWeeks: Set<int>.from(deloadWeeks),
      nextRotationIndex: 0,
      isActive: false,
      isTemplate: true,
      notes: notes,
      completions: const <ProgramCompletion>[],
    );
  }

  TrainingProgram instantiateTemplate({
    required String newId,
    required String newName,
    required DateTime now,
  }) {
    if (!isTemplate) {
      throw StateError('Solo una plantilla puede instanciarse como programa.');
    }
    return TrainingProgram(
      id: newId,
      name: newName,
      routineIds: List<String>.from(routineIds),
      createdAt: now,
      startedAt: now,
      durationWeeks: durationWeeks,
      scheduleMode: scheduleMode,
      targetSessionsPerWeek: targetSessionsPerWeek,
      trainingWeekdays: Set<int>.from(trainingWeekdays),
      fixedWeekdayRoutineIds: Map<int, String>.from(fixedWeekdayRoutineIds),
      deloadWeeks: Set<int>.from(deloadWeeks),
      nextRotationIndex: 0,
      isActive: false,
      isTemplate: false,
      notes: notes,
      completions: const <ProgramCompletion>[],
    );
  }

  TrainingProgram copyWith({
    String? id,
    String? name,
    List<String>? routineIds,
    DateTime? createdAt,
    DateTime? startedAt,
    int? durationWeeks,
    ProgramScheduleMode? scheduleMode,
    int? targetSessionsPerWeek,
    Set<int>? trainingWeekdays,
    Map<int, String>? fixedWeekdayRoutineIds,
    Set<int>? deloadWeeks,
    int? nextRotationIndex,
    bool? isActive,
    bool? isTemplate,
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
      scheduleMode: scheduleMode ?? this.scheduleMode,
      targetSessionsPerWeek:
          targetSessionsPerWeek ?? this.targetSessionsPerWeek,
      trainingWeekdays: trainingWeekdays ?? this.trainingWeekdays,
      fixedWeekdayRoutineIds:
          fixedWeekdayRoutineIds ?? this.fixedWeekdayRoutineIds,
      deloadWeeks: deloadWeeks ?? this.deloadWeeks,
      nextRotationIndex: nextRotationIndex ?? this.nextRotationIndex,
      isActive: isActive ?? this.isActive,
      isTemplate: isTemplate ?? this.isTemplate,
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
        'scheduleMode': scheduleMode.name,
        'targetSessionsPerWeek': targetSessionsPerWeek,
        'trainingWeekdays': trainingWeekdays.toList()..sort(),
        'fixedWeekdayRoutineIds': {
          for (final entry in fixedWeekdayRoutineIds.entries)
            entry.key.toString(): entry.value,
        },
        'deloadWeeks': deloadWeeks.toList()..sort(),
        'nextRotationIndex': nextRotationIndex,
        'isActive': isActive,
        'isTemplate': isTemplate,
        'notes': notes,
        'completions': completions.map((item) => item.toJson()).toList(),
      };

  factory TrainingProgram.fromJson(Map<String, dynamic> json) {
    final rawCompletions = json['completions'];
    final trainingWeekdays =
        (json['trainingWeekdays'] as List? ?? const [])
            .map((value) => (value as num).toInt())
            .where(
              (value) =>
                  value >= DateTime.monday && value <= DateTime.sunday,
            )
            .toSet();

    final rawMode = json['scheduleMode']?.toString();
    final scheduleMode = ProgramScheduleMode.values.firstWhere(
      (value) => value.name == rawMode,
      orElse: () => ProgramScheduleMode.continuous,
    );

    final fixedWeekdayRoutineIds = <int, String>{};
    final rawFixed = json['fixedWeekdayRoutineIds'];
    if (rawFixed is Map) {
      for (final entry in rawFixed.entries) {
        final day = int.tryParse(entry.key.toString());
        final routineId = entry.value?.toString();
        if (day != null &&
            day >= DateTime.monday &&
            day <= DateTime.sunday &&
            routineId != null &&
            routineId.isNotEmpty) {
          fixedWeekdayRoutineIds[day] = routineId;
        }
      }
    }

    final storedTarget =
        (json['targetSessionsPerWeek'] as num?)?.toInt() ?? 0;
    final legacyTarget = storedTarget > 0
        ? storedTarget
        : scheduleMode == ProgramScheduleMode.fixed &&
                fixedWeekdayRoutineIds.isNotEmpty
            ? fixedWeekdayRoutineIds.length
            : trainingWeekdays.length;

    return TrainingProgram(
      id: json['id'] as String,
      name: json['name'] as String,
      routineIds: List<String>.from(json['routineIds'] as List? ?? const []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      durationWeeks: (json['durationWeeks'] as num?)?.toInt() ?? 8,
      scheduleMode: scheduleMode,
      targetSessionsPerWeek: legacyTarget.clamp(0, 7).toInt(),
      trainingWeekdays: trainingWeekdays,
      fixedWeekdayRoutineIds: fixedWeekdayRoutineIds,
      deloadWeeks: (json['deloadWeeks'] as List? ?? const [])
          .map((value) => (value as num).toInt())
          .where((value) => value > 0)
          .toSet(),
      nextRotationIndex: (json['nextRotationIndex'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      isTemplate: json['isTemplate'] as bool? ?? false,
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