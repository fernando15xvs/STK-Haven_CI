import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/domain/models/active_program_state.dart';
import 'package:core/domain/models/personal_record.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/programs/application/training_program_legacy_policy.dart';
import 'package:core/features/routines/data/routine_repository.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/todays_workout_status.dart';
import 'package:core/features/home/application/home_dashboard_session_policy.dart';
import 'package:core/features/home/application/hydration_provider.dart';
import 'package:core/features/home/application/wellness_provider.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:gym_tracker/features/home/application/home_refresh_policy.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:gym_tracker/features/progress/presentation/pages/focused_exercise_progress_page.dart';
import 'package:core/features/workout/presentation/widgets/recent_workout_details.dart';
import 'package:core/features/workout/application/unfinished_workout_reminder_policy.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/features/faith/presentation/pages/daily_verse_page.dart';
import 'package:gym_tracker/features/home/presentation/widgets/hydration_widget.dart';
import 'package:gym_tracker/features/home/presentation/widgets/home_wellness_layout.dart';
import 'package:gym_tracker/features/home/presentation/widgets/weekly_activity_card.dart';
import 'package:gym_tracker/features/progress/presentation/pages/progress_page.dart';
import 'package:gym_tracker/features/home/presentation/widgets/daily_steps_widget.dart';
import 'package:gym_tracker/features/home/presentation/widgets/recovery_check_in_card.dart';
import 'package:gym_tracker/features/workout/application/workout_launcher.dart';
import 'package:gym_tracker/features/workout/presentation/active_workout_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({
    super.key,
    this.onOpenProgress,
    this.isVisible = true,
  });

  final VoidCallback? onOpenProgress;
  final bool isVisible;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _appResumed = true;
  DateTime _observedAt = DateTime.now();

  bool get _shouldRefresh => HomeRefreshPolicy.canPoll(
        visible: widget.isVisible,
        appResumed: _appResumed,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restartClock();
    });
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restartClock();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_appResumed == resumed) return;
    _appResumed = resumed;
    if (resumed) {
      _restartClock();
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  void _restartClock() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (!_shouldRefresh) return;
    // A retained tab has no ticker while hidden. Refresh immediately when
    // visible again, then check time boundaries without rebuilding every tick.
    _refreshDailyState(force: true);
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshDailyState(),
    );
  }

  void _refreshDailyState({bool force = false}) {
    if (!mounted || !_shouldRefresh) return;
    final now = DateTime.now();
    final changedDay =
        !HomeRefreshPolicy.sameLocalDay(_observedAt, now);
    if (force || changedDay) {
      ref.read(hydrationProvider.notifier).checkDateAndRefresh();
      ref.read(dailyStepsProvider.notifier).checkDateAndRefresh();
    }
    if (changedDay) {
      // These providers otherwise cache yesterday's date while IndexedStack
      // keeps Inicio mounted. Do not mutate persisted history.
      ref.invalidate(nextProgramSessionProvider);
      ref.invalidate(recoveryProvider);
      ref.invalidate(dailyVerseProvider);
    }
    if (HomeRefreshPolicy.needsHeaderUpdate(_observedAt, now)) {
      setState(() => _observedAt = now);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(workoutHistoryProvider);
    final prRepo = ref.watch(personalRecordRepositoryProvider);
    final routineRepo = ref.watch(routineRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final faithEnabled = ref.watch(
      userExperienceProfileProvider.select(
        (profile) => profile.value?.faithEnabled ?? false,
      ),
    );
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final nextProgramSession = ref.watch(nextProgramSessionProvider);
    // The modern plan is authoritative even while paused. The onboarding
    // snapshot is read only for users who have no modern plans yet.
    final legacyProgram = TrainingProgramLegacyPolicy.dashboardFallback(
      programs: ref.watch(trainingProgramListProvider),
      legacy: settings.activeProgram,
    );

    final completedToday = TodaysWorkoutStatus.latestCompletedToday(
      history,
      DateTime.now(),
    );
    final recentWorkout = HomeDashboardSessionPolicy.recentWorkout(
      history: history,
      completedToday: completedToday,
      activeSessionId: activeWorkout.isActive ? activeWorkout.session?.id : null,
    );
    final allPRs = prRepo.getAllPRs()
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
    final recentPR = allPRs.isNotEmpty ? allPRs.first : null;

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
            120,
          ),
          children: [
            _GreetingHeader(now: _observedAt),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'TU ENTRENAMIENTO',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (activeWorkout.isActive)
              _ActiveWorkoutHero(
                session: activeWorkout.session!,
                name: activeWorkout.routineDisplayName,
                startedAt: activeWorkout.session!.startedAt,
                lastActivityAt: ref
                    .read(activeWorkoutRepositoryProvider)
                    .lastActivityAt,
              )
            else if (completedToday != null)
              _CompletedTodayCard(
                session: completedToday,
                weightUnit: settings.weightUnit,
              )
            else
              _TodayRoutineCard(
                routineRepo: routineRepo,
                activeProgram: legacyProgram,
                programSession: nextProgramSession,
              ),
            const SizedBox(height: AppSpacing.md),
            const RecoveryCheckInCard(compact: true),
            if (faithEnabled && settings.showDailyVerse) ...[
              const SizedBox(height: AppSpacing.md),
              const _DailyMessageCard(),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'BIENESTAR',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            HomeWellnessLayout(
              hydration: HydrationWidget(
                compact: true,
                isVisible: widget.isVisible,
              ),
              steps: DailyStepsWidget(
                compact: true,
                isVisible: widget.isVisible,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'ACTIVIDAD',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            WeeklyActivityCard(
              history: history,
              onOpenProgress: widget.onOpenProgress ??
                  () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProgressPage(),
                        ),
                      ),
            ),
            if (recentWorkout != null || recentPR != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'NOVEDADES',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.of(context).textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _RecentGrid(
                lastWorkout: recentWorkout,
                recentPR: recentPR,
                weightUnit: settings.weightUnit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final greeting = now.hour < 12
        ? 'Buenos días'
        : now.hour < 18
        ? 'Buenas tardes'
        : 'Buenas noches';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: AppTypography.displaySmall),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, d MMMM', 'es').format(now).toUpperCase(),
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.of(context).primary,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            borderRadius: AppRadius.md_,
            border: Border.all(color: AppColors.of(context).surfaceBorder),
          ),
          child: Icon(Icons.bolt, color: AppColors.of(context).primary),
        ),
      ],
    );
  }
}

class _DailyMessageCard extends ConsumerWidget {
  const _DailyMessageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(dailyVerseProvider);
    final bibleInit = ref.watch(bibleInitProvider);
    final failed = bibleInit.status == BibleDbStatus.error;

    Widget loadingCard() => PremiumCard(
      backgroundColor: AppColors.of(context).primaryFaded,
      borderColor: AppColors.of(context).primary.withValues(alpha: 0.28),
      onTap: failed
          ? () => ref.read(bibleInitProvider.notifier).initialize()
          : null,
      child: Row(
        children: [
          Icon(failed ? Icons.refresh_outlined : Icons.menu_book_outlined,
               color: AppColors.of(context).primary),
          const SizedBox(width: 12),
          Expanded(child: Text(
            failed ? 'No se pudo preparar el pasaje. Toca para reintentar.'
                   : 'Preparando el pasaje de hoy…',
            style: AppTypography.bodyMedium,
          )),
          if (!failed)
            const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );

    return stateAsync.when(
      loading: loadingCard,
      error: (_, _) => loadingCard(),
      data: (state) {
        final verse = state.verse;
        if (state.isLoading || verse == null) return loadingCard();

        return PremiumCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DailyVersePage()),
          ),
          backgroundColor: AppColors.of(context).primaryFaded,
          borderColor: AppColors.of(context).primary.withValues(alpha: 0.28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.of(context).primary.withValues(alpha: 0.14),
                  borderRadius: AppRadius.sm_,
                ),
                child: Icon(
                  Icons.wb_sunny_outlined,
                  color: AppColors.of(context).primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MENSAJE DE HOY',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.of(context).primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '“${verse.text}”',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      verse.reference,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.of(context).textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DailyVersePage(),
                        ),
                      ),
                      child: const Text('Leer completo'),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.of(context).textSecondary,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveWorkoutHero extends StatelessWidget {
  final WorkoutSession session;
  final String name;
  final DateTime startedAt;
  final DateTime? lastActivityAt;

  const _ActiveWorkoutHero({
    required this.session,
    required this.name,
    required this.startedAt,
    this.lastActivityAt,
  });

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(startedAt);
    final minutes = elapsed.inMinutes;
    final stale = UnfinishedWorkoutReminderPolicy.isStale(
      lastActivityAt ?? startedAt,
      DateTime.now(),
    );
    final effectiveExercises = session.exercises.where((exercise) {
      return exercise.sets.any((set) => set.setType == WorkoutSetType.working);
    }).toList(growable: false);
    final completedExercises = effectiveExercises.where((exercise) {
      final sets = exercise.sets
          .where((set) => set.setType == WorkoutSetType.working)
          .toList(growable: false);
      return sets.isNotEmpty && sets.every((set) => set.completed);
    }).length;
    final pendingExercises = effectiveExercises.length - completedExercises;

    return PremiumCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveWorkoutPage()),
      ),
      backgroundColor: AppColors.of(context).primaryFaded,
      borderColor: AppColors.of(context).primary.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.of(context).primary,
                  borderRadius: AppRadius.md_,
                  boxShadow: AppElevation.accent(context),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.of(context).onPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stale
                          ? 'ENTRENAMIENTO PENDIENTE'
                          : 'ENTRENAMIENTO EN CURSO',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.of(context).primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(name, style: AppTypography.headlineLarge),
                    if (stale)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Lleva varias horas sin cambios. Toca para revisar y finalizar o continuar.',
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.of(context).textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${completedExercises} de ${effectiveExercises.length} ejercicios completados'
            ' · ${pendingExercises} pendientes',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            minutes <= 0
                ? 'Recién comenzado · toca para continuar'
                : '$minutes min en curso · toca para continuar',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedTodayCard extends ConsumerWidget {
  final WorkoutSession session;
  final WeightUnit weightUnit;

  const _CompletedTodayCard({required this.session, required this.weightUnit});

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: session.notes);
    try {
      final notes = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Editar nota del entrenamiento'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: '¿Cómo te fue hoy?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (notes == null) return;
      // Preserve original session ID, exercises, working sets, duration and
      // progress history. Never re-award completed workouts when editing notes.
      final edited = WorkoutSession(
        id: session.id,
        routineId: session.routineId,
        routineNameSnapshot: session.routineNameSnapshot,
        startedAt: session.startedAt,
        finishedAt: session.finishedAt,
        exercises: session.exercises,
        durationSeconds: session.durationSeconds,
        notes: notes,
        currentRestEndsAt: session.currentRestEndsAt,
      );
      await ref.read(workoutRepositoryProvider).saveWorkoutSession(edited);
      ref.read(workoutHistoryProvider.notifier).refresh();
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumCard(
      backgroundColor: AppColors.of(context).primaryFaded,
      borderColor: AppColors.of(context).success.withValues(alpha: 0.55),
      // Explicit, independent actions below; no duplicate card-wide tap.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.of(context).success),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FINALIZADO HOY',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.of(context).success,
                      ),
                    ),
                    Text(
                      session.routineNameSnapshot.isEmpty
                          ? 'Entrenamiento libre'
                          : session.routineNameSnapshot,
                      style: AppTypography.headlineLarge,
                    ),
                    Text(
                      'Completado · ${session.durationSeconds ~/ 60} min',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Ver entrenamiento'),
                onPressed: () =>
                    RecentWorkoutDetails.show(context, session, weightUnit),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit_note),
                label: const Text('Editar nota'),
                onPressed: () => _editNotes(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayRoutineCard extends ConsumerWidget {
  final RoutineRepository routineRepo;
  final ActiveProgramState? activeProgram;
  final NextProgramSession? programSession;

  const _TodayRoutineCard({
    required this.routineRepo,
    this.activeProgram,
    this.programSession,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayWeekday = DateTime.now().weekday;
    final routines = routineRepo.getAllRoutines();
    Routine? todayRoutine;
    String? programLabel;
    String? restSubtitle;

    if (programSession != null) {
      programLabel = programSession!.program.name;
      if (programSession!.isTrainingDay) {
        todayRoutine = programSession!.routine;
      } else {
        restSubtitle =
            'Próxima sesión: ${programSession!.routine.name}. La secuencia continúa en tu próximo día de entrenamiento.';
      }
    } else {
      if (activeProgram != null) {
        for (final routine in routines) {
          if (activeProgram!.generatedRoutineIds.contains(routine.id) &&
              routine.scheduledDays.contains(todayWeekday)) {
            todayRoutine = routine;
            break;
          }
        }
      }

      if (todayRoutine == null) {
        for (final routine in routines) {
          if (routine.scheduledDays.contains(todayWeekday)) {
            todayRoutine = routine;
            break;
          }
        }
      }
    }

    if (todayRoutine == null) {
      return PremiumCard(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.of(context).surfaceHigh,
                borderRadius: AppRadius.md_,
              ),
              child: Icon(
                Icons.self_improvement_outlined,
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Día de descanso', style: AppTypography.headlineMedium),
                  const SizedBox(height: 3),
                  Text(
                    restSubtitle ?? 'No tienes una rutina programada para hoy.',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final routine = todayRoutine;
    final estimatedMinutes = (routine.exercises.length * 8).clamp(20, 90);

    return PremiumCard(
      onTap: () async => WorkoutLauncher.launch(context, ref, routine),
      backgroundColor: AppColors.of(context).primaryFaded,
      borderColor: AppColors.of(context).primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.of(context).primary,
                  borderRadius: AppRadius.md_,
                  boxShadow: AppElevation.accent(context),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: AppColors.of(context).onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      programLabel == null
                          ? 'ENTRENAR AHORA'
                          : 'SIGUIENTE SESIÓN · $programLabel',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.of(context).primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(routine.name, style: AppTypography.headlineLarge),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.of(context).primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaPill(
                icon: Icons.format_list_numbered,
                text: '${routine.exercises.length} ejercicios',
              ),
              _MetaPill(icon: Icons.schedule, text: '~$estimatedMinutes min'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentGrid extends StatelessWidget {
  final WorkoutSession? lastWorkout;
  final PersonalRecordEvent? recentPR;
  final WeightUnit weightUnit;

  const _RecentGrid({
    required this.lastWorkout,
    required this.recentPR,
    required this.weightUnit,
  });

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (lastWorkout != null)
        _LastWorkoutCard(
          lastWorkout: lastWorkout!,
          weightUnit: weightUnit,
        ),
      if (recentPR != null) _RecentPRCard(pr: recentPR!),
    ];

    if (cards.isEmpty) return const SizedBox.shrink();
    if (cards.length == 1) return cards.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cards[0],
        const SizedBox(height: AppSpacing.sm),
        cards[1],
      ],
    );
  }
}

class _LastWorkoutCard extends StatelessWidget {
  const _LastWorkoutCard({
    required this.lastWorkout,
    required this.weightUnit,
  });

  final WorkoutSession lastWorkout;
  final WeightUnit weightUnit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PremiumCard(
      onTap: () => RecentWorkoutDetails.show(context, lastWorkout, weightUnit),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: colors.primary, size: 25),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Último entrenamiento',
                    style: AppTypography.labelMedium.copyWith(
                        color: colors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  lastWorkout.routineNameSnapshot.isEmpty
                      ? 'Entrenamiento libre'
                      : lastWorkout.routineNameSnapshot,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSmall,
                ),
                Text(
                  DateFormat('dd MMM', 'es')
                      .format(lastWorkout.finishedAt.toLocal()),
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.textSecondary),
        ],
      ),
    );
  }
}

class _RecentPRCard extends ConsumerWidget {
  const _RecentPRCard({required this.pr});

  final PersonalRecordEvent pr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final exercise = ref.watch(exerciseListProvider)
        .where((item) => item.id == pr.exerciseId)
        .firstOrNull;
    final colors = AppColors.of(context);
    return PremiumCard(
      onTap: exercise == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FocusedExerciseProgressPage(exercise: exercise),
                ),
              ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_outlined, color: colors.gold, size: 25),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RÉCORD RECIENTE',
                    style: AppTypography.labelMedium.copyWith(
                        color: colors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  pr.exerciseNameSnapshot,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSmall,
                ),
                Text(
                  FitnessFormatter.formatPRValue(
                    pr.newValue,
                    pr.type,
                    settings.weightUnit,
                  ),
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (exercise != null)
            Icon(Icons.chevron_right, color: colors.textSecondary),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceHigh.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.of(context).surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.of(context).textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
