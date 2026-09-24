import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
import 'package:core/features/home/application/hydration_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../faith/presentation/ai_chat_page_web.dart';
import '../../faith/presentation/bible_reader_page_web.dart';
import '../../faith/presentation/daily_verse_page_web.dart';
import '../../workout/presentation/active_workout_page_web.dart';
import 'widgets/recovery_check_in_card_web.dart';

class HomePageWeb extends ConsumerWidget {
  const HomePageWeb({super.key});

  Future<void> _startRoutine(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
    List<Exercise> exercises,
  ) async {
    final active = ref.read(activeWorkoutProvider);
    if (active.isActive) {
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ActiveWorkoutPageWeb()),
      );
      return;
    }
    ref.read(activeWorkoutProvider.notifier).startWorkout(routine, exercises);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutPageWeb()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final routines = ref.watch(routineListProvider);
    final exercises = ref.watch(exerciseListProvider);
    final history = ref.watch(workoutHistoryProvider);
    final active = ref.watch(activeWorkoutProvider);
    final hydration = ref.watch(hydrationProvider);
    final faithEnabled = ref.watch(
      userExperienceProfileProvider.select(
        (profile) => profile.value?.faithEnabled ?? false,
      ),
    );
    final verseAsync = faithEnabled ? ref.watch(dailyVerseProvider) : null;
    final bibleInit = faithEnabled ? ref.watch(bibleInitProvider) : null;
    final nextProgramSession = ref.watch(nextProgramSessionProvider);
    final prs = ref.watch(personalRecordRepositoryProvider).getAllPRs()
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

    final now = DateTime.now();
    Routine? todayRoutine;
    String? todayLabel;
    String? restSubtitle;

    if (nextProgramSession != null) {
      todayLabel = 'SIGUIENTE SESIÓN · ${nextProgramSession.program.name}';
      if (nextProgramSession.isTrainingDay) {
        todayRoutine = nextProgramSession.routine;
      } else {
        restSubtitle =
            'Próxima sesión: ${nextProgramSession.routine.name}. La secuencia continúa en tu próximo día de entrenamiento.';
      }
    } else {
      for (final routine in routines) {
        if (routine.scheduledDays.contains(now.weekday)) {
          todayRoutine = routine;
          break;
        }
      }
    }

    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final week = history.where((session) => !session.startedAt.isBefore(startOfWeek)).toList();
    var weeklySets = 0;
    var weeklySeconds = 0;
    var weeklyVolume = 0.0;
    final trainedDays = <int>{};
    for (final session in week) {
      weeklySeconds += session.durationSeconds;
      trainedDays.add(session.startedAt.weekday);
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          if (!set.completed || set.warmup) continue;
          weeklySets++;
          weeklyVolume += set.performedVolume;
        }
      }
    }

    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 520 ? 16.0 : 22.0;
    final recentPr = prs.isEmpty ? null : prs.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 110),
              children: [
                const _GreetingHeader(),
                if (faithEnabled && settings.showDailyVerse &&
                    verseAsync != null && bibleInit != null) ...[
                  const SizedBox(height: 20),
                  _DailyMessageCard(
                    verseAsync: verseAsync,
                    bibleInit: bibleInit,
                    onRetry: () => ref.read(bibleInitProvider.notifier).initialize(),
                    onOpenReflection: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DailyVersePageWeb()),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text('Tu día', style: AppTypography.headlineLarge),
                const SizedBox(height: 10),
                if (active.isActive) ...[
                  _ActiveWorkoutCard(
                    name: active.routineDisplayName,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ActiveWorkoutPageWeb()),
                    ),
                  ),
                ] else ...[
                  _TodayRoutineCard(
                    routine: todayRoutine,
                    label: todayLabel,
                    restSubtitle: restSubtitle,
                    onStart: todayRoutine == null
                        ? null
                        : () => _startRoutine(context, ref, todayRoutine!, exercises),
                  ),
                ],
                const SizedBox(height: 14),
                const RecoveryCheckInCardWeb(),
                if (settings.activeProgram != null) ...[
                  const SizedBox(height: 14),
                  _ProgramCard(settings: settings),
                ],
                const SizedBox(height: 24),
                Text('Bienestar y progreso', style: AppTypography.headlineLarge),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 760;
                    final hydrationCard = _HydrationCard(
                      waterMl: hydration.waterMl,
                      onAdd: (ml) => ref.read(hydrationProvider.notifier).addWater(ml),
                    );
                    final weekCard = _WeeklyCard(
                      workouts: week.length,
                      sets: weeklySets,
                      seconds: weeklySeconds,
                      volume: weeklyVolume,
                      trainedDays: trainedDays,
                      weightLabel: settings.weightUnit.label,
                      displayedVolume: WeightConverter.displayWeight(weeklyVolume, settings.weightUnit),
                    );
                    if (stacked) {
                      return Column(children: [hydrationCard, const SizedBox(height: 14), weekCard]);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Expanded(child: hydrationCard), const SizedBox(width: 14), Expanded(child: weekCard)],
                    );
                  },
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 760;
                    final lastWorkoutCard = _LastWorkoutCard(session: history.isEmpty ? null : history.first);
                    final prCard = _RecentPrCard(
                      title: recentPr?.exerciseNameSnapshot,
                      value: recentPr == null
                          ? null
                          : FitnessFormatter.formatPRValue(recentPr.newValue, recentPr.type, settings.weightUnit),
                    );
                    if (stacked) {
                      return Column(children: [lastWorkoutCard, const SizedBox(height: 14), prCard]);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Expanded(child: lastWorkoutCard), const SizedBox(width: 14), Expanded(child: prCard)],
                    );
                  },
                ),
                if (faithEnabled) ...[
                  const SizedBox(height: 24),
                  Text('Fe y enfoque', style: AppTypography.headlineLarge),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 620;
                      final bible = _FeatureCard(
                        icon: Icons.menu_book_outlined,
                        title: 'La Biblia',
                        subtitle: 'Lee por libro y capítulo.',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BibleReaderPageWeb(),
                          ),
                        ),
                      );
                      final faith = _FeatureCard(
                        icon: Icons.auto_awesome_outlined,
                        title: 'Haven Faith',
                        subtitle: 'Asistente espiritual y físico.',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AiChatPageWeb(),
                          ),
                        ),
                      );
                      if (stacked) {
                        return Column(
                          children: [bible, const SizedBox(height: 12), faith],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: bible),
                          const SizedBox(width: 14),
                          Expanded(child: faith),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
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
    final greeting = now.hour < 12 ? 'Buenos días' : now.hour < 18 ? 'Buenas tardes' : 'Buenas noches';
    const weekdays = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO'];
    const months = ['ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO', 'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'];
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: AppTypography.displaySmall),
              const SizedBox(height: 4),
              Text('${weekdays[now.weekday - 1]}, ${now.day} DE ${months[now.month - 1]}', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.md_,
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.bolt, color: AppColors.primary),
        ),
      ],
    );
  }
}

class _DailyMessageCard extends StatelessWidget {
  final AsyncValue<DailyVerseState> verseAsync;
  final BibleInitState bibleInit;
  final VoidCallback onRetry;
  final VoidCallback onOpenReflection;

  const _DailyMessageCard({required this.verseAsync, required this.bibleInit, required this.onRetry, required this.onOpenReflection});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Icon(Icons.wb_sunny_outlined, color: AppColors.primary), const SizedBox(width: 8), Text('MENSAJE DE HOY', style: AppTypography.labelMedium)]),
          const SizedBox(height: 14),
          if (bibleInit.status == BibleDbStatus.error) ...[
            Text('No pude preparar el mensaje de hoy.', style: AppTypography.headlineSmall),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
          ] else
            verseAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text('El mensaje estará disponible en un momento.', style: AppTypography.bodyMedium),
              data: (state) {
                final verse = state.verse;
                if (state.isLoading || verse == null) return const LinearProgressIndicator();
                return InkWell(
                  onTap: onOpenReflection,
                  borderRadius: AppRadius.md_,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('“${verse.text}”', style: AppTypography.bodyLarge.copyWith(fontStyle: FontStyle.italic, height: 1.5, fontSize: 17)),
                        const SizedBox(height: 7),
                        Text(verse.reference, style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutCard extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _ActiveWorkoutCard({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      accent: true,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.md_, boxShadow: AppElevation.accent),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ENTRENAMIENTO EN CURSO', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)), Text(name, style: AppTypography.headlineLarge)])),
          FilledButton.icon(onPressed: onTap, icon: const Icon(Icons.play_arrow), label: const Text('Continuar')),
        ],
      ),
    );
  }
}

class _TodayRoutineCard extends StatelessWidget {
  final Routine? routine;
  final VoidCallback? onStart;
  final String? label;
  final String? restSubtitle;

  const _TodayRoutineCard({
    required this.routine,
    required this.onStart,
    this.label,
    this.restSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (routine == null) {
      return _Panel(
        child: Row(
          children: [
            const Icon(Icons.self_improvement, color: AppColors.textSecondary, size: 30),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Día de descanso', style: AppTypography.headlineLarge), Text(restSubtitle ?? 'No hay una rutina programada para hoy.', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary))])),
          ],
        ),
      );
    }
    return _Panel(
      accent: true,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.md_, boxShadow: AppElevation.accent),
            child: const Icon(Icons.fitness_center, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label ?? 'ENTRENAR AHORA', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)), Text(routine!.name, style: AppTypography.headlineLarge), Text('${routine!.exercises.length} ejercicios', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary))])),
          FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.play_arrow), label: const Text('Comenzar')),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final dynamic settings;
  const _ProgramCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final program = settings.activeProgram;
    final week = (DateTime.now().difference(program.startedAt).inDays / 7).floor() + 1;
    return _Panel(
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PROGRAMA ACTIVO', style: AppTypography.labelMedium), Text(program.programNameSnapshot, style: AppTypography.headlineSmall)])),
          Text('Semana ${week.clamp(1, program.durationWeeks)} / ${program.durationWeeks}', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _HydrationCard extends StatelessWidget {
  final int waterMl;
  final ValueChanged<int> onAdd;
  const _HydrationCard({required this.waterMl, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    const goal = 3000;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Icon(Icons.water_drop_outlined, color: Colors.lightBlueAccent), const SizedBox(width: 8), Expanded(child: Text('Hidratación diaria', style: AppTypography.headlineSmall)), Text('$waterMl / $goal ml', style: AppTypography.labelMedium)]),
          const SizedBox(height: 14),
          LinearProgressIndicator(value: (waterMl / goal).clamp(0.0, 1.0), minHeight: 9, borderRadius: BorderRadius.circular(20)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: () => onAdd(250), child: const Text('+250 ml')),
              OutlinedButton(onPressed: () => onAdd(500), child: const Text('+500 ml')),
              OutlinedButton(onPressed: () => onAdd(750), child: const Text('+750 ml')),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  final int workouts;
  final int sets;
  final int seconds;
  final double volume;
  final Set<int> trainedDays;
  final String weightLabel;
  final double displayedVolume;

  const _WeeklyCard({required this.workouts, required this.sets, required this.seconds, required this.volume, required this.trainedDays, required this.weightLabel, required this.displayedVolume});

  @override
  Widget build(BuildContext context) {
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Esta semana', style: AppTypography.headlineSmall),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final trained = trainedDays.contains(index + 1);
              return CircleAvatar(
                radius: 15,
                backgroundColor: trained ? AppColors.primary : AppColors.surfaceHigh,
                child: Text(days[index], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: trained ? Colors.white : AppColors.textSecondary)),
              );
            }),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              Text('$workouts entrenos', style: AppTypography.labelMedium),
              Text('$sets series', style: AppTypography.labelMedium),
              Text('${seconds ~/ 60} min', style: AppTypography.labelMedium),
              Text('${displayedVolume.toStringAsFixed(0)} $weightLabel', style: AppTypography.labelMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _LastWorkoutCard extends StatelessWidget {
  final dynamic session;
  const _LastWorkoutCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: session == null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Último entrenamiento', style: AppTypography.headlineSmall), const SizedBox(height: 8), Text('Aún no hay entrenamientos guardados.', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary))])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Último entrenamiento', style: AppTypography.headlineSmall),
                const SizedBox(height: 8),
                Text(session.routineNameSnapshot.isEmpty ? 'Entrenamiento libre' : session.routineNameSnapshot, style: AppTypography.headlineLarge),
                const SizedBox(height: 4),
                Text('${session.durationSeconds ~/ 60} min · ${session.exercises.length} ejercicios', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
              ],
            ),
    );
  }
}

class _RecentPrCard extends StatelessWidget {
  final String? title;
  final String? value;
  const _RecentPrCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: title == null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PR reciente', style: AppTypography.headlineSmall), const SizedBox(height: 8), Text('Tus récords personales aparecerán aquí.', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary))])
          : Row(
              children: [
                const Icon(Icons.emoji_events, color: AppColors.gold, size: 34),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PR reciente', style: AppTypography.labelMedium), Text(title!, style: AppTypography.headlineSmall), if (value != null) Text(value!, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary))])),
              ],
            ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _FeatureCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lg_,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lg_,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: AppRadius.lg_, border: Border.all(color: AppColors.border), boxShadow: AppElevation.soft),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: AppRadius.md_), child: Icon(icon, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTypography.headlineSmall), Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary))])),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ]),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final bool accent;
  const _Panel({required this.child, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: accent ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
        boxShadow: AppElevation.soft,
      ),
      child: child,
    );
  }
}
