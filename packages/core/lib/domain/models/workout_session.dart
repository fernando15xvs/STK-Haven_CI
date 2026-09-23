import 'package:core/domain/models/routine.dart';

enum WorkoutSetType {
  warmup,
  approach,
  working,
}

enum WorkoutSide { left, right }

extension WorkoutSideX on WorkoutSide {
  String get label => switch (this) {
        WorkoutSide.left => 'Izquierda',
        WorkoutSide.right => 'Derecha',
      };

  String get shortLabel => switch (this) {
        WorkoutSide.left => 'I',
        WorkoutSide.right => 'D',
      };
}

extension WorkoutSetTypeX on WorkoutSetType {
  String get label => switch (this) {
        WorkoutSetType.warmup => 'Calentamiento',
        WorkoutSetType.approach => 'Aproximación',
        WorkoutSetType.working => 'Trabajo',
      };

  String get shortLabel => switch (this) {
        WorkoutSetType.warmup => 'C',
        WorkoutSetType.approach => 'A',
        WorkoutSetType.working => 'T',
      };
}

class WorkoutSet {
  final double weight;
  final int reps;
  final bool completed;
  final int? rir;
  final WorkoutSetType setType;
  final int restSeconds; // fuente de verdad para el timer de descanso
  final bool leftCompleted;
  final bool rightCompleted;

  /// Datos específicos por lado para ejercicios unilaterales.
  ///
  /// Son opcionales para preservar compatibilidad con sesiones históricas.
  /// Cuando un lado no tiene datos detallados, los consumidores usan
  /// [weight], [reps] y [rir] como fallback del registro antiguo/compartido.
  final double? leftWeight;
  final int? leftReps;
  final int? leftRir;
  final double? rightWeight;
  final int? rightReps;
  final int? rightRir;

  /// Descanso entre un lado y el otro. Es independiente de [restSeconds], que
  /// continúa representando el descanso posterior a completar toda la serie.
  final int sideRestSeconds;

  const WorkoutSet({
    required this.weight,
    required this.reps,
    required this.completed,
    this.rir,
    WorkoutSetType setType = WorkoutSetType.working,
    bool warmup = false,
    this.restSeconds = 90,
    this.leftCompleted = false,
    this.rightCompleted = false,
    this.leftWeight,
    this.leftReps,
    this.leftRir,
    this.rightWeight,
    this.rightReps,
    this.rightRir,
    this.sideRestSeconds = 60,
  }) : setType = warmup ? WorkoutSetType.warmup : setType;

  /// Compatibilidad con los cálculos existentes: calentamiento y aproximación
  /// no cuentan como series efectivas de trabajo.
  bool get warmup => setType != WorkoutSetType.working;

  bool get hasLeftSideData =>
      leftWeight != null || leftReps != null || leftRir != null;
  bool get hasRightSideData =>
      rightWeight != null || rightReps != null || rightRir != null;
  bool get hasDetailedSideData => hasLeftSideData || hasRightSideData;

  double weightForSide(WorkoutSide side) => switch (side) {
        WorkoutSide.left => hasLeftSideData ? (leftWeight ?? weight) : weight,
        WorkoutSide.right =>
          hasRightSideData ? (rightWeight ?? weight) : weight,
      };

  int repsForSide(WorkoutSide side) => switch (side) {
        WorkoutSide.left => hasLeftSideData ? (leftReps ?? reps) : reps,
        WorkoutSide.right => hasRightSideData ? (rightReps ?? reps) : reps,
      };

  int? rirForSide(WorkoutSide side) => switch (side) {
        WorkoutSide.left => hasLeftSideData ? leftRir : rir,
        WorkoutSide.right => hasRightSideData ? rightRir : rir,
      };

  bool completedForSide(WorkoutSide side) => switch (side) {
        WorkoutSide.left => leftCompleted,
        WorkoutSide.right => rightCompleted,
      };

  /// Valor conservador usado por la progresión mientras Progreso 2.0 expone
  /// ambos lados por separado. Para unilateral detallado representa el lado
  /// limitante; para registros normales/antiguos conserva los campos clásicos.
  double get performanceWeight {
    if (!hasDetailedSideData) return weight;
    final values = <double>[
      if (leftCompleted) weightForSide(WorkoutSide.left),
      if (rightCompleted) weightForSide(WorkoutSide.right),
    ].where((value) => value > 0).toList(growable: false);
    if (values.isEmpty) return weight;
    return values.reduce((a, b) => a < b ? a : b);
  }

  int get performanceReps {
    if (!hasDetailedSideData) return reps;
    final values = <int>[
      if (leftCompleted) repsForSide(WorkoutSide.left),
      if (rightCompleted) repsForSide(WorkoutSide.right),
    ].where((value) => value > 0).toList(growable: false);
    if (values.isEmpty) return reps;
    return values.reduce((a, b) => a < b ? a : b);
  }

  int? get performanceRir {
    if (!hasDetailedSideData) return rir;

    // When RIR is enabled, both completed sides must carry their own evidence.
    // Missing RIR on one side must never be hidden by the other side's value.
    if (leftCompleted && rirForSide(WorkoutSide.left) == null) return null;
    if (rightCompleted && rirForSide(WorkoutSide.right) == null) return null;

    final values = <int>[
      if (leftCompleted && rirForSide(WorkoutSide.left) != null)
        rirForSide(WorkoutSide.left)!,
      if (rightCompleted && rirForSide(WorkoutSide.right) != null)
        rirForSide(WorkoutSide.right)!,
    ];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a < b ? a : b);
  }

  /// Raw sum of the work recorded on both sides. This is preserved for future
  /// per-side analytics/export, but it is not used as the legacy-comparable
  /// dashboard volume because old unilateral sessions stored only one shared
  /// value per set.
  double get combinedSideVolume {
    if (!hasDetailedSideData) return weight * reps;
    var total = 0.0;
    if (leftCompleted) {
      total += weightForSide(WorkoutSide.left) * repsForSide(WorkoutSide.left);
    }
    if (rightCompleted) {
      total += weightForSide(WorkoutSide.right) * repsForSide(WorkoutSide.right);
    }
    return total;
  }

  /// Normalized per-set volume used by existing historical charts and PRs.
  /// Detailed unilateral work is averaged across completed sides so enabling
  /// Unilateral Pro does not create an artificial ~2x jump versus legacy data.
  double get performedVolume {
    if (!hasDetailedSideData) return weight * reps;
    var sideCount = 0;
    if (leftCompleted) sideCount++;
    if (rightCompleted) sideCount++;
    if (sideCount == 0) return 0;
    return combinedSideVolume / sideCount;
  }

  double get maxPerformedWeight {
    if (!hasDetailedSideData) return weight;
    final left = leftCompleted ? weightForSide(WorkoutSide.left) : 0.0;
    final right = rightCompleted ? weightForSide(WorkoutSide.right) : 0.0;
    return left > right ? left : right;
  }

  WorkoutSet copyWith({
    double? weight,
    int? reps,
    bool? completed,
    int? rir,
    WorkoutSetType? setType,
    int? restSeconds,
    bool? leftCompleted,
    bool? rightCompleted,
    double? leftWeight,
    int? leftReps,
    int? leftRir,
    double? rightWeight,
    int? rightReps,
    int? rightRir,
    int? sideRestSeconds,
    bool clearRir = false,
    bool clearLeftRir = false,
    bool clearRightRir = false,
    bool clearLeftPerformance = false,
    bool clearRightPerformance = false,
  }) {
    return WorkoutSet(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      completed: completed ?? this.completed,
      rir: clearRir ? null : (rir ?? this.rir),
      setType: setType ?? this.setType,
      restSeconds: restSeconds ?? this.restSeconds,
      leftCompleted: leftCompleted ?? this.leftCompleted,
      rightCompleted: rightCompleted ?? this.rightCompleted,
      leftWeight:
          clearLeftPerformance ? null : (leftWeight ?? this.leftWeight),
      leftReps: clearLeftPerformance ? null : (leftReps ?? this.leftReps),
      leftRir: clearLeftPerformance || clearLeftRir
          ? null
          : (leftRir ?? this.leftRir),
      rightWeight:
          clearRightPerformance ? null : (rightWeight ?? this.rightWeight),
      rightReps:
          clearRightPerformance ? null : (rightReps ?? this.rightReps),
      rightRir: clearRightPerformance || clearRightRir
          ? null
          : (rightRir ?? this.rightRir),
      sideRestSeconds: sideRestSeconds ?? this.sideRestSeconds,
    );
  }
}

class WorkoutExercise {
  final String exerciseId;
  final String exerciseNameSnapshot;
  final String muscleGroupSnapshot;
  final List<WorkoutSet> sets;
  final String notes;
  final bool unilateral;
  final UnilateralTarget unilateralTarget;

  /// Identificador compartido por exactamente dos ejercicios cuando forman
  /// una superserie durante la sesión. `null` significa ejercicio individual.
  final String? supersetGroupId;

  const WorkoutExercise({
    required this.exerciseId,
    required this.exerciseNameSnapshot,
    required this.muscleGroupSnapshot,
    required this.sets,
    this.notes = '',
    this.unilateral = false,
    this.unilateralTarget = UnilateralTarget.other,
    this.supersetGroupId,
  });

  bool get completed => sets.isNotEmpty && sets.every((set) => set.completed);
  bool get isInSuperset => supersetGroupId != null;

  WorkoutExercise copyWith({
    String? exerciseId,
    String? exerciseNameSnapshot,
    String? muscleGroupSnapshot,
    List<WorkoutSet>? sets,
    String? notes,
    bool? unilateral,
    UnilateralTarget? unilateralTarget,
    String? supersetGroupId,
    bool clearSupersetGroup = false,
  }) {
    return WorkoutExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseNameSnapshot:
          exerciseNameSnapshot ?? this.exerciseNameSnapshot,
      muscleGroupSnapshot: muscleGroupSnapshot ?? this.muscleGroupSnapshot,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
      unilateral: unilateral ?? this.unilateral,
      unilateralTarget: unilateralTarget ?? this.unilateralTarget,
      supersetGroupId:
          clearSupersetGroup ? null : (supersetGroupId ?? this.supersetGroupId),
    );
  }
}

class WorkoutSession {
  final String id;
  final String? routineId;
  final String routineNameSnapshot;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<WorkoutExercise> exercises;
  final int durationSeconds;
  final String notes;
  final DateTime? currentRestEndsAt;

  const WorkoutSession({
    required this.id,
    this.routineId,
    required this.routineNameSnapshot,
    required this.startedAt,
    required this.finishedAt,
    required this.exercises,
    required this.durationSeconds,
    this.notes = '',
    this.currentRestEndsAt,
  });
}
