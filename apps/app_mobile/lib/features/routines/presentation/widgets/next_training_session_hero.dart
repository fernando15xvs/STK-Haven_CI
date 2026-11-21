import 'package:core/domain/models/routine.dart';
import 'package:core/features/programs/application/training_program_legacy_policy.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/unfinished_workout_reminder_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/features/routines/application/routine_card_evidence.dart';
import 'package:gym_tracker/features/workout/application/workout_launcher.dart';
import 'package:gym_tracker/features/workout/presentation/active_workout_page.dart';
import 'package:intl/intl.dart';

/// Read-only fallback for accounts that only have the old onboarding plan.
/// Modern paused plans suppress this fallback; there is no implicit rotation.
class LegacyTodaySession {
  const LegacyTodaySession(this.routine, this.programName);

  final Routine routine;
  final String programName;
}

final legacyTodaySessionProvider = Provider<LegacyTodaySession?>((ref) {
  final legacy = TrainingProgramLegacyPolicy.dashboardFallback(
    programs: ref.watch(trainingProgramListProvider),
    legacy: ref.watch(settingsProvider).activeProgram,
  );
  if (legacy == null) return null;
  final weekday = DateTime.now().weekday;
  for (final routine in ref.watch(routineListProvider)) {
    if (legacy.generatedRoutineIds.contains(routine.id) &&
        routine.scheduledDays.contains(weekday)) {
      return LegacyTodaySession(routine, legacy.programNameSnapshot);
    }
  }
  return null;
});

/// Entrenar owns the sole next-session hero. Inicio only offers a small link.
class NextTrainingSessionHero extends ConsumerStatefulWidget {
  const NextTrainingSessionHero({
    super.key,
    required this.routines,
    required this.historyByRoutine,
    required this.musclesFor,
  });

  final List<Routine> routines;
  final Map<String, RoutineCardEvidence> historyByRoutine;
  final List<String> Function(Routine routine) musclesFor;

  @override
  ConsumerState<NextTrainingSessionHero> createState() =>
      _NextTrainingSessionHeroState();
}

class _NextTrainingSessionHeroState
    extends ConsumerState<NextTrainingSessionHero> {
  bool _opening = false;

  Future<void> _open(Routine? routine) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (routine == null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ActiveWorkoutPage()),
        );
      } else {
        await WorkoutLauncher.launch(context, ref, routine);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final active = ref.watch(
      activeWorkoutProvider.select((state) => state.isActive),
    );
    final activeName = ref.watch(
      activeWorkoutProvider.select((state) => state.routineDisplayName),
    );
    final next = ref.watch(nextProgramSessionProvider);
    final currentProgram = ref.watch(activeTrainingProgramProvider);
    final legacyToday = ref.watch(legacyTodaySessionProvider);

    // Reuse the active workout; never start a second one automatically.
    if (active) {
      final lastActivityAt =
          ref.read(activeWorkoutRepositoryProvider).lastActivityAt;
      final sessionStart = ref.read(activeWorkoutProvider).session?.startedAt;
      final stale = sessionStart != null &&
          UnfinishedWorkoutReminderPolicy.isStale(
            lastActivityAt ?? sessionStart,
            DateTime.now(),
          );
      return PremiumCard(
        key: const ValueKey('train_next_session_hero'),
        backgroundColor: colors.primaryFaded,
        borderColor: colors.primary.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stale ? 'ENTRENAMIENTO PENDIENTE' : 'ENTRENAMIENTO EN CURSO',
              style: AppTypography.labelMedium.copyWith(
                color: colors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(activeName, style: AppTypography.headlineLarge),
            if (stale)
              Text(
                'Revisa la sesión antes de continuar o finalizar.',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('train_resume_workout'),
              onPressed: _opening ? null : () => _open(null),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Continuar'),
            ),
          ],
        ),
      );
    }

    // A paused program must not masquerade as the active next workout.
    // A person without a plan can still start any saved routine below.
    final suggested = next?.routine ?? legacyToday?.routine;
    if (suggested == null) {
      if (widget.routines.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          currentProgram == null
              ? 'Elige una rutina de tu lista para comenzar.'
              : 'No hay una próxima sesión disponible en este programa.',
          key: const ValueKey('train_choose_routine'),
          style: AppTypography.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
      );
    }

    final routine = suggested;
    final validRoutine =
        widget.routines.any((candidate) => candidate.id == routine.id);
    if (!validRoutine) {
      return Text(
        'La próxima rutina ya no está disponible. Revisa tu programa.',
        style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
      );
    }

    final muscles = widget.musclesFor(routine);
    final typicalMinutes =
        widget.historyByRoutine[routine.id]?.typicalMinutes;
    final schedule = next == null
        ? 'Programada para hoy · ${legacyToday!.programName}'
        : next.scheduledDate == null
            ? 'Rotación flexible · sin día obligatorio'
            : next.isTrainingDay
                ? 'Sesión programada para hoy'
                : 'Próximo día: ${DateFormat('EEE d MMM', 'es').format(next.scheduledDate!.toLocal())}';
    final detailItems = <String>[
      '${routine.exercises.length} ejercicios',
      if (muscles.isNotEmpty) muscles.join(' · '),
      if (typicalMinutes != null) '~$typicalMinutes min habituales',
    ];

    return PremiumCard(
      key: const ValueKey('train_next_session_hero'),
      backgroundColor: colors.primaryFaded,
      borderColor: colors.primary.withValues(alpha: 0.38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center_rounded, size: 19, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'SIGUIENTE SESIÓN',
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            routine.name,
            style: AppTypography.headlineLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            schedule,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final item in detailItems)
                Text(
                  item,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('train_start_next_session'),
              onPressed: _opening ? null : () => _open(routine),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Iniciar'),
            ),
          ),
        ],
      ),
    );
  }
}
