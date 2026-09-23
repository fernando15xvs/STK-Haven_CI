import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/preset_program.dart';
import 'package:core/domain/models/active_program_state.dart';
import 'package:core/features/routines/data/routine_repository.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/domain/models/settings_state.dart';

final programServiceProvider = Provider<ProgramService>((ref) {
  final routineRepo = ref.watch(routineRepositoryProvider);
  final settingsNotifier = ref.watch(settingsProvider.notifier);
  final routinesNotifier = ref.watch(routineListProvider.notifier);
  final exerciseNotifier = ref.watch(exerciseListProvider.notifier);
  return ProgramService(
    routineRepo,
    settingsNotifier,
    routinesNotifier,
    exerciseNotifier,
    () => ref.read(settingsProvider),
  );
});

class ProgramService {
  final RoutineRepository _routineRepository;
  final SettingsNotifier _settingsNotifier;
  final RoutineListNotifier _routineListNotifier;
  final ExerciseListNotifier _exerciseListNotifier;
  final SettingsState Function() _getSettingsState;

  bool _isInstalling = false;

  ProgramService(
    this._routineRepository,
    this._settingsNotifier,
    this._routineListNotifier,
    this._exerciseListNotifier,
    this._getSettingsState,
  );

  Future<void> installProgram(PresetProgram preset) async {
    if (_isInstalling) return;
    _isInstalling = true;

    try {
      await _exerciseListNotifier.ensureSeeded();

      const uuid = Uuid();
    final List<String> generatedIds = [];
    final now = DateTime.now();

    for (final presetRoutine in preset.routines) {
      final routineId = uuid.v4();
      generatedIds.add(routineId);

      final routine = Routine(
        id: routineId,
        name: presetRoutine.name,
        scheduledDays: presetRoutine.scheduledDays,
        createdAt: now,
        exercises: presetRoutine.exercises.asMap().entries.map((entry) {
          final index = entry.key;
          final ex = entry.value;
          return RoutineExercise(
            exerciseId: ex.exerciseId,
            order: index,
            targetSets: ex.targetSets,
            targetRepsMin: ex.targetRepsMin,
            targetRepsMax: ex.targetRepsMax,
            restSeconds: ex.restSeconds,
          );
        }).toList(),
      );

      await _routineRepository.addRoutine(routine);
    }
    
    // Refresh the routines list in the UI
    _routineListNotifier.refresh();

    // Guardar ActiveProgramState
    final activeProgram = ActiveProgramState(
      presetProgramId: preset.id,
      presetVersion: preset.version,
      programNameSnapshot: preset.name,
      startedAt: now,
      durationWeeks: preset.durationWeeks,
      generatedRoutineIds: generatedIds,
    );

    _settingsNotifier.updateSettings(
      _getSettingsState().copyWith(
        activeProgram: activeProgram,
        hasCompletedOnboarding: true,
      ),
    );
    } finally {
      _isInstalling = false;
    }
  }

  Future<void> completeOnboardingFromScratch() async {
    _settingsNotifier.updateSettings(
      _getSettingsState().copyWith(
        hasCompletedOnboarding: true,
        clearActiveProgram: true,
      ),
    );
  }

  Future<void> replaceProgram(PresetProgram newPreset, bool keepOldRoutines) async {
    final activeProgram = _getSettingsState().activeProgram;

    if (!keepOldRoutines && activeProgram != null) {
      for (final id in activeProgram.generatedRoutineIds) {
        await _routineRepository.deleteRoutine(id);
      }
      _routineListNotifier.refresh();
    }

    await installProgram(newPreset);
  }

  Future<void> removeActiveProgram({required bool keepGeneratedRoutines}) async {
    final activeProgram = _getSettingsState().activeProgram;
    if (activeProgram == null) return;

    if (!keepGeneratedRoutines) {
      for (final id in activeProgram.generatedRoutineIds) {
        await _routineRepository.deleteRoutine(id);
      }
      _routineListNotifier.refresh();
    }

    _settingsNotifier.updateSettings(
      _getSettingsState().copyWith(
        clearActiveProgram: true,
      ),
    );
  }
}
