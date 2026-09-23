import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';

/// Persiste el borrador del entrenamiento activo mientras está en progreso.
/// Usa startedAt para recalcular la duración sin escribir cada segundo.
///
/// Todas las escrituras se serializan para preservar el orden. Así, un
/// saveDraft iniciado antes de clearDraft nunca puede terminar después y
/// recrear accidentalmente un entrenamiento que ya fue finalizado/cancelado.
class ActiveWorkoutRepository {
  final Box _box;

  ActiveWorkoutRepository(this._box);

  static const String _key = 'draft';
  Future<void> _operationQueue = Future<void>.value();

  Future<void> saveDraft(WorkoutSession session) {
    final payload = _encode(session);
    return _enqueue(() => _box.put(_key, payload));
  }

  Future<void> clearDraft() {
    return _enqueue(() => _box.delete(_key));
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final current = _operationQueue.then((_) => operation());
    _operationQueue = current.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return current;
  }

  WorkoutSession? getDraft() {
    final raw = _box.get(_key);
    if (raw == null) return null;
    return _decode(raw as Map);
  }

  bool get hasDraft => _box.containsKey(_key);

  Map<String, dynamic> _encode(WorkoutSession session) => {
        'id': session.id,
        'routineId': session.routineId,
        'routineNameSnapshot': session.routineNameSnapshot,
        'startedAt': session.startedAt.toIso8601String(),
        'currentRestEndsAt': session.currentRestEndsAt?.toIso8601String(),
        'exercises': session.exercises
            .map(
              (exercise) => {
                'exerciseId': exercise.exerciseId,
                'exerciseNameSnapshot': exercise.exerciseNameSnapshot,
                'muscleGroupSnapshot': exercise.muscleGroupSnapshot,
                'notes': exercise.notes,
                'unilateral': exercise.unilateral,
                'unilateralTarget': exercise.unilateralTarget.name,
                'supersetGroupId': exercise.supersetGroupId,
                'sets': exercise.sets
                    .map(
                      (set) => {
                        'weight': set.weight,
                        'reps': set.reps,
                        'completed': set.completed,
                        'rir': set.rir,
                        'warmup': set.warmup,
                        'setType': set.setType.name,
                        'restSeconds': set.restSeconds,
                        'leftCompleted': set.leftCompleted,
                        'rightCompleted': set.rightCompleted,
                        'leftWeight': set.leftWeight,
                        'leftReps': set.leftReps,
                        'leftRir': set.leftRir,
                        'rightWeight': set.rightWeight,
                        'rightReps': set.rightReps,
                        'rightRir': set.rightRir,
                        'sideRestSeconds': set.sideRestSeconds,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      };

  WorkoutSession _decode(Map raw) {
    final exercises = (raw['exercises'] as List).map((exercise) {
      final sets = (exercise['sets'] as List)
          .map((set) {
            final legacyWarmup = set['warmup'] as bool? ?? false;
            return WorkoutSet(
              weight: (set['weight'] as num).toDouble(),
              reps: set['reps'] as int,
              completed: set['completed'] as bool,
              rir: set['rir'] as int?,
              setType: WorkoutSetType.values.firstWhere(
                (type) => type.name == set['setType'],
                orElse: () => legacyWarmup
                    ? WorkoutSetType.warmup
                    : WorkoutSetType.working,
              ),
              restSeconds: set['restSeconds'] as int? ?? 0,
              leftCompleted: set['leftCompleted'] as bool? ?? false,
              rightCompleted: set['rightCompleted'] as bool? ?? false,
              leftWeight: (set['leftWeight'] as num?)?.toDouble(),
              leftReps: set['leftReps'] as int?,
              leftRir: set['leftRir'] as int?,
              rightWeight: (set['rightWeight'] as num?)?.toDouble(),
              rightReps: set['rightReps'] as int?,
              rightRir: set['rightRir'] as int?,
              sideRestSeconds: set['sideRestSeconds'] as int? ?? 60,
            );
          })
          .toList();

      return WorkoutExercise(
        exerciseId: exercise['exerciseId'] as String,
        exerciseNameSnapshot:
            exercise['exerciseNameSnapshot'] as String? ?? '',
        muscleGroupSnapshot:
            exercise['muscleGroupSnapshot'] as String? ?? '',
        notes: exercise['notes'] as String? ?? '',
        unilateral: exercise['unilateral'] as bool? ?? false,
        unilateralTarget: UnilateralTarget.values.firstWhere(
          (target) => target.name == exercise['unilateralTarget'],
          orElse: () => UnilateralTarget.other,
        ),
        supersetGroupId: exercise['supersetGroupId'] as String?,
        sets: sets,
      );
    }).toList();

    return WorkoutSession(
      id: raw['id'] as String,
      routineId: raw['routineId'] as String?,
      routineNameSnapshot: raw['routineNameSnapshot'] as String? ?? '',
      startedAt: DateTime.parse(raw['startedAt'] as String),
      finishedAt: DateTime.now(),
      exercises: exercises,
      durationSeconds: 0,
      currentRestEndsAt: raw['currentRestEndsAt'] != null
          ? DateTime.parse(raw['currentRestEndsAt'] as String)
          : null,
    );
  }
}
