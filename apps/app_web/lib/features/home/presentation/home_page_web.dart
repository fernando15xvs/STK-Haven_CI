import 'dart:async';

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
import 'package:core/features/home/application/wellness_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';

import '../../../core/notifications/web_platform_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../faith/presentation/daily_verse_page_web.dart';
import '../../workout/presentation/active_workout_page_web.dart';
import 'widgets/recovery_check_in_card_web.dart';

class HomePageWeb extends ConsumerWidget {
  const HomePageWeb({super.key});

  Future<void> _showHydrationSettings(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(hydrationPreferencesProvider);
    var targetMl = current.targetMl;
    var reminderEnabled = current.reminderEnabled;
    var reminderHour = current.reminderHour;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Hidratación'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ajusta una meta que tenga sentido para ti. Esta función sirve como referencia de registro y no reemplaza una recomendación médica.',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Meta diaria: ${(targetMl / 1000).toStringAsFixed(targetMl % 1000 == 0 ? 0 : 2)} L',
                  ),
                  Slider(
                    value: targetMl.toDouble(),
                    min: 1000,
                    max: 5000,
                    divisions: 16,
                    label: '$targetMl ml',
                    onChanged: (value) =>
                        setDialogState(() => targetMl = value.round()),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Avisarme si todavía no llego a mi meta'),
                    subtitle: const Text(
                      'En la PWA el aviso funciona cuando el navegador permite notificaciones.',
                    ),
                    value: reminderEnabled,
                    onChanged: (value) =>
                        setDialogState(() => reminderEnabled = value),
                  ),
                  if (reminderEnabled)
                    DropdownButtonFormField<int>(
                      initialValue: reminderHour,
                      decoration: const InputDecoration(
                        labelText: 'Hora del recordatorio',
                      ),
                      items: [
                        for (final hour in [12, 15, 18, 20, 22])
                          DropdownMenuItem(
                            value: hour,
                            child: Text('${hour.toString().padLeft(2, '0')}:00'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => reminderHour = value);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;
    await ref
        .read(hydrationPreferencesProvider.notifier)
        .setTargetMl(targetMl);
    await ref
        .read(hydrationPreferencesProvider.notifier)
        .setReminderHour(reminderHour);
    await ref
        .read(hydrationPreferencesProvider.notifier)
        .setReminderEnabled(reminderEnabled);

    if (reminderEnabled && context.mounted) {
      final permission =
          await WebPlatformNotificationService.requestLocalNotificationPermission();
      if (permission != 'granted' && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El recordatorio quedó configurado, pero Safari todavía no concedió permiso de notificaciones.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _editSteps(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(dailyStepsProvider).steps;
    final controller = TextEditingController(text: '$current');
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pasos de hoy'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cantidad de pasos',
            hintText: 'Ej. 4500',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(controller.text.trim()),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      await ref.read(dailyStepsProvider.notifier).setSteps(value);
    }
  }

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
    final hydrationPreferences = ref.watch(hydrationPreferencesProvider);
    final dailySteps = ref.watch(dailyStepsProvider);
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
                const _HydrationReminderHost(),
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
                      targetMl: hydrationPreferences.targetMl,
                      reminderEnabled: hydrationPreferences.reminderEnabled,
                      reminderHour: hydrationPreferences.reminderHour,
                      onConfigure: () => _showHydrationSettings(context, ref),
                      onAdd: (ml) =>
                          ref.read(hydrationProvider.notifier).addWater(ml),
                    );
                    final stepsCard = _DailyStepsCard(
                      steps: dailySteps.steps,
                      onEdit: () => _editSteps(context, ref),
                    );
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          hydrationCard,
                          const SizedBox(height: 14),
                          stepsCard,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: hydrationCard),
                        const SizedBox(width: 14),
                        Expanded(child: stepsCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _WeeklyCard(
                  workouts: week.length,
                  sets: weeklySets,
                  seconds: weeklySeconds,
                  volume: weeklyVolume,
                  trainedDays: trainedDays,
                  weightLabel: settings.weightUnit.label,
                  displayedVolume: WeightConverter.displayWeight(
                    weeklyVolume,
                    settings.weightUnit,
                  ),
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
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          lastWorkoutCard,
                          const SizedBox(height: 14),
                          prCard,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Expanded(child: lastWorkoutCard), const SizedBox(width: 14), Expanded(child: prCard)],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HydrationReminderHost extends ConsumerStatefulWidget {
  const _HydrationReminderHost();

  @override
  ConsumerState<_HydrationReminderHost> createState() =>
      _HydrationReminderHostState();
}

class _HydrationReminderHostState
    extends ConsumerState<_HydrationReminderHost> {
  Timer? _timer;
  String? _signature;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    final preferences = ref.read(hydrationPreferencesProvider);
    final hydration = ref.read(hydrationProvider);
    final signature =
        '${preferences.reminderEnabled}|${preferences.reminderHour}|${preferences.targetMl}|${hydration.waterMl}|${preferences.lastReminderDate}';
    if (_signature == signature) return;
    _signature = signature;

    _timer?.cancel();
    if (!preferences.reminderEnabled ||
        hydration.waterMl >= preferences.targetMl) {
      return;
    }

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (preferences.lastReminderDate == today) return;

    final reminderAt = DateTime(
      now.year,
      now.month,
      now.day,
      preferences.reminderHour,
    );
    final delay = reminderAt.isAfter(now)
        ? reminderAt.difference(now)
        : Duration.zero;

    _timer = Timer(delay, () async {
      if (!mounted) return;
      final latestPreferences = ref.read(hydrationPreferencesProvider);
      final latestHydration = ref.read(hydrationProvider);
      if (!latestPreferences.reminderEnabled ||
          latestHydration.waterMl >= latestPreferences.targetMl ||
          latestPreferences.lastReminderDate == today) {
        return;
      }

      final missing =
          (latestPreferences.targetMl - latestHydration.waterMl).clamp(0, 5000);
      final shown =
          await WebPlatformNotificationService.showForegroundNotification(
        title: 'Hidratación · STK Haven',
        body: 'Te faltan $missing ml para tu meta personal de hoy.',
      );
      if (shown && mounted) {
        await ref
            .read(hydrationPreferencesProvider.notifier)
            .markReminderSent(DateTime.now());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(hydrationPreferencesProvider);
    ref.watch(hydrationProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedule();
    });
    return const SizedBox.shrink();
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
  final int targetMl;
  final bool reminderEnabled;
  final int reminderHour;
  final ValueChanged<int> onAdd;
  final VoidCallback onConfigure;

  const _HydrationCard({
    required this.waterMl,
    required this.targetMl,
    required this.reminderEnabled,
    required this.reminderHour,
    required this.onAdd,
    required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (targetMl - waterMl).clamp(0, targetMl);
    final progress =
        targetMl <= 0 ? 0.0 : (waterMl / targetMl).clamp(0.0, 1.0);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.water_drop_outlined,
                color: Colors.lightBlueAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hidratación diaria',
                  style: AppTypography.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Configurar hidratación',
                onPressed: onConfigure,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          Text(
            '$waterMl / $targetMl ml',
            style: AppTypography.labelMedium,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 10),
          Text(
            remaining == 0
                ? 'Meta registrada por hoy.'
                : 'Te faltan $remaining ml para tu meta personal.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (reminderEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Recordatorio: ${reminderHour.toString().padLeft(2, '0')}:00',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onAdd(250),
                child: const Text('+250 ml'),
              ),
              OutlinedButton(
                onPressed: () => onAdd(500),
                child: const Text('+500 ml'),
              ),
              OutlinedButton(
                onPressed: () => onAdd(750),
                child: const Text('+750 ml'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyStepsCard extends StatelessWidget {
  final int steps;
  final VoidCallback onEdit;

  const _DailyStepsCard({
    required this.steps,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_walk_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pasos de hoy',
                  style: AppTypography.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Registrar pasos',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          Text(
            '$steps',
            style: AppTypography.displaySmall,
          ),
          const SizedBox(height: 6),
          Text(
            'En la web puedes registrarlos manualmente. En Android e iOS se puede sincronizar el sensor del dispositivo.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
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
