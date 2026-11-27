import 'package:flutter/material.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:core/features/recovery/application/adaptive_recovery.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:core/features/recovery/application/sleep_diary.dart';
import 'package:core/features/recovery/application/recovery_session_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/exercises/application/providers/exercise_provider.dart';
import 'package:core/features/programs/application/providers/training_program_provider.dart';
import 'package:gym_tracker/features/workout/presentation/active_workout_page.dart';
import 'package:gym_tracker/features/programs/presentation/widgets/adaptive_planning_sheet.dart';
import 'package:core/features/routines/application/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/application/todays_workout_status.dart';
import 'package:core/features/programs/application/training_day_decision.dart';

class WorkoutLauncher {
  static bool _launching = false;

  static Future<void> launch(BuildContext context, WidgetRef ref, Routine routine, {
    bool independent = false, String? occurrenceId,
  }) async {
    if (_launching) return;
    _launching = true;
    try {
      await _launch(context,ref,routine,independent:independent,occurrenceId:occurrenceId);
    } finally {
      _launching = false;
    }
  }

  static Future<void> _launch(
    BuildContext context,
    WidgetRef ref,
    Routine routine, {
    bool independent = false,
    String? occurrenceId,
  }) async {
    final activeState = ref.read(activeWorkoutProvider);
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final exercises = ref.read(exerciseListProvider);

    // Guard: another workout is already active
    if (activeState.isActive) {
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.of(context).surfaceHigh,
          title: Text(
            'Entrenamiento en curso',
            style: TextStyle(
              color: AppColors.of(context).textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '${activeState.routineDisplayName} ya está en progreso.\n\n¿Qué deseas hacer?',
            style: TextStyle(color: AppColors.of(context).textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('continue'),
              child: const Text('Seguir con el actual'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard_start'),
              child: Text(
                'Descartar e iniciar nuevo',
                style: TextStyle(color: AppColors.of(context).warning),
              ),
            ),
          ],
        ),
      );
      if (choice == 'continue' || choice == null) {
        if (context.mounted && choice == 'continue') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActiveWorkoutPage()),
          );
        }
        return;
      }
      if (choice == 'discard_start') {
        await notifier.cancelWorkout();
      }
    }

    if (!context.mounted) return;
    if (ref.read(activeTrainingProgramProvider) != null) {
      try {
        await ref.read(trainingProgramListProvider.notifier).recoverAbandonedReservations();
      } catch (_) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo revisar la planificación. Inténtalo de nuevo.')));
        return;
      }
    }
    if (!context.mounted) return;
    final programSession = ref.read(nextProgramSessionProvider);
    final currentProgram = ref.read(activeTrainingProgramProvider);
    final now = DateTime.now();
    final completedToday = TodaysWorkoutStatus.latestCompletedToday(ref.read(workoutHistoryProvider), now) != null;
    final scheduledDate = programSession?.scheduledDate;
    final future = scheduledDate != null && TrainingDayDecision.localDay(scheduledDate).isAfter(TrainingDayDecision.localDay(now));
    if (!independent && currentProgram != null && (occurrenceId == null && (completedToday || programSession == null || future))) {
      final proceed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text(completedToday ? 'Ya entrenaste hoy' : 'No hay sesión disponible hoy'),
        content: const Text('Puedes realizar un entrenamiento independiente sin avanzar el programa.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Entrenar de forma independiente'))],
      ));
      if (proceed != true || !context.mounted) return;
      independent = true;
      occurrenceId = null;
    }
    if (!independent && occurrenceId == null && programSession != null && programSession.routine.id != routine.id) {
      final proceed = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rutina fuera de la secuencia'),
          content: Text(
            'La siguiente sesión de “${programSession.program.name}” es '
            '“${programSession.routine.name}”. Puedes entrenar '
            '“${routine.name}”, pero esta sesión no avanzará la rotación del '
            'programa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'cancel'),
              child: const Text('Cancelar'),
            ),
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'adapt'),
              child: const Text('Adaptar planificación')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'independent'),
              child: const Text('Entrenamiento independiente'),
            ),
          ],
        ),
      );
      if (!context.mounted || proceed == null || proceed == 'cancel') return;
      if (proceed == 'adapt') {
        final selection = await AdaptivePlanningSheet.show(context);
        if (selection != null && context.mounted) {
          for (final selected in ref.read(routineListProvider)) {
            if (selected.id == selection.routineId) {
              await _launch(context, ref, selected, occurrenceId: selection.occurrenceId);
              break;
            }
          }
        }
        return;
      }
      independent = true;
    }

    // Review before reserving a program occurrence. No template mutation.
    final recovery = ref.read(recoveryProvider);
    final sleep = ref.read(sleepDiaryProvider);
    final advice = AdaptiveRecovery.evaluate(now: DateTime.now(), routine: routine,
      exercises: exercises, sleep: sleep, checkIn: recovery,
      age: AdaptiveRecovery.consentedAge(ref.read(userExperienceProfileProvider).value, DateTime.now()));
    final muscleWork = AdaptiveRecovery.recentMuscleWork(now: DateTime.now(),
      sessions: ref.read(workoutHistoryProvider), exercises: exercises,
      selectedAreas: recovery?.fatiguedAreas ?? const []);
    final rirEnabled = ref.read(settingsProvider).isRirEnabled;
    var selectedRoutine = routine;
    var recoveryAdapted = false;
    if (advice.needsReview) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(advice.pain ? 'Revisa tus molestias' : 'Adaptar sesión de hoy'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(routine.name, style: AppTypography.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final reason in advice.reasons) Text('• $reason'),
              const SizedBox(height: AppSpacing.md),
              if (advice.pain)
                const Text('Evita los ejercicios que provoquen dolor. Si el dolor es agudo, intenso o persistente, busca valoración profesional.')
              else ...[
                const Text('Mantén un margen de esfuerzo y revisa la técnica. No se aumenta la carga por el check-in.'),
                if (rirEnabled && advice.suggestedRir != null)
                  Text('Margen orientativo: RIR ${advice.suggestedRir}. Ajusta según técnica y sensación real.'),
                for (final evidence in muscleWork)
                  Text('${evidence.area} · últimos 7 días: ${evidence.primarySets} series directas, ${evidence.secondarySets} exposiciones secundarias; ${evidence.highEffortSets} con RIR 0–1.'),
                for (final entry in advice.reducedSets.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${exercises.where((e) => e.id == routine.exercises[entry.key].exerciseId).firstOrNull?.name ?? 'Ejercicio'}: ${routine.exercises[entry.key].targetSets} → ${entry.value} series efectivas'),
                  ),
                const SizedBox(height: 8),
                const Text('Los ajustes solo afectan a esta sesión; la rutina y el calendario se conservan.'),
              ],
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            if (!advice.pain)
              TextButton(onPressed: () => Navigator.pop(ctx,'original'), child: const Text('Mantener sesión original')),
            if (!advice.pain && advice.reducedSets.isNotEmpty)
              FilledButton(onPressed: () => Navigator.pop(ctx,'adapted'), child: const Text('Iniciar sesión adaptada')),
            if (advice.pain)
              TextButton(onPressed: () => Navigator.pop(ctx,'planning'), child: const Text('Revisar planificación')),
          ],
        ),
      );
      if (!context.mounted || choice == null) return;
      if (choice == 'planning') {
        await AdaptivePlanningSheet.show(context);
        return;
      }
      if (choice == 'adapted') {
        selectedRoutine = advice.adapt(routine);
        recoveryAdapted = true;
      }
    }
    final adapted = ref.read(activeTrainingProgramProvider) != null;
    final programNotifier = ref.read(trainingProgramListProvider.notifier);
    final String? sessionId;
    try {
      sessionId = adapted || independent || occurrenceId != null
          ? await programNotifier.bindWorkoutStart(routine.id, occurrenceId: occurrenceId, independent: independent)
          : null;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo reservar la sesión. Inténtalo de nuevo.')));
      }
      return;
    }
    if (!context.mounted) {
      if (sessionId != null) {
        await programNotifier.releaseWorkoutBinding(sessionId);
      }
      return;
    }
    final workoutId = sessionId ?? RecoverySessionSnapshot.newSessionId();
    final startedAt = DateTime.now();
    try {
      await RecoverySessionSnapshot.capture(workoutId, startedAt, advice, sleep, recovery,
        adapted: recoveryAdapted);
      if (!context.mounted) {
        await RecoverySessionSnapshot.discard(workoutId);
        if (sessionId != null) await programNotifier.releaseWorkoutBinding(sessionId);
        return;
      }
      notifier.startWorkout(selectedRoutine, exercises, sessionId: workoutId,
        startedAt: startedAt);
    } catch (_) {
      await RecoverySessionSnapshot.discard(workoutId);
      if (sessionId != null) await programNotifier.releaseWorkoutBinding(sessionId);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo iniciar la sesión con su contexto. Inténtalo de nuevo.')));
      return;
    }
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveWorkoutPage()),
      );
    }
  }
}
