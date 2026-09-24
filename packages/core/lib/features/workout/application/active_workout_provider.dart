import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/workout/data/active_workout_repository.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/application/workout_history_index.dart';
import 'package:core/features/workout/application/workout_analysis_service.dart';
import 'package:core/features/workout/application/superset_coordinator.dart';
import 'package:core/features/workout/application/unilateral_set_coordinator.dart';
import 'package:core/features/workout/application/exercise_memory_actions.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';
import 'package:core/domain/models/workout_analysis.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/core/services/workout_notification_service.dart';
import 'package:core/features/coach/application/coach_progress_provider.dart';
import 'package:core/features/profile/application/gamification_provider.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';

sealed class FinishWorkoutResult {}

class WorkoutFinished extends FinishWorkoutResult {
  final WorkoutAnalysisResult analysis;
  WorkoutFinished(this.analysis);
}

class EmptyWorkout extends FinishWorkoutResult {}

final activeWorkoutRepositoryProvider = Provider<ActiveWorkoutRepository>((ref) {
  final box = Hive.box(HiveBoxes.activeWorkout);
  return ActiveWorkoutRepository(box);
});

class ActiveWorkoutState {
  final WorkoutSession? session;
  final int globalTimerSeconds;
  final int restTimerSeconds;
  final bool isResting;
  final bool canUndo;

  const ActiveWorkoutState({
    this.session,
    this.globalTimerSeconds = 0,
    this.restTimerSeconds = 0,
    this.isResting = false,
    this.canUndo = false,
  });

  bool get isActive => session != null;

  String get routineDisplayName =>
      session?.routineNameSnapshot ?? 'Entrenamiento libre';

  ActiveWorkoutState copyWith({
    WorkoutSession? session,
    int? globalTimerSeconds,
    int? restTimerSeconds,
    bool? isResting,
    bool? canUndo,
  }) {
    return ActiveWorkoutState(
      session: session ?? this.session,
      globalTimerSeconds: globalTimerSeconds ?? this.globalTimerSeconds,
      restTimerSeconds: restTimerSeconds ?? this.restTimerSeconds,
      isResting: isResting ?? this.isResting,
      canUndo: canUndo ?? this.canUndo,
    );
  }
}

/// Elapsed workout time is always derived from the persisted start timestamp;
/// it does not depend on counting timer ticks while the app is foregrounded.
final workoutTimerProvider = StreamProvider.autoDispose<int>((ref) {
  final session = ref.watch(activeWorkoutProvider.select((s) => s.session));
  if (session == null) return Stream.value(0);

  final start = session.startedAt;
  return Stream.periodic(const Duration(seconds: 1), (_) {
    return DateTime.now().difference(start).inSeconds;
  });
});

final activeWorkoutProvider =
    NotifierProvider<ActiveWorkoutNotifier, ActiveWorkoutState>(
  ActiveWorkoutNotifier.new,
);

class ActiveWorkoutNotifier extends Notifier<ActiveWorkoutState> {
  Timer? _restTimer;
  WorkoutSession? _undoSession;

  @override
  ActiveWorkoutState build() {
    ref.onDispose(_cancelTimers);
    final draft = ref.read(activeWorkoutRepositoryProvider).getDraft();
    if (draft != null) {
      final elapsed = DateTime.now().difference(draft.startedAt).inSeconds;

      int remainingRest = 0;
      bool resting = false;
      if (draft.currentRestEndsAt != null) {
        remainingRest =
            draft.currentRestEndsAt!.difference(DateTime.now()).inSeconds;
        if (remainingRest > 0) {
          resting = true;
          Future.microtask(
            () => _startRestTimer(remainingRest, draft.currentRestEndsAt!),
          );
        } else {
          _clearRestInDraft(draft);
        }
      }

      return ActiveWorkoutState(
        session: draft,
        globalTimerSeconds: elapsed,
        restTimerSeconds: remainingRest,
        isResting: resting,
      );
    }
    return const ActiveWorkoutState();
  }

  void _clearRestInDraft(WorkoutSession draft) {
    final updated = WorkoutSession(
      id: draft.id,
      routineId: draft.routineId,
      routineNameSnapshot: draft.routineNameSnapshot,
      startedAt: draft.startedAt,
      finishedAt: draft.finishedAt,
      durationSeconds: draft.durationSeconds,
      exercises: draft.exercises,
      notes: draft.notes,
      currentRestEndsAt: null,
    );
    ref.read(activeWorkoutRepositoryProvider).saveDraft(updated);
  }

  /// Starts a routine while preserving routine-specific set structure/rest.
  /// Exercise Memory prefill is optional and only copies performance values.
  void startWorkout(
    Routine routine,
    List<Exercise> allExercises, {
    bool? prefillFromExerciseMemory,
  }) {
    _cancelTimers();
    _undoSession = null;
    final settings = ref.read(settingsProvider);
    final configuredSideRest = settings.unilateralSideRestSeconds;

    var exercises = routine.exercises.map((re) {
      final ex = allExercises.firstWhere(
        (e) => e.id == re.exerciseId,
        orElse: () => Exercise(
          id: re.exerciseId,
          name: 'Ejercicio eliminado',
          muscleGroup: '',
        ),
      );

      final sets = <WorkoutSet>[
        ...List.generate(
          re.warmupSets,
          (_) => WorkoutSet(
            weight: 0,
            reps: 0,
            completed: false,
            setType: WorkoutSetType.warmup,
            restSeconds: re.restSeconds,
            sideRestSeconds: configuredSideRest,
          ),
        ),
        ...List.generate(
          re.approachSets,
          (_) => WorkoutSet(
            weight: 0,
            reps: 0,
            completed: false,
            setType: WorkoutSetType.approach,
            restSeconds: re.restSeconds,
            sideRestSeconds: configuredSideRest,
          ),
        ),
        ...List.generate(
          re.targetSets,
          (_) => WorkoutSet(
            weight: 0,
            reps: 0,
            completed: false,
            setType: WorkoutSetType.working,
            restSeconds: re.restSeconds,
            sideRestSeconds: configuredSideRest,
          ),
        ),
      ];

      return WorkoutExercise(
        exerciseId: re.exerciseId,
        exerciseNameSnapshot: ex.name,
        muscleGroupSnapshot: ex.muscleGroup,
        unilateral: re.unilateral,
        unilateralTarget: re.unilateralTarget,
        supersetGroupId: re.supersetGroupId,
        sets: sets,
      );
    }).toList(growable: false);

    var session = WorkoutSession(
      id: const Uuid().v4(),
      routineId: routine.id,
      routineNameSnapshot: routine.name,
      startedAt: DateTime.now(),
      finishedAt: DateTime.now(),
      durationSeconds: 0,
      exercises: exercises,
    );

    final shouldPrefill =
        prefillFromExerciseMemory ?? settings.prefillExerciseMemoryByDefault;
    if (shouldPrefill) {
      final index = ref.read(workoutHistoryIndexProvider);
      final previous =
          ExercisePerformanceMemory.syntheticPreviousSessionForCurrentInIndex(
        index,
        session,
      );
      if (previous != null) {
        exercises = session.exercises.map((currentExercise) {
          WorkoutExercise? aligned;
          for (final candidate in previous.exercises) {
            if (candidate.exerciseId == currentExercise.exerciseId) {
              aligned = candidate;
              break;
            }
          }
          if (aligned == null) return currentExercise;
          return ExerciseMemoryActions.applyPreviousExercise(
            current: currentExercise,
            previousAligned: aligned,
          );
        }).toList(growable: false);
        session = WorkoutSession(
          id: session.id,
          routineId: session.routineId,
          routineNameSnapshot: session.routineNameSnapshot,
          startedAt: session.startedAt,
          finishedAt: session.finishedAt,
          durationSeconds: session.durationSeconds,
          exercises: exercises,
          notes: session.notes,
          currentRestEndsAt: session.currentRestEndsAt,
        );
      }
    }

    state = ActiveWorkoutState(session: session);
    _persistDraft();
  }

  WorkoutExercise _withSets(WorkoutExercise exercise, List<WorkoutSet> sets) {
    return exercise.copyWith(sets: sets);
  }

  void _captureUndo() {
    final session = state.session;
    if (session == null) return;
    _undoSession = session;
    state = state.copyWith(canUndo: true);
  }

  bool undoLastAction() {
    final previous = _undoSession;
    if (previous == null) return false;

    _restTimer?.cancel();
    WorkoutNotificationService.cancelRestTimerNotification();
    _undoSession = null;

    final now = DateTime.now();
    final remaining = previous.currentRestEndsAt == null
        ? 0
        : previous.currentRestEndsAt!.difference(now).inSeconds;
    final resting = remaining > 0;
    state = ActiveWorkoutState(
      session: previous,
      globalTimerSeconds: now.difference(previous.startedAt).inSeconds,
      restTimerSeconds: resting ? remaining : 0,
      isResting: resting,
      canUndo: false,
    );
    _persistDraft();
    if (resting) {
      _startRestTimer(remaining, previous.currentRestEndsAt!);
    }
    return true;
  }

  void updateSet(int exerciseIndex, int setIndex, WorkoutSet updatedSet) {
    if (state.session == null) return;
    _captureUndo();
    _updateSetInternal(exerciseIndex, setIndex, updatedSet);
  }

  void _updateSetInternal(
    int exerciseIndex,
    int setIndex,
    WorkoutSet updatedSet,
  ) {
    if (state.session == null) return;
    final exercises = List<WorkoutExercise>.from(state.session!.exercises);
    if (exerciseIndex < 0 || exerciseIndex >= exercises.length) return;
    final sets = List<WorkoutSet>.from(exercises[exerciseIndex].sets);
    if (setIndex < 0 || setIndex >= sets.length) return;

    final wasCompleted = sets[setIndex].completed;
    sets[setIndex] = updatedSet;
    exercises[exerciseIndex] = _withSets(exercises[exerciseIndex], sets);

    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();

    if (!wasCompleted && updatedSet.completed && updatedSet.restSeconds > 0) {
      final decision = SupersetCoordinator.restDecision(
        exercises: exercises,
        exerciseIndex: exerciseIndex,
        setIndex: setIndex,
      );
      if (decision.shouldStartRest && decision.restSeconds > 0) {
        _maybeStartRest(decision.restSeconds, exercises);
      }
    }
  }

  bool applyPreviousExercise(
    int exerciseIndex,
    WorkoutExercise previousAligned,
  ) {
    if (state.session == null ||
        exerciseIndex < 0 ||
        exerciseIndex >= state.session!.exercises.length) {
      return false;
    }
    final current = state.session!.exercises[exerciseIndex];
    if (current.exerciseId != previousAligned.exerciseId) return false;

    final updated = ExerciseMemoryActions.applyPreviousExercise(
      current: current,
      previousAligned: previousAligned,
    );
    _captureUndo();
    final exercises = List<WorkoutExercise>.from(state.session!.exercises);
    exercises[exerciseIndex] = updated;
    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();
    return true;
  }

  bool copyPreviousSet(int exerciseIndex, int setIndex) {
    if (state.session == null ||
        exerciseIndex < 0 ||
        exerciseIndex >= state.session!.exercises.length) {
      return false;
    }
    final current = state.session!.exercises[exerciseIndex];
    final updated = ExerciseMemoryActions.copyPreviousSet(
      current: current,
      setIndex: setIndex,
    );
    if (identical(updated, current)) return false;

    _captureUndo();
    final exercises = List<WorkoutExercise>.from(state.session!.exercises);
    exercises[exerciseIndex] = updated;
    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();
    return true;
  }

  /// Snapshots the current shared inputs into the selected unilateral side.
  /// When same-weight mode is enabled, the second side inherits the first
  /// side's actual load while reps/RIR may still differ.
  void toggleUnilateralSide(
    int exerciseIndex,
    int setIndex, {
    required bool left,
  }) {
    if (state.session == null) return;
    final exercise = state.session!.exercises[exerciseIndex];
    if (!exercise.unilateral) return;

    final current = exercise.sets[setIndex];
    final settings = ref.read(settingsProvider);
    final result = UnilateralSetCoordinator.toggleSide(
      current,
      left ? WorkoutSide.left : WorkoutSide.right,
      sameWeightForBothSides: settings.unilateralSameWeightByDefault,
    );

    _captureUndo();
    _updateSetInternal(exerciseIndex, setIndex, result.set);

    if (result.shouldStartInterSideRest) {
      final updatedExercises = state.session?.exercises;
      if (updatedExercises != null) {
        _maybeStartRest(result.set.sideRestSeconds, updatedExercises);
      }
    }
  }

  WorkoutSide? recommendedUnilateralFirstSide(int exerciseIndex, int setIndex) {
    if (state.session == null ||
        exerciseIndex < 0 ||
        exerciseIndex >= state.session!.exercises.length) {
      return null;
    }
    final exercise = state.session!.exercises[exerciseIndex];
    if (!exercise.unilateral || setIndex < 0 || setIndex >= exercise.sets.length) {
      return null;
    }
    final preferred = switch (
      ref.read(settingsProvider).preferredUnilateralStartSide
    ) {
      PreferredWorkoutSide.left => WorkoutSide.left,
      PreferredWorkoutSide.right => WorkoutSide.right,
      PreferredWorkoutSide.automatic => null,
    };
    return UnilateralSetCoordinator.recommendedFirstSide(
      preferred: preferred,
      set: exercise.sets[setIndex],
    );
  }

  void updateSideRestSeconds(int exerciseIndex, int setIndex, int seconds) {
    if (state.session == null || seconds < 0) return;
    final exercise = state.session!.exercises[exerciseIndex];
    final set = exercise.sets[setIndex];
    updateSet(
      exerciseIndex,
      setIndex,
      set.copyWith(sideRestSeconds: seconds),
    );
  }

  void configureExerciseUnilateral(
    int exerciseIndex, {
    required bool unilateral,
    UnilateralTarget target = UnilateralTarget.other,
  }) {
    if (state.session == null) return;
    _captureUndo();
    final exercises = List<WorkoutExercise>.from(state.session!.exercises);
    final current = exercises[exerciseIndex];
    final configuredSideRest =
        ref.read(settingsProvider).unilateralSideRestSeconds;
    final sets = current.sets.map((set) {
      if (unilateral) {
        if (set.completed && !set.leftCompleted && !set.rightCompleted) {
          return set.copyWith(
            completed: true,
            leftCompleted: true,
            rightCompleted: true,
            leftWeight: set.weight,
            leftReps: set.reps,
            leftRir: set.rir,
            clearLeftRir: set.rir == null,
            rightWeight: set.weight,
            rightReps: set.reps,
            rightRir: set.rir,
            clearRightRir: set.rir == null,
            sideRestSeconds: configuredSideRest,
          );
        }
        return set.copyWith(
          completed: set.leftCompleted && set.rightCompleted,
          sideRestSeconds: configuredSideRest,
        );
      }

      return set.copyWith(
        completed: set.completed,
        leftCompleted: false,
        rightCompleted: false,
        clearLeftPerformance: true,
        clearRightPerformance: true,
      );
    }).toList();

    exercises[exerciseIndex] = current.copyWith(
      sets: sets,
      unilateral: unilateral,
      unilateralTarget: target,
    );
    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();
  }

  void updateExerciseNotes(int exerciseIndex, String notes) {
    if (state.session == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= state.session!.exercises.length) {
      return;
    }

    _captureUndo();
    final exercises = List<WorkoutExercise>.from(state.session!.exercises);
    final current = exercises[exerciseIndex];
    exercises[exerciseIndex] = current.copyWith(notes: notes.trim());

    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();
  }

  /// Replaces an exercise only while it has no completed work. This avoids
  /// attributing completed sets from the old movement to the replacement.
  /// The set structure/rests are preserved, while performance values reset.
  bool replaceExercise(int exerciseIndex, Exercise replacement) {
    if (state.session == null) return false;
    if (exerciseIndex < 0 || exerciseIndex >= state.session!.exercises.length) {
      return false;
    }

    final exercises = List<WorkoutExercise>.from(state.session!.exercises);
    final current = exercises[exerciseIndex];
    final hasCompletedWork = current.sets.any(
      (set) => set.completed || set.leftCompleted || set.rightCompleted,
    );
    if (hasCompletedWork) return false;

    _captureUndo();
    final resetSets = current.sets
        .map(
          (set) => WorkoutSet(
            weight: 0,
            reps: 0,
            completed: false,
            setType: set.setType,
            restSeconds: set.restSeconds,
            sideRestSeconds: set.sideRestSeconds,
          ),
        )
        .toList(growable: false);

    exercises[exerciseIndex] = WorkoutExercise(
      exerciseId: replacement.id,
      exerciseNameSnapshot: replacement.name,
      muscleGroupSnapshot: replacement.muscleGroup,
      sets: resetSets,
      supersetGroupId: current.supersetGroupId,
    );

    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();
    return true;
  }

  /// Crea una superserie de exactamente dos ejercicios. Si alguno ya estaba
  /// agrupado, primero se libera su grupo anterior para evitar grupos huérfanos
  /// o de más de dos elementos.
  bool createSuperset(int firstIndex, int secondIndex) {
    if (state.session == null || firstIndex == secondIndex) return false;
    final source = state.session!.exercises;
    if (firstIndex < 0 || firstIndex >= source.length) return false;
    if (secondIndex < 0 || secondIndex >= source.length) return false;

    _captureUndo();
    final groupsToClear = <String>{};
    final firstGroup = source[firstIndex].supersetGroupId;
    final secondGroup = source[secondIndex].supersetGroupId;
    if (firstGroup != null) groupsToClear.add(firstGroup);
    if (secondGroup != null) groupsToClear.add(secondGroup);

    final exercises = source.map((exercise) {
      if (exercise.supersetGroupId != null &&
          groupsToClear.contains(exercise.supersetGroupId)) {
        return exercise.copyWith(clearSupersetGroup: true);
      }
      return exercise;
    }).toList(growable: false);

    final groupId = const Uuid().v4();
    exercises[firstIndex] = exercises[firstIndex].copyWith(
      supersetGroupId: groupId,
    );
    exercises[secondIndex] = exercises[secondIndex].copyWith(
      supersetGroupId: groupId,
    );

    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();
    return true;
  }

  bool removeSuperset(int exerciseIndex) {
    if (state.session == null) return false;
    final source = state.session!.exercises;
    if (exerciseIndex < 0 || exerciseIndex >= source.length) return false;
    final groupId = source[exerciseIndex].supersetGroupId;
    if (groupId == null) return false;

    _captureUndo();
    final exercises = source
        .map(
          (exercise) => exercise.supersetGroupId == groupId
              ? exercise.copyWith(clearSupersetGroup: true)
              : exercise,
        )
        .toList(growable: false);

    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();
    return true;
  }

  void _maybeStartRest(int seconds, List<WorkoutExercise> exercises) {
    final autoRestEnabled = ref.read(settingsProvider).autoRestEnabled;
    if (!autoRestEnabled || seconds <= 0) return;
    final endsAt = DateTime.now().add(Duration(seconds: seconds));
    state = state.copyWith(session: _rebuildSession(exercises, endsAt));
    _persistDraft();
    _startRestTimer(seconds, endsAt);
  }

  void addSet(
    int exerciseIndex, {
    WorkoutSetType setType = WorkoutSetType.working,
  }) {
    if (state.session == null) return;

    _captureUndo();
    final exercises = List<WorkoutExercise>.from(state.session!.exercises);
    final sets = List<WorkoutSet>.from(exercises[exerciseIndex].sets);
    final inheritedRest = sets.isNotEmpty ? sets.last.restSeconds : 90;
    final inheritedSideRest = sets.isNotEmpty
        ? sets.last.sideRestSeconds
        : ref.read(settingsProvider).unilateralSideRestSeconds;
    sets.add(
      WorkoutSet(
        weight: 0,
        reps: 0,
        completed: false,
        setType: setType,
        restSeconds: inheritedRest,
        sideRestSeconds: inheritedSideRest,
      ),
    );

    exercises[exerciseIndex] = _withSets(exercises[exerciseIndex], sets);
    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();
  }

  void removeSet(int exerciseIndex, int setIndex) {
    if (state.session == null) return;

    final exercises = List<WorkoutExercise>.from(state.session!.exercises);
    final sets = List<WorkoutSet>.from(exercises[exerciseIndex].sets);
    if (sets.length <= 1) return;
    _captureUndo();
    sets.removeAt(setIndex);
    exercises[exerciseIndex] = _withSets(exercises[exerciseIndex], sets);

    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();
  }

  void addExercise(Exercise exercise) {
    if (state.session == null) return;

    _captureUndo();
    final exercises = List<WorkoutExercise>.from(state.session!.exercises);
    final sideRest = ref.read(settingsProvider).unilateralSideRestSeconds;
    exercises.add(
      WorkoutExercise(
        exerciseId: exercise.id,
        exerciseNameSnapshot: exercise.name,
        muscleGroupSnapshot: exercise.muscleGroup,
        sets: [
          WorkoutSet(
            weight: 0,
            reps: 0,
            completed: false,
            restSeconds: 90,
            sideRestSeconds: sideRest,
          ),
        ],
      ),
    );

    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();
  }

  void reorderExercises(int oldIndex, int newIndex) {
    if (state.session == null) return;
    _captureUndo();
    final exercises = List<WorkoutExercise>.from(state.session!.exercises);
    if (oldIndex < newIndex) newIndex -= 1;
    final item = exercises.removeAt(oldIndex);
    exercises.insert(newIndex, item);
    state = state.copyWith(
      session: _rebuildSession(exercises, state.session?.currentRestEndsAt),
    );
    _persistDraft();
  }

  void skipRest() {
    if (state.session == null) return;
    _captureUndo();
    _restTimer?.cancel();
    WorkoutNotificationService.cancelRestTimerNotification();
    state = state.copyWith(
      isResting: false,
      restTimerSeconds: 0,
      session: _rebuildSession(state.session!.exercises, null),
    );
    _persistDraft();
  }

  Future<FinishWorkoutResult?> finishWorkout() async {
    if (state.session == null) return null;
    _cancelTimers();

    final duration =
        DateTime.now().difference(state.session!.startedAt).inSeconds;

    final finalSession = WorkoutSession(
      id: state.session!.id,
      routineId: state.session!.routineId,
      routineNameSnapshot: state.session!.routineNameSnapshot,
      startedAt: state.session!.startedAt,
      finishedAt: DateTime.now(),
      durationSeconds: duration,
      exercises: state.session!.exercises,
      notes: state.session!.notes,
    );

    bool hasCompletedWorkingSets = false;
    for (final ex in finalSession.exercises) {
      if (ex.sets.any(
        (s) =>
            s.setType == WorkoutSetType.working &&
            s.completed &&
            s.performanceReps > 0,
      )) {
        hasCompletedWorkingSets = true;
        break;
      }
    }

    if (!hasCompletedWorkingSets) return EmptyWorkout();

    try {
      await ref.read(workoutRepositoryProvider).saveWorkoutSession(finalSession);
      ref.read(workoutHistoryProvider.notifier).refresh();

      // Shared progress is best-effort and must never block workout completion.
      // Tests/local-only flows may not initialize Supabase at all, so even
      // obtaining the cloud provider is isolated from the local save path.
      _syncSharedProgressBestEffort();

      await ref
          .read(gamificationProvider.notifier)
          .addWorkoutSession(finalSession);

      final analysisResult =
          await ref.read(workoutAnalysisServiceProvider).analyze(finalSession);

      // Program rotation is reconciled from the saved history, so free or
      // out-of-order workouts never advance A/B/C accidentally.
      await ref.read(trainingProgramListProvider.notifier).reconcileActive();

      await ref.read(activeWorkoutRepositoryProvider).clearDraft();
      _undoSession = null;
      state = const ActiveWorkoutState();
      return WorkoutFinished(analysisResult);
    } catch (_) {
      return null;
    }
  }

  void _syncSharedProgressBestEffort() {
    try {
      final notifier = ref.read(coachProgressProvider.notifier);
      final history = ref.read(workoutHistoryProvider);
      unawaited(
        notifier.syncOwnProgress(
          history,
          silent: true,
        ),
      );
    } catch (_) {
      // Remote sharing is optional. A cloud/bootstrap failure must never turn
      // a successfully saved local workout into a failed completion.
    }
  }

  Future<void> cancelWorkout() async {
    _cancelTimers();
    _undoSession = null;
    await ref.read(activeWorkoutRepositoryProvider).clearDraft();
    state = const ActiveWorkoutState();
  }

  void _startRestTimer(int initialSeconds, DateTime endsAt) {
    _restTimer?.cancel();
    state = state.copyWith(
      isResting: true,
      restTimerSeconds: initialSeconds,
    );
    WorkoutNotificationService.scheduleRestTimerNotification(endsAt);

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = endsAt.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        state = state.copyWith(restTimerSeconds: remaining);
      } else {
        timer.cancel();
        if (state.session == null) return;
        state = state.copyWith(
          isResting: false,
          restTimerSeconds: 0,
          session: _rebuildSession(state.session!.exercises, null),
        );
        _persistDraft();
      }
    });
  }

  void _cancelTimers() {
    _restTimer?.cancel();
    WorkoutNotificationService.cancelRestTimerNotification();
    _restTimer = null;
  }

  WorkoutSession _rebuildSession(
    List<WorkoutExercise> exercises,
    DateTime? restEndsAt,
  ) {
    return WorkoutSession(
      id: state.session!.id,
      routineId: state.session!.routineId,
      routineNameSnapshot: state.session!.routineNameSnapshot,
      startedAt: state.session!.startedAt,
      finishedAt: state.session!.finishedAt,
      durationSeconds: DateTime.now().difference(state.session!.startedAt).inSeconds,
      exercises: exercises,
      notes: state.session!.notes,
      currentRestEndsAt: restEndsAt,
    );
  }

  Future<void> _persistDraft() async {
    if (state.session != null) {
      await ref.read(activeWorkoutRepositoryProvider).saveDraft(state.session!);
    }
  }
}
