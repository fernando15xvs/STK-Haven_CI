import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/domain/models/active_program_state.dart';
import 'package:core/domain/models/personal_record.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/routines/data/routine_repository.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/workout_comparator.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/metric_tile.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/features/faith/presentation/pages/daily_verse_page.dart';
import 'package:gym_tracker/features/home/presentation/widgets/hydration_widget.dart';
import 'package:gym_tracker/features/home/presentation/widgets/recovery_check_in_card.dart';
import 'package:gym_tracker/features/workout/application/workout_launcher.dart';
import 'package:gym_tracker/features/workout/presentation/active_workout_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final lastWorkout = history.isNotEmpty ? history.first : null;
    final allPRs = prRepo.getAllPRs()..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
    final recentPR = allPRs.isNotEmpty ? allPRs.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
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
            const _GreetingHeader(),
            if (faithEnabled && settings.showDailyVerse) ...[
              const SizedBox(height: AppSpacing.lg),
              const _DailyMessageCard(),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('TU DÍA', style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            if (activeWorkout.isActive)
              _ActiveWorkoutHero(
                name: activeWorkout.routineDisplayName,
                startedAt: activeWorkout.session!.startedAt,
              )
            else
              _TodayRoutineCard(
                routineRepo: routineRepo,
                activeProgram: settings.activeProgram,
                programSession: nextProgramSession,
              ),
            const SizedBox(height: AppSpacing.md),
            const RecoveryCheckInCard(),
            if (settings.activeProgram != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ActiveProgramCard(
                activeProgram: settings.activeProgram!,
                history: history,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Text('BIENESTAR', style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            const HydrationWidget(),
            const SizedBox(height: AppSpacing.xxl),
            _WeeklyTracker(history: history),
            if (lastWorkout != null || recentPR != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              Text('RECIENTE', style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              _RecentGrid(
                lastWorkout: lastWorkout,
                history: history,
                recentPR: recentPR,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
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
                style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.md_,
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: const Icon(Icons.bolt, color: AppColors.primary),
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

    return stateAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (state) {
        final verse = state.verse;
        if (state.isLoading || verse == null) return const SizedBox.shrink();

        return PremiumCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DailyVersePage()),
          ),
          backgroundColor: AppColors.primaryFaded,
          borderColor: AppColors.primary.withValues(alpha: 0.28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: AppRadius.sm_,
                ),
                child: const Icon(Icons.wb_sunny_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MENSAJE DE HOY', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 6),
                    Text(
                      '“${verse.text}”',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLarge.copyWith(fontStyle: FontStyle.italic, height: 1.45),
                    ),
                    const SizedBox(height: 6),
                    Text(verse.reference, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveWorkoutHero extends StatelessWidget {
  final String name;
  final DateTime startedAt;

  const _ActiveWorkoutHero({required this.name, required this.startedAt});

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(startedAt);
    final minutes = elapsed.inMinutes;

    return PremiumCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveWorkoutPage()),
      ),
      backgroundColor: AppColors.primaryFaded,
      borderColor: AppColors.primary.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.md_,
                  boxShadow: AppElevation.accent,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ENTRENAMIENTO EN CURSO', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 3),
                    Text(name, style: AppTypography.headlineLarge),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            minutes <= 0 ? 'Recién comenzado · toca para continuar' : '$minutes min en curso · toca para continuar',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
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
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: AppRadius.md_),
              child: const Icon(Icons.self_improvement_outlined, color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Día de descanso', style: AppTypography.headlineMedium),
                  const SizedBox(height: 3),
                  Text(restSubtitle ?? 'No tienes una rutina programada para hoy.', style: AppTypography.bodySmall),
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
      backgroundColor: AppColors.primaryFaded,
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.md_,
                  boxShadow: AppElevation.accent,
                ),
                child: const Icon(Icons.fitness_center, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(programLabel == null ? 'ENTRENAR AHORA' : 'SIGUIENTE SESIÓN · $programLabel', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 3),
                    Text(routine.name, style: AppTypography.headlineLarge),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaPill(icon: Icons.format_list_numbered, text: '${routine.exercises.length} ejercicios'),
              _MetaPill(icon: Icons.schedule, text: '~$estimatedMinutes min'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveProgramCard extends StatelessWidget {
  final ActiveProgramState activeProgram;
  final List<WorkoutSession> history;

  const _ActiveProgramCard({required this.activeProgram, required this.history});

  @override
  Widget build(BuildContext context) {
    final daysSinceStart = DateTime.now().difference(activeProgram.startedAt).inDays;
    final rawWeek = (daysSinceStart / 7).floor() + 1;
    final week = rawWeek > activeProgram.durationWeeks ? activeProgram.durationWeeks : rawWeek;
    final completed = history.where((session) {
      return session.startedAt.isAfter(activeProgram.startedAt) &&
          activeProgram.generatedRoutineIds.contains(session.routineId);
    }).length;
    final progress = activeProgram.durationWeeks <= 0 ? 0.0 : week / activeProgram.durationWeeks;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(activeProgram.programNameSnapshot, style: AppTypography.headlineMedium)),
              Text('Semana $week/${activeProgram.durationWeeks}', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppColors.surfaceHigh,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('$completed entrenamientos completados', style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}

class _WeeklyTracker extends ConsumerWidget {
  final List<WorkoutSession> history;

  const _WeeklyTracker({required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final sessions = history.where((session) => !session.startedAt.isBefore(startOfWeek)).toList();

    var totalSets = 0;
    var totalVolume = 0.0;
    var totalTime = 0;
    final trainedDays = <int>{};
    for (final session in sessions) {
      totalSets += WorkoutComparator.calculateSets(session);
      totalVolume += WorkoutComparator.calculateVolume(session);
      totalTime += session.durationSeconds;
      trainedDays.add(session.startedAt.weekday);
    }

    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ESTA SEMANA', style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        PremiumCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final weekday = index + 1;
                  final trained = trainedDays.contains(weekday);
                  final today = weekday == now.weekday;
                  return Column(
                    children: [
                      Text(days[index], style: AppTypography.labelSmall),
                      const SizedBox(height: 7),
                      AnimatedContainer(
                        duration: AppMotion.fast,
                        width: 31,
                        height: 31,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: trained ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: trained
                                ? AppColors.primary
                                : today
                                    ? AppColors.primary.withValues(alpha: 0.65)
                                    : AppColors.surfaceBorder,
                          ),
                        ),
                        child: trained
                            ? const Icon(Icons.check, size: 15, color: Colors.white)
                            : today
                                ? const Icon(Icons.circle, size: 7, color: AppColors.primary)
                                : null,
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'ENTRENOS', value: '${sessions.length}')),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: MetricTile(label: 'SERIES', value: '$totalSets')),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'TIEMPO', value: '${totalTime ~/ 60}m')),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricTile(
                      label: 'VOLUMEN',
                      value: FitnessFormatter.formatVolume(totalVolume, settings.weightUnit),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentGrid extends StatelessWidget {
  final WorkoutSession? lastWorkout;
  final List<WorkoutSession> history;
  final PersonalRecordEvent? recentPR;

  const _RecentGrid({required this.lastWorkout, required this.history, required this.recentPR});

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (lastWorkout != null) _LastWorkoutCard(lastWorkout: lastWorkout!, history: history),
      if (recentPR != null) _RecentPRCard(pr: recentPR!),
    ];

    if (cards.length <= 1) return cards.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            children: [cards[0], const SizedBox(height: AppSpacing.sm), cards[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }
}

class _LastWorkoutCard extends StatelessWidget {
  final WorkoutSession lastWorkout;
  final List<WorkoutSession> history;

  const _LastWorkoutCard({required this.lastWorkout, required this.history});

  @override
  Widget build(BuildContext context) {
    WorkoutSession? previous;
    for (final session in history) {
      if (session.routineId == lastWorkout.routineId && session.id != lastWorkout.id) {
        previous = session;
        break;
      }
    }
    final comparison = WorkoutComparator.compare(
      currentSession: lastWorkout,
      previousSession: previous,
    );

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text('Último entrenamiento', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            lastWorkout.routineNameSnapshot.isEmpty ? 'Entrenamiento libre' : lastWorkout.routineNameSnapshot,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headlineSmall,
          ),
          const SizedBox(height: 5),
          if (comparison != null && comparison.volumeDifferencePercent != 0)
            Text(
              '${comparison.volumeDifferencePercent > 0 ? '+' : ''}${comparison.volumeDifferencePercent.toStringAsFixed(1)}% volumen',
              style: AppTypography.bodySmall.copyWith(
                color: comparison.volumeDifferencePercent > 0 ? AppColors.success : AppColors.warning,
              ),
            )
          else
            Text(DateFormat('dd MMM', 'es').format(lastWorkout.startedAt), style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}

class _RecentPRCard extends ConsumerWidget {
  final PersonalRecordEvent pr;

  const _RecentPRCard({required this.pr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.emoji_events_outlined, color: AppColors.gold),
          const SizedBox(height: AppSpacing.sm),
          Text('PR reciente', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(pr.exerciseNameSnapshot, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.headlineSmall),
          const SizedBox(height: 5),
          Text(
            FitnessFormatter.formatPRValue(pr.newValue, pr.type, settings.weightUnit),
            style: AppTypography.bodySmall.copyWith(color: AppColors.gold),
          ),
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
        color: AppColors.surfaceHigh.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
