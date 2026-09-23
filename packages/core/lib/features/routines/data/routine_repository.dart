import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/database/hive/models/hive_routine.dart';

class RoutineRepository {
  final Box<HiveRoutine> _box;
  RoutineRepository(this._box);

  Future<void> addRoutine(Routine routine) async {
    await _box.put(routine.id, _toHive(routine));
  }

  Future<void> updateRoutine(
    Routine routine, {
    bool preserveExistingNotes = true,
  }) async {
    var value = routine;
    if (preserveExistingNotes && !routine.notesWereProvided) {
      final existing = _box.get(routine.id);
      if (existing != null) {
        value = routine.copyWith(notes: existing.notes);
      }
    }
    await _box.put(value.id, _toHive(value));
  }

  Future<void> deleteRoutine(String id) async {
    await _box.delete(id);
  }

  List<Routine> getAllRoutines() {
    return _box.values.map(_fromHive).toList();
  }

  HiveRoutine _toHive(Routine model) => HiveRoutine(
        id: model.id,
        name: model.name,
        scheduledDays: model.scheduledDays,
        createdAt: model.createdAt,
        notes: model.notes,
        exercises: model.exercises
            .map(
              (e) => HiveRoutineExercise(
                exerciseId: e.exerciseId,
                order: e.order,
                targetSets: e.targetSets,
                targetRepsMin: e.targetRepsMin,
                targetRepsMax: e.targetRepsMax,
                restSeconds: e.restSeconds,
                warmupSets: e.warmupSets,
                approachSets: e.approachSets,
                unilateral: e.unilateral,
                unilateralTarget: e.unilateralTarget.name,
                supersetGroupId: e.supersetGroupId,
              ),
            )
            .toList(),
      );

  Routine _fromHive(HiveRoutine h) => Routine(
        id: h.id,
        name: h.name,
        scheduledDays: h.scheduledDays,
        createdAt: h.createdAt,
        notes: h.notes,
        exercises: h.exercises
            .map(
              (e) => RoutineExercise(
                exerciseId: e.exerciseId,
                order: e.order,
                targetSets: e.targetSets,
                targetRepsMin: e.targetRepsMin,
                targetRepsMax: e.targetRepsMax,
                restSeconds: e.restSeconds,
                warmupSets: e.warmupSets,
                approachSets: e.approachSets,
                unilateral: e.unilateral,
                unilateralTarget: UnilateralTarget.values.firstWhere(
                  (target) => target.name == e.unilateralTarget,
                  orElse: () => UnilateralTarget.other,
                ),
                supersetGroupId: e.supersetGroupId,
              ),
            )
            .toList(),
      );
}
