import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/domain/models/personal_record.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
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
import 'package:gym_tracker/features/nutrition/presentation/pages/nutrition_intelligence_page_mobile.dart';
import 'package:gym_tracker/features/home/presentation/widgets/recovery_check_in_card.dart';
import 'package:gym_tracker/features/home/presentation/widgets/home_training_shortcut.dart';
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
    final settings = ref.watch(settingsProvider);
    final faithEnabled = ref.watch(
      userExperienceProfileProvider.select(
        (profile) => profile.value?.faithEnabled ?? false,
      ),
    );
    final activeWorkout = ref.watch(activeWorkoutProvider);

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
            if (faithEnabled && settings.showDailyVerse) ...[
              const SizedBox(height: AppSpacing.sm),
              const _DailyMessageCard(),
            ],
            // The dock owns Entrenar navigation; resume only active drafts.
            if (activeWorkout.isActive) ...[
              const SizedBox(height: AppSpacing.md),
              _CompactActiveWorkoutAccess(
                name: activeWorkout.routineDisplayName,
                startedAt: activeWorkout.session!.startedAt,
                lastActivityAt: ref
                    .read(activeWorkoutRepositoryProvider)
                    .lastActivityAt,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'RECUPERACIÓN',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            RecoveryCheckInCard(
              compact: true,
              trainingContext: activeWorkout.isActive
                  ? RecoveryCheckInTiming.active
                  : completedToday != null
                      ? RecoveryCheckInTiming.completed
                      : RecoveryCheckInTiming.planned,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child:Text(
                  'BIENESTAR',
                  style:AppTypography.labelLarge.copyWith(
                    color:AppColors.of(context).textSecondary),
                )),
                TextButton.icon(
                  key:const ValueKey('home_open_nutrition_plan'),
                  onPressed:()=>Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:(_)=>const NutritionIntelligencePageMobile(),
                    ),
                  ),
                  icon:const Icon(Icons.restaurant_menu_outlined,size:18),
                  label:const Text('Nutrición'),
                ),
              ],
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
              'ACTIVIDAD SEMANAL',
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
            if (completedToday != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _CompletedTodayCard(
                session: completedToday,
                weightUnit: settings.weightUnit,
              ),
            ],
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

    return Column(
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
    final colors = AppColors.of(context);

    Widget loadingCard({bool providerError = false}) {
      final canRetry = failed || providerError;
      return Semantics(
        button: canRetry,
        label: canRetry ? 'Reintentar la reflexión de hoy' : null,
        child: PremiumCard(
          key: const ValueKey('home_daily_reflection_status'),
          padding: const EdgeInsets.all(AppSpacing.sm),
          backgroundColor: colors.primaryFaded,
          borderColor: colors.primary.withValues(alpha: 0.20),
          onTap: canRetry ? () {
            if (failed) ref.read(bibleInitProvider.notifier).initialize();
            ref.invalidate(dailyVerseProvider);
          } : null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  canRetry
                      ? 'No se pudo cargar la reflexión. Toca para reintentar.'
                      : 'Preparando la reflexión de hoy…',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (canRetry)
                Icon(Icons.refresh_rounded, color: colors.primary, size: 20)
              else
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      );
    }

    return stateAsync.when(
      loading: () => loadingCard(),
      error: (_, _) => loadingCard(providerError: true),
      data: (state) {
        final verse = state.verse;
        if (state.isLoading) return loadingCard();
        if (verse == null) return loadingCard(providerError: true);

        return Semantics(
          button: true,
          label: 'Leer reflexión completa: ${verse.reference}',
          child: PremiumCard(
            key: const ValueKey('home_daily_reflection'),
            padding: const EdgeInsets.all(AppSpacing.sm),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyVersePage()),
            ),
            backgroundColor: colors.primaryFaded,
            borderColor: colors.primary.withValues(alpha: 0.20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '“${verse.text}”',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        verse.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right, color: colors.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Only an active session gets a direct action on Inicio.
class _CompactActiveWorkoutAccess extends StatelessWidget {
  const _CompactActiveWorkoutAccess({
    required this.name,
    required this.startedAt,
    this.lastActivityAt,
  });

  final String name;
  final DateTime startedAt;
  final DateTime? lastActivityAt;

  @override
  Widget build(BuildContext context) {
    final stale = UnfinishedWorkoutReminderPolicy.isStale(
      lastActivityAt ?? startedAt,
      DateTime.now(),
    );
    return HomeTrainingShortcut(
      routineName: name,
      isPendingReview: stale,
      onContinue: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveWorkoutPage()),
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
    final colors = AppColors.of(context);
    return Padding(
      key: const ValueKey('home_completed_today_compact'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: colors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Finalizado hoy', style: AppTypography.labelSmall.copyWith(
                  color: colors.success,
                )),
                Text(
                  session.routineNameSnapshot.isEmpty
                      ? 'Entrenamiento libre'
                      : session.routineNameSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones del entrenamiento finalizado',
            onSelected: (action) {
              if (action == 'summary') {
                RecentWorkoutDetails.show(context, session, weightUnit);
              } else if (action == 'notes') {
                _editNotes(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'summary', child: Text('Ver resumen')),
              PopupMenuItem(value: 'notes', child: Text('Editar nota')),
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
