import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/database/hive/models/hive_routine.dart';
import 'package:core/features/routines/application/routine_schedule_coordinator.dart';
import 'package:core/features/routines/data/routine_repository.dart';
import 'package:core/domain/models/routine.dart';

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  final box = Hive.box<HiveRoutine>(HiveBoxes.routines);
  return RoutineRepository(box);
});

final routineListProvider =
    NotifierProvider<RoutineListNotifier, List<Routine>>(RoutineListNotifier.new);

class RoutineListNotifier extends Notifier<List<Routine>> {
  @override
  List<Routine> build() {
    return ref.read(routineRepositoryProvider).getAllRoutines();
  }

  void addRoutine(Routine routine) async {
    await ref.read(routineRepositoryProvider).addRoutine(routine);
    state = ref.read(routineRepositoryProvider).getAllRoutines();
  }

  void updateRoutine(Routine routine) async {
    await ref.read(routineRepositoryProvider).updateRoutine(routine);
    state = ref.read(routineRepositoryProvider).getAllRoutines();
  }

  void updateRoutineNotes(String routineId, String notes) async {
    Routine? routine;
    for (final item in state) {
      if (item.id == routineId) {
        routine = item;
        break;
      }
    }
    if (routine == null) return;

    await ref.read(routineRepositoryProvider).updateRoutine(
          routine.copyWith(notes: notes),
          preserveExistingNotes: false,
        );
    state = ref.read(routineRepositoryProvider).getAllRoutines();
  }

  Future<bool> moveRoutineToDay({
    required String routineId,
    required int fromDay,
    required int toDay,
  }) async {
    Routine? routine;
    for (final item in state) {
      if (item.id == routineId) {
        routine = item;
        break;
      }
    }
    if (routine == null) return false;

    final updated = RoutineScheduleCoordinator.moveToDay(
      routine: routine,
      fromDay: fromDay,
      toDay: toDay,
    );
    if (identical(updated, routine)) return false;

    await ref.read(routineRepositoryProvider).updateRoutine(updated);
    state = ref.read(routineRepositoryProvider).getAllRoutines();
    return true;
  }

  void deleteRoutine(String id) async {
    await ref.read(routineRepositoryProvider).deleteRoutine(id);
    state = ref.read(routineRepositoryProvider).getAllRoutines();
  }

  void refresh() {
    state = ref.read(routineRepositoryProvider).getAllRoutines();
  }
}
