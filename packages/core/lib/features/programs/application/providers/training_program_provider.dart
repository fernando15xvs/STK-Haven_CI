import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:core/features/programs/application/program_routine_order_policy.dart';
import 'package:core/features/programs/application/program_week_plan.dart';
import 'package:core/features/programs/application/program_adaptation_policy.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:core/features/programs/application/training_program_legacy_policy.dart';
import 'package:core/features/programs/data/training_program_repository.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/routines/application/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:hive/hive.dart';
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
    ProgramScheduleMode scheduleMode = ProgramScheduleMode.continuous,
    ProgramSequencePolicy sequencePolicy = ProgramSequencePolicy.rolling,
    List<String> weeklySequenceRoutineIds = const [],
    int targetSessionsPerWeek = 0,
    Set<int> trainingWeekdays = const {},
    Map<int, String> fixedWeekdayRoutineIds = const {},
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
      scheduleMode: scheduleMode,
      sequencePolicy: sequencePolicy,
      weeklySequenceRoutineIds: List<String>.unmodifiable(weeklySequenceRoutineIds),
      targetSessionsPerWeek: targetSessionsPerWeek.clamp(0, 7).toInt(),
      trainingWeekdays: Set<int>.from(trainingWeekdays),
      fixedWeekdayRoutineIds:
          Map<int, String>.from(fixedWeekdayRoutineIds),
      deloadWeeks: Set<int>.from(deloadWeeks),
      notes: notes.trim(),
      isActive: activate,
    );

    ProgramRoutineOrderPolicy.validateWeeklyConfiguration(program);
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
    final existing = _repository.getById(program.id);
    final updated = existing == null ? program : ProgramRoutineOrderPolicy.applyScheduleEdit(
      existing: ProgramRotationCoordinator.reconcile(existing, ref.read(workoutHistoryProvider)),
      edited: program, now: DateTime.now(), routines: ref.read(routineListProvider),
    );
    if (existing == null) ProgramRoutineOrderPolicy.validateWeeklyConfiguration(updated);
    await _repository.save(updated);
    refresh();
  }

  /// Upgrades the old onboarding-generated program once, using the frequency
  /// already stored in the user's personalization profile.
  ///
  /// The legacy note is the migration marker. Replacing it with a friendly
  /// sentence makes this idempotent and ensures later manual weekday edits are
  /// never overwritten.
  Future<void> personalizeLegacyOnboardingProgram({
    int? preferredDaysPerWeek,
  }) async {
    final active = _repository.getActive();
    if (active == null ||
        !active.notes.startsWith('Instalado desde onboarding ·')) {
      return;
    }

    final weekdays = preferredDaysPerWeek == null
        ? active.trainingWeekdays
        : ProgramScheduleProjector.recommendedTrainingWeekdays(
            preferredDaysPerWeek,
          );
    final friendlyName = active.name == 'Upper / Lower (4 Días)'
        ? 'Upper / Lower continuo'
        : active.name;

    await _repository.save(
      active.copyWith(
        name: friendlyName,
        scheduleMode: ProgramScheduleMode.continuous,
        targetSessionsPerWeek:
            preferredDaysPerWeek ?? active.effectiveTargetSessionsPerWeek,
        trainingWeekdays: weekdays,
        fixedWeekdayRoutineIds: const <int, String>{},
        notes: 'Programa recomendado según tu configuración inicial.',
      ),
    );

    final settings = ref.read(settingsProvider);
    final legacySnapshot = settings.activeProgram;
    if (legacySnapshot != null &&
        legacySnapshot.programNameSnapshot == 'Upper / Lower (4 Días)') {
      ref.read(settingsProvider.notifier).updateSettings(
            settings.copyWith(
              activeProgram: legacySnapshot.copyWith(
                programNameSnapshot: friendlyName,
              ),
            ),
          );
    }

    refresh();
  }

  Future<void> activate(String programId) async {
    await _repository.activate(programId, startedAt: DateTime.now());
    refresh();
  }

  Future<void> delete(String programId) async {
    final removed = _repository.getById(programId);
    await _repository.delete(programId);
    if (removed != null) {
      final settings = ref.read(settingsProvider);
      if (TrainingProgramLegacyPolicy.shouldClearLegacyOnDelete(
        deleted: removed,
        legacy: settings.activeProgram,
      )) {
        ref.read(settingsProvider.notifier).updateSettings(
          settings.copyWith(clearActiveProgram: true),
        );
      }
    }
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

  Future<TrainingProgram?> saveAsTemplate(String programId) async {
    final source = _repository.getById(programId);
    if (source == null) return null;
    final template = source.toTemplate(
      newId: const Uuid().v4(),
      newName: '${source.name} · plantilla',
      now: DateTime.now(),
    );
    await _repository.save(template);
    refresh();
    return template;
  }

  Future<TrainingProgram?> createFromTemplate(String templateId) async {
    final source = _repository.getById(templateId);
    if (source == null || !source.isTemplate) return null;
    final program = source.instantiateTemplate(
      newId: const Uuid().v4(),
      newName: source.name.replaceFirst(' · plantilla', ''),
      now: DateTime.now(),
    );
    await _repository.save(program);
    refresh();
    return program;
  }

  Future<void> pause(String programId) async {
    final program = _repository.getById(programId);
    if (program == null || program.isTemplate || !program.isActive) return;
    await _repository.save(program.copyWith(isActive: false));
    refresh();
  }

  Future<void> resume(String programId) async {
    final program = _repository.getById(programId);
    if (program == null || program.isTemplate || program.isActive) return;
    for (final existing in _repository.getAll()) {
      if (existing.isActive && existing.id != programId) {
        await _repository.save(existing.copyWith(isActive: false));
      }
    }
    await _repository.save(program.copyWith(isActive: true));
    refresh();
  }

  /// Apply an exception to the reconciled active plan and persist it before
  /// reporting success. UI selects the command, Core owns the transition.
  Future<TrainingProgram> adaptActive(TrainingProgram Function(
      TrainingProgram, List<Routine>, DateTime) command) async {
    final active = _repository.getActive();
    if (active == null) throw StateError('No hay programa activo.');
    final current = ProgramRotationCoordinator.reconcile(active, ref.read(workoutHistoryProvider));
    final updated = command(current, ref.read(routineListProvider), DateTime.now());
    if (updated.id != current.id) throw StateError('Programa incorrecto.');
    await _repository.save(updated);
    refresh();
    return updated;
  }

  /// Reserve a workout identity before starting its draft. Legacy plans keep
  /// their existing inference until an explicit adaptation is requested.
  Future<String?> bindWorkoutStart(String routineId, {String? occurrenceId,
      bool independent = false}) async {
    final active = _repository.getActive();
    if (active == null) return null;
    final id = const Uuid().v4();
    await adaptActive((p, routines, now) {
      final prepared = ProgramAdaptationPolicy.prepare(p, routines, now);
      final suggestion = ProgramAdaptationPolicy.nextOccurrence(prepared, routines, now);
      return ProgramAdaptationPolicy.bind(prepared, routines, id, routineId, now,
        slotId: occurrenceId,
        independent: independent || (occurrenceId == null &&
            (suggestion?.routineId != routineId ||
              (suggestion != null && (ProgramAdaptationPolicy.availableDate(prepared, routines,
                  suggestion, now)?.isAfter(ProgramAdaptationPolicy.day(now)) ?? true)))));
    });
    return id;
  }

  Future<void> releaseWorkoutBinding(String workoutId) async {
    for (final program in _repository.getAll()) {
      final state = program.adaptation;
      if (state == null || !state.bindings.containsKey(workoutId) ||
          program.completions.any((c) => c.workoutSessionId == workoutId)) continue;
      final bindings = Map<String,String>.from(state.bindings)..remove(workoutId);
      await _repository.save(program.copyWith(adaptation: state.copyWith(bindings: bindings)));
    }
    refresh();
  }

  /// Persists any completions that can be deterministically inferred from
  /// workout history. Safe to call repeatedly; completion IDs are idempotent.
  Future<TrainingProgram?> reconcileActive() async {
    final active = _repository.getActive();
    if (active == null) return null;
    final history = ref.read(workoutHistoryProvider);
    final reconciled = ProgramAdaptationPolicy.prepare(
      ProgramRotationCoordinator.reconcile(active, history), ref.read(routineListProvider), DateTime.now());
    if (!_sameProgress(active, reconciled)) {
      await _repository.save(reconciled);
      refresh();
    }
    return reconciled;
  }

  bool _sameProgress(TrainingProgram a, TrainingProgram b) {
    return a.nextRotationIndex == b.nextRotationIndex &&
        a.completions.length == b.completions.length &&
        identical(a.adaptation, b.adaptation);
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
  final DateTime? scheduledDate;
  final int targetSessionsPerWeek;
  final String? occurrenceId;

  const NextProgramSession({
    required this.program,
    required this.routine,
    required this.week,
    required this.isDeloadWeek,
    required this.isTrainingDay,
    required this.trainingWeekdays,
    required this.scheduledDate,
    required this.targetSessionsPerWeek,
    this.occurrenceId,
  });
}

/// Invalidated by Mobile at local midnight and on foreground resume.
final trainingDayClockProvider = Provider<DateTime>((ref) => DateTime.now());

final nextProgramSessionProvider = Provider<NextProgramSession?>((ref) {
  final active = ref.watch(activeTrainingProgramProvider);
  if (active == null || active.routineIds.isEmpty) return null;

  final history = ref.watch(workoutHistoryProvider);
  final reconciled = ProgramRotationCoordinator.reconcile(active, history);
  final routines = ref.watch(routineListProvider);
  final now = ref.watch(trainingDayClockProvider).toLocal();
  final prepared = ProgramAdaptationPolicy.prepare(reconciled, routines, now);
  final plan = ProgramWeekPlan.calculate(program: prepared, routines: routines, now: now);
  final nextRoutineId = plan.nextSuggestion?.routineId;
  final scheduledDate = plan.nextSuggestion?.date;
  if (nextRoutineId == null) return null;

  Routine? routine;
  for (final candidate in routines) {
    if (candidate.id == nextRoutineId) {
      routine = candidate;
      break;
    }
  }
  if (routine == null) return null;

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
    scheduledDate: scheduledDate,
    occurrenceId: plan.nextSuggestion?.occurrenceId,
    targetSessionsPerWeek:
        ProgramScheduleProjector.effectiveTargetSessionsPerWeek(
      reconciled,
      routines,
    ),
  );
});
