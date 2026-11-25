import 'package:core/domain/models/routine.dart';
import 'package:core/features/programs/application/training_program_legacy_policy.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/programs/application/training_day_decision.dart';
import 'package:core/features/programs/application/program_week_plan.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:gym_tracker/features/workout/presentation/widgets/recent_workout_details.dart';
import 'package:intl/intl.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/routines/application/providers/routine_provider.dart';
import 'package:core/features/programs/application/providers/training_program_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/unfinished_workout_reminder_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/features/routines/application/routine_card_evidence.dart';
import 'package:gym_tracker/features/workout/application/workout_launcher.dart';
import 'package:gym_tracker/features/workout/presentation/active_workout_page.dart';

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
  ref.watch(trainingDayClockProvider);
  final weekday = DateTime.now().weekday;
  for (final routine in ref.watch(routineListProvider)) {
    if (legacy.generatedRoutineIds.contains(routine.id) &&
        routine.scheduledDays.contains(weekday)) {
      return LegacyTodaySession(routine, legacy.programNameSnapshot);
    }
  }
  return null;
});

/// Read last activity from persistent draft only when an active session is
/// displayed. Overridable for widget QA without opening a user's Hive store.
final activeWorkoutLastActivityProvider = Provider<DateTime?>((ref) {
  // A saved set changes the immutable workout session; invalidate this
  // read rather than caching the last activity timestamp for the whole
  // exercise session and mislabeling recently edited workouts as stale.
  final session = ref.watch(
    activeWorkoutProvider.select((state) => state.session),
  );
  if (session == null) return null;
  return ref.read(activeWorkoutRepositoryProvider).lastActivityAt;
});

/// Entrenar owns the sole next-session hero. Inicio only offers a small link.
class NextTrainingSessionHero extends ConsumerStatefulWidget {
  const NextTrainingSessionHero({
    super.key,
    required this.routines,
    required this.historyByRoutine,
    required this.musclesFor,
    this.decision,
    this.routineMenu,
  });

  final List<Routine> routines;
  final Map<String, RoutineCardEvidence> historyByRoutine;
  final List<String> Function(Routine routine) musclesFor;
  final TrainingDayDecision? decision;
  final Widget Function(Routine routine)? routineMenu;

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

  Future<void> _editNotes(WorkoutSession session) async {
    final controller = TextEditingController(text: session.notes);
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Editar nota del entrenamiento'),
          content: TextField(controller: controller, maxLines: 4, maxLength: 1000),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Guardar')),
          ],
        ),
      );
      if (value == null || !mounted) return;
      await ref.read(workoutRepositoryProvider).saveWorkoutSession(
        WorkoutSession(
          id: session.id, routineId: session.routineId,
          routineNameSnapshot: session.routineNameSnapshot,
          startedAt: session.startedAt, finishedAt: session.finishedAt,
          exercises: session.exercises, durationSeconds: session.durationSeconds,
          notes: value, currentRestEndsAt: session.currentRestEndsAt,
        ),
      );
      if (mounted) ref.read(workoutHistoryProvider.notifier).refresh();
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    ref.watch(trainingDayClockProvider);
    final now = DateTime.now();
    final active = ref.watch(activeWorkoutProvider);
    final next = ref.watch(nextProgramSessionProvider);
    final currentProgram = ref.watch(activeTrainingProgramProvider);
    final legacyToday = ref.watch(legacyTodaySessionProvider);
    final history = ref.watch(workoutHistoryProvider);
    final plan = widget.decision != null || currentProgram == null ? null : ProgramWeekPlan.calculate(
        program: ProgramRotationCoordinator.reconcile(currentProgram, history),
        routines: widget.routines, now: now);
    final day = widget.decision ?? TrainingDayDecision.resolve(
      now: now, active: active.isActive ? active.session : null,
      history: history,
      next: next?.routine, mode: next?.program.scheduleMode,
      scheduledDate: next?.scheduledDate, isTrainingDay: next?.isTrainingDay ?? false,
      legacyToday: legacyToday?.routine, hasProgram: currentProgram != null,
      programPaused: plan?.isPaused ?? false, goalReached: plan?.goalReached ?? false,
    );
    final routine = day.routine;
    if (day.kind == TrainingDayKind.none ||
        (routine != null && !widget.routines.any((r) => r.id == routine.id))) {
      if (widget.routines.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(currentProgram == null
            ? 'Elige una rutina de tu lista para comenzar.'
            : 'No hay una próxima sesión disponible en este programa.',
          key: const ValueKey('train_choose_routine'),
          style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary)),
      );
    }

    final completed = day.kind == TrainingDayKind.completed;
    final rest = day.kind == TrainingDayKind.rest;
    final running = day.kind == TrainingDayKind.active;
    final session = day.session;
    final tint = completed ? colors.success : rest ? colors.textSecondary : colors.primary;
    final background = completed ? colors.success.withValues(alpha: 0.10)
        : rest ? colors.surface : colors.primaryFaded;
    final stale = running && session != null &&
        UnfinishedWorkoutReminderPolicy.isStale(
          ref.watch(activeWorkoutLastActivityProvider) ?? session.startedAt, now);
    final restName = switch (day.restReason) {
      TrainingRestReason.paused => 'Programa en pausa',
      TrainingRestReason.goalReached => 'Objetivo semanal cumplido',
      TrainingRestReason.unavailable => 'Sin sesión disponible',
      TrainingRestReason.scheduled => 'Día de descanso',
    };
    final name = rest ? restName
        : running ? active.routineDisplayName
        : completed ? (session!.routineNameSnapshot.isEmpty
            ? 'Entrenamiento libre' : session.routineNameSnapshot)
        : routine!.name;
    final title = rest ? (day.restReason == TrainingRestReason.goalReached ? 'SEMANA COMPLETADA' : 'RECUPERACIÓN') : completed ? 'FINALIZADO HOY'
        : running ? (stale ? 'PENDIENTE DE REVISAR' : 'SESIÓN EN CURSO')
        : 'INICIAR SESIÓN';
    Routine? managed;
    for (final item in widget.routines) {
      if (item.id == day.featuredRoutineId) { managed = item; break; }
    }
    final menu = managed == null || rest || running ? null : widget.routineMenu?.call(managed);
    final action = day.allowsSuggestedStart
        ? IconButton(
            key: const ValueKey('train_start_next_session'),
            tooltip: 'Iniciar sesión', onPressed: _opening ? null : () => _open(routine),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48),
              fixedSize: const Size(48, 48), visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.padded),
            color: tint, icon: const Icon(Icons.arrow_forward_rounded))
        : null;
    final items = <Widget>[];
    if (day.allowsSuggestedStart && routine != null) {
      items.add(_metric(context, Icons.format_list_numbered, '${routine.exercises.length} ejercicios'));
      final minutes = widget.historyByRoutine[routine.id]?.typicalMinutes;
      if (minutes != null) items.add(_metric(context, Icons.schedule, '~$minutes min'));
    }
    if (running && session != null) {
      final finished = session.exercises.where((exercise) {
        final sets = exercise.sets.where((s) => s.setType == WorkoutSetType.working).toList();
        return sets.isNotEmpty && sets.every((s) => s.completed);
      }).length;
      items.add(_metric(context, Icons.format_list_numbered,
          '$finished de ${session.exercises.length} ejercicios'));
      final minutes = now.difference(session.startedAt).inMinutes.clamp(0, 99999);
      items.add(_metric(context, Icons.schedule, '$minutes min'));
      items.add(FilledButton(
        key: const ValueKey('train_resume_workout'),
        onPressed: _opening ? null : () => _open(null),
        child: const Text('Continuar')));
    }
    if (completed && session != null) {
      items.add(FilledButton(
        key: const ValueKey('train_view_completed'),
        style: FilledButton.styleFrom(backgroundColor: tint,
            foregroundColor: ThemeData.estimateBrightnessForColor(tint) == Brightness.dark
                ? Colors.white : Colors.black),
        onPressed: () => RecentWorkoutDetails.show(context, session, ref.read(settingsProvider).weightUnit),
        child: const Text('Ver entrenamiento')));
      items.add(OutlinedButton.icon(
        onPressed: () => _editNotes(session), icon: const Icon(Icons.edit_outlined),
        label: const Text('Editar nota')));
    }

    final ui = AppUiTokens.of(context);
    return SizedBox(
      width: double.infinity,
      child: PremiumCard(
        key: const ValueKey('train_next_session_hero'),
        backgroundColor: background,
        borderColor: tint.withValues(alpha: 0.38),
        padding: EdgeInsets.symmetric(horizontal: ui.cardPadding,
          vertical: ui.cardPadding - AppSpacing.xxs),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (context, constraints) {
            final actions = <Widget>[if (menu != null) menu, if (action != null) action];
            final compactHeader = constraints.maxWidth >= 260 &&
                MediaQuery.textScalerOf(context).scale(14) <= 21;
            final leading = Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: rest ? colors.surfaceHigh : tint,
                borderRadius: BorderRadius.circular(AppUiTokens.of(context).buttonRadius)),
              child: Icon(rest ? Icons.nightlight_round : completed
                  ? Icons.check_rounded : Icons.fitness_center_rounded,
                color: rest ? tint : ThemeData.estimateBrightnessForColor(tint) == Brightness.dark
                    ? Colors.white : Colors.black),
            );
            final labels = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTypography.labelMedium.copyWith(color: tint)),
              const SizedBox(height: AppSpacing.xxs),
              Text(name, style: AppTypography.headlineMedium),
              if (completed && session != null)
                Text('Completado · ${(session.durationSeconds / 60).round()} min',
                    style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
            ]);
            return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              leading, const SizedBox(width: AppSpacing.sm),
              Expanded(child: compactHeader || actions.isEmpty ? labels : Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  labels,
                  Align(alignment: Alignment.centerRight,
                    child: Wrap(children: actions)),
                ])),
              if (compactHeader) ...actions,
            ]);
          }),
          if (stale) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Revisa la sesión antes de continuar o finalizar.',
                style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
          ],
          if (rest) ...[
            const SizedBox(height: AppSpacing.xs),
            if (routine != null && day.date != null)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.calendar_today_outlined, size: 18, color: colors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text('Próximo día: ${_dateLabel(day.date!, now)} · ${routine.name}',
                    style: AppTypography.bodySmall.copyWith(color: colors.textSecondary))),
              ])
            else
              Text(switch (day.restReason) {
                TrainingRestReason.paused => 'Tu progreso se conserva durante la pausa.',
                TrainingRestReason.goalReached => 'Puedes descansar o entrenar por decisión propia.',
                TrainingRestReason.unavailable => 'Consulta tu planificación o elige una rutina.',
                TrainingRestReason.scheduled => 'No tienes entrenamientos programados hoy.',
              }, style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center, children: items),
          ],
        ]),
      ),
    );
  }

  String _dateLabel(DateTime date, DateTime now) {
    final today = TrainingDayDecision.localDay(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    return date == tomorrow ? 'Mañana' : DateFormat('EEEE d MMM', 'es').format(date);
  }

  Widget _metric(BuildContext context, IconData icon, String label) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: colors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: colors.surfaceBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(label, style: AppTypography.bodySmall.copyWith(color: colors.textSecondary))),
      ]),
    );
  }
}
