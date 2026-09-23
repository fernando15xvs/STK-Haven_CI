import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/database/hive/models/hive_workout_session.dart';

class WorkoutRepository {
  final Box<HiveWorkoutSession> _box;

  WorkoutRepository(this._box);

  Future<void> saveWorkoutSession(WorkoutSession session) async {
    await _box.put(session.id, _toHive(session));
  }

  List<WorkoutSession> getAllSessions() {
    return _box.values.map(_fromHive).toList();
  }

  HiveWorkoutSession _toHive(WorkoutSession model) {
    return HiveWorkoutSession(
      id: model.id,
      routineId: model.routineId,
      routineNameSnapshot: model.routineNameSnapshot,
      startedAt: model.startedAt,
      finishedAt: model.finishedAt,
      durationSeconds: model.durationSeconds,
      notes: model.notes,
      currentRestEndsAt: model.currentRestEndsAt,
      exercises: model.exercises
          .map(
            (e) => HiveWorkoutExercise(
              exerciseId: e.exerciseId,
              exerciseNameSnapshot: e.exerciseNameSnapshot,
              muscleGroupSnapshot: e.muscleGroupSnapshot,
              notes: e.notes,
              unilateral: e.unilateral,
              unilateralTarget: e.unilateralTarget.name,
              supersetGroupId: e.supersetGroupId,
              sets: e.sets
                  .map(
                    (s) => HiveWorkoutSet(
                      weight: s.weight,
                      reps: s.reps,
                      completed: s.completed,
                      rir: s.rir,
                      warmup: s.warmup,
                      restSeconds: s.restSeconds,
                      setType: s.setType.name,
                      leftCompleted: s.leftCompleted,
                      rightCompleted: s.rightCompleted,
                      leftWeight: s.leftWeight,
                      leftReps: s.leftReps,
                      leftRir: s.leftRir,
                      rightWeight: s.rightWeight,
                      rightReps: s.rightReps,
                      rightRir: s.rightRir,
                      sideRestSeconds: s.sideRestSeconds,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  WorkoutSession _fromHive(HiveWorkoutSession h) {
    return WorkoutSession(
      id: h.id,
      routineId: h.routineId,
      routineNameSnapshot: h.routineNameSnapshot,
      startedAt: h.startedAt,
      finishedAt: h.finishedAt,
      durationSeconds: h.durationSeconds,
      notes: h.notes,
      currentRestEndsAt: h.currentRestEndsAt,
      exercises: h.exercises
          .map(
            (e) => WorkoutExercise(
              exerciseId: e.exerciseId,
              exerciseNameSnapshot: e.exerciseNameSnapshot,
              muscleGroupSnapshot: e.muscleGroupSnapshot,
              notes: e.notes,
              unilateral: e.unilateral,
              unilateralTarget: UnilateralTarget.values.firstWhere(
                (target) => target.name == e.unilateralTarget,
                orElse: () => UnilateralTarget.other,
              ),
              supersetGroupId: e.supersetGroupId,
              sets: e.sets
                  .map(
                    (s) => WorkoutSet(
                      weight: s.weight,
                      reps: s.reps,
                      completed: s.completed,
                      rir: s.rir,
                      setType: WorkoutSetType.values.firstWhere(
                        (type) => type.name == s.setType,
                        orElse: () => s.warmup
                            ? WorkoutSetType.warmup
                            : WorkoutSetType.working,
                      ),
                      restSeconds: s.restSeconds,
                      leftCompleted: s.leftCompleted,
                      rightCompleted: s.rightCompleted,
                      leftWeight: s.leftWeight,
                      leftReps: s.leftReps,
                      leftRir: s.leftRir,
                      rightWeight: s.rightWeight,
                      rightReps: s.rightReps,
                      rightRir: s.rightRir,
                      sideRestSeconds: s.sideRestSeconds,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }
}