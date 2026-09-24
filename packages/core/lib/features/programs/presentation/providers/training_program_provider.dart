import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:core/features/programs/data/training_program_repository.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

final trainingProgramRepositoryProvider = Provider<TrainingProgramRepository>(
  (ref) => TrainingProgramRepository(Hive.box(HiveBoxes.trainingPrograms)),
);

final trainingProgramListProvider =
    NotifierProvider<TrainingProgramListNotifier, List<TrainingProgram>>(
  TrainingProgramListNotifier.new,
);

class TrainingProgramListNotifier extends Notifier<List<TrainingProgram>> {
  TrainingProgramRepository get _repository =>
      ref.read(trainingProgramRepositoryProvider);

  @override
  List<TrainingProgram> build() {
    final metadata = Hive.box(HiveBoxes.metadata);
    final subscription = metadata
        .watch(key: TrainingProgramRepository.backupMetadataKey)
        .listen((_) {
      state = _repository.getAll();
    });
    ref.onDispose(() {
      subscription.cancel();
    });
    return _repository.getAll();
  }

  void refresh() => state = _repository.getAll();

  Future<TrainingProgram> create({
    required String name,
    required List<String> routineIds,
    int durationWeeks = 8,
    Set<int> trainingWeekdays = const {},
    Set<int> deloadWeeks = const {},
    String notes = '',
    bool activate = true,
  }) async {
    if (routineIds.isEmpty) {
      throw ArgumentError('Un programa necesita al menos una rutina.');
    }
    if (durationWeeks <= 0) {
      throw ArgumentError('durationWeeks debe ser mayor que cero.');
    }

    final now = DateTime.now();
    final program = TrainingProgram(
      id: const Uuid().v4(),
      name: name.trim().isEmpty ? 'Programa' : name.trim(),
      routineIds: List<String>.from(routineIds),
      createdAt: now,
      startedAt: now,
      durationWeeks: durationWeeks,
      trainingWeekdays: Set<int>.from(trainingWeekdays),
      deloadWeeks: Set<int>.from(deloadWeeks),
      notes: notes.trim(),
      isActive: activate,
    );

    if (activate) {
      for (final existing in _repository.getAll()) {
        if (existing.isActive) {
          await _repository.save(existing.copyWith(isActive: false));
        }
      }
    }
    await _repository.save(program);
    refresh();
    return program;
  }

  Future<void> save(TrainingProgram program) async {
    await _repository.save(program);
    refresh();
  }

  Future<void> activate(String programId) async {
    await _repository.activate(programId, startedAt: DateTime.now());
    refresh();
  }

  Future<void> delete(String programId) async {
    await _repository.delete(programId);
    refresh();
  }

  Future<TrainingProgram?> duplicate(String programId) async {
    final source = _repository.getById(programId);
    if (source == null) return null;
    final copy = source.duplicate(
      newId: const Uuid().v4(),
      newName: '${source.name} copia',
      now: DateTime.now(),
    );
    await _repository.save(copy);
    refresh();
    return copy;
  }

  /// Persists any completions that can be deterministically inferred from
  /// workout history. Safe to call repeatedly; completion IDs are idempotent.
  Future<TrainingProgram?> reconcileActive() async {
    final active = _repository.getActive();
    if (active == null) return null;
    final history = ref.read(workoutHistoryProvider);
    final reconciled = ProgramRotationCoordinator.reconcile(active, history);
    if (!_sameProgress(active, reconciled)) {
      await _repository.save(reconciled);
      refresh();
    }
    return reconciled;
  }

  bool _sameProgress(TrainingProgram a, TrainingProgram b) {
    return a.nextRotationIndex == b.nextRotationIndex &&
        a.completions.length == b.completions.length;
  }
}

final activeTrainingProgramProvider = Provider<TrainingProgram?>((ref) {
  final programs = ref.watch(trainingProgramListProvider);
  final active = programs.where((program) => program.isActive).toList();
  if (active.isEmpty) return null;
  active.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return active.first;
});

class NextProgramSession {
  final TrainingProgram program;
  final Routine routine;
  final int week;
  final bool isDeloadWeek;
  final bool isTrainingDay;
  final Set<int> trainingWeekdays;

  const NextProgramSession({
    required this.program,
    required this.routine,
    required this.week,
    required this.isDeloadWeek,
    required this.isTrainingDay,
    required this.trainingWeekdays,
  });
}

final nextProgramSessionProvider = Provider<NextProgramSession?>((ref) {
  final active = ref.watch(activeTrainingProgramProvider);
  if (active == null || active.routineIds.isEmpty) return null;

  final history = ref.watch(workoutHistoryProvider);
  final reconciled = ProgramRotationCoordinator.reconcile(active, history);
  final nextRoutineId = reconciled.nextRoutineId;
  if (nextRoutineId == null) return null;

  final routines = ref.watch(routineListProvider);
  Routine? routine;
  for (final candidate in routines) {
    if (candidate.id == nextRoutineId) {
      routine = candidate;
      break;
    }
  }
  if (routine == null) return null;

  final now = DateTime.now();
  final trainingWeekdays = ProgramScheduleProjector.effectiveTrainingWeekdays(
    reconciled,
    routines,
  );
  return NextProgramSession(
    program: reconciled,
    routine: routine,
    week: reconciled.weekAt(now),
    isDeloadWeek: reconciled.isDeloadWeekAt(now),
    isTrainingDay: ProgramScheduleProjector.isTrainingDay(
      reconciled,
      routines,
      now,
    ),
    trainingWeekdays: trainingWeekdays,
  );
});
