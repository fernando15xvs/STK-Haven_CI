import 'dart:async';
import 'package:core/features/programs/application/training_day_decision.dart';
import 'package:core/features/programs/application/program_plan_insights.dart';
import 'package:core/features/programs/application/program_week_plan.dart';
import 'package:gym_tracker/features/programs/presentation/widgets/adaptive_planning_sheet.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_library_page.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/exercises/application/providers/exercise_provider.dart';
import 'package:core/features/routines/application/providers/routine_provider.dart';
import 'package:core/features/programs/application/providers/training_program_provider.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/action_navigation_group.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/core/theme/components/primary_button.dart';
import 'package:gym_tracker/features/routines/presentation/pages/create_routine_page.dart';
import 'package:gym_tracker/features/routines/presentation/pages/routine_templates_page.dart';
import 'package:gym_tracker/features/routines/presentation/widgets/quick_training_plan_sheet.dart';
import 'package:gym_tracker/features/programs/presentation/pages/training_programs_page.dart';
import 'package:gym_tracker/features/workout/application/workout_launcher.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:gym_tracker/features/routines/presentation/widgets/next_training_session_hero.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:gym_tracker/features/routines/application/routine_card_evidence.dart';

class RoutinesPage extends ConsumerStatefulWidget {
  const RoutinesPage({super.key});

  @override
  ConsumerState<RoutinesPage> createState() => _RoutinesPageState();
}

class _RoutinesPageState extends ConsumerState<RoutinesPage> with WidgetsBindingObserver {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleClock();
  }

  void _scheduleClock() {
    _clockTimer?.cancel();
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _clockTimer = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      ref.invalidate(trainingDayClockProvider);
      _scheduleClock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(trainingDayClockProvider);
      _scheduleClock();
    } else {
      _clockTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final routines = ref.watch(routineListProvider);
    final exercises = ref.watch(exerciseListProvider);
    final exerciseMap = {
      for (final exercise in exercises) exercise.id: exercise,
    };
    final activeProgram = ref.watch(activeTrainingProgramProvider);
    final nextProgramSession = ref.watch(nextProgramSessionProvider);
    final legacyTodaySession = ref.watch(legacyTodaySessionProvider);
    final workoutActive = ref.watch(
      activeWorkoutProvider.select((state) => state.isActive),
    );
    final history = ref.watch(workoutHistoryProvider);
    ref.watch(trainingDayClockProvider);
    final now = DateTime.now();
    final plan = activeProgram == null ? null : ProgramWeekPlan.calculate(
      program: ProgramRotationCoordinator.reconcile(activeProgram, history), routines: routines, now: now);
    final day = TrainingDayDecision.resolve(
      now: now,
      active: workoutActive ? ref.watch(activeWorkoutProvider).session : null,
      history: history,
      next: nextProgramSession?.routine,
      mode: nextProgramSession?.program.scheduleMode,
      scheduledDate: nextProgramSession?.scheduledDate,
      isTrainingDay: nextProgramSession?.isTrainingDay ?? false,
      legacyToday: legacyTodaySession?.routine,
      hasProgram: activeProgram != null, programPaused: plan?.isPaused ?? false,
      goalReached: plan?.goalReached ?? false,
    );
    final featuredRoutineId = day.featuredRoutineId;
    final eligibleRoutines = routines
        .where((routine) => routine.id != featuredRoutineId)
        .toList(growable: false);
    List<String> musclesFor(Routine routine) {
      final unique = <String>{};
      for (final item in routine.exercises) {
        final raw = exerciseMap[item.exerciseId]?.muscleGroup.trim();
        if (raw == null || raw.isEmpty) continue;
        unique.add(_canonicalMuscleLabel(raw));
      }
      return unique.take(2).toList(growable: false);
    }
    // A single pass over history replaces repeated per-card calculations.
    final usageByRoutine = RoutineCardEvidence.fromHistory(
      history, asOf: now,
    );

    void createRoutine() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateRoutinePage()),
      );
    }

    return Scaffold(
      // The bottom dock already identifies Entrenar.
      body: SafeArea(
        bottom: false,
        child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                AppUiTokens.of(context).pageHorizontalPadding, AppSpacing.sm,
                AppUiTokens.of(context).pageHorizontalPadding, AppSpacing.xxl,
              ),
              itemCount: 1 +
                  (routines.isEmpty
                      ? 1
                      : eligibleRoutines.length),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NextTrainingSessionHero(
                        routines: routines,
                        historyByRoutine: usageByRoutine,
                        musclesFor: musclesFor,
                        decision: day,
                        routineMenu: (routine) => _routineMenu(context, ref, routine),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ProgramOrganizerCard(routines: routines,
                        onPlanning: () => _showWeeklyPlan(context, ref, routines)),
                      const SizedBox(height: AppSpacing.sm),
                      LayoutBuilder(builder: (context, constraints) {
                        final links = [
                          _TrainingQuickLink(
                            key: const ValueKey('train_open_manage'),
                            label: 'Gestionar programa', icon: Icons.tune_rounded,
                            onTap: () => _showTrainingManagement(context,
                              canCreatePlan: activeProgram == null && routines.isNotEmpty),
                          ),
                          _TrainingQuickLink(
                            key: const ValueKey('train_open_library'),
                            label: 'Biblioteca de ejercicios', icon: Icons.fitness_center_rounded,
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const ExerciseLibraryPage())),
                          ),
                        ];
                        if (constraints.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(14) > 21) {
                          return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [links[0], const SizedBox(height: AppSpacing.xs), links[1]]);
                        }
                        return Row(children: [
                          Expanded(child: links[0]), const SizedBox(width: AppSpacing.sm),
                          Expanded(child: links[1]),
                        ]);
                      }),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Mis rutinas', style: AppTypography.headlineSmall),
                          ),
                          if (routines.isNotEmpty)
                            TextButton.icon(
                              onPressed: createRoutine,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Nueva'),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  );
                }

                if (routines.isEmpty && index == 1) {
                  return _EmptyState(onCreate: createRoutine);
                }

                final routine = eligibleRoutines[index - 1];
                final muscleGroups = musclesFor(routine);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _RoutineCard(
                    key: ValueKey('train_routine_${routine.id}'),
                    routine: routine,
                    muscleGroups: muscleGroups,
                    allowStart: !workoutActive,
                    evidence: usageByRoutine[routine.id],
                    onStart: () => _startRoutine(context, ref, routine, day),
                    onEdit: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CreateRoutinePage(editingRoutine: routine))),
                    menu: _routineMenu(context, ref, routine),

                  ),
                );
              },
        ),
      ),
    );
  }

  Future<void> _startRoutine(BuildContext context, WidgetRef ref, Routine routine,
      TrainingDayDecision day) async {
    if (day.kind == TrainingDayKind.completed || day.kind == TrainingDayKind.rest) {
      final confirmed = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: Text(day.kind == TrainingDayKind.completed
              ? 'Ya entrenaste hoy' : 'Día de descanso'),
          content: const Text('¿Quieres iniciar otro entrenamiento por decisión propia?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Entrenar de todos modos')),
          ],
        ));
      if (confirmed != true || !context.mounted) return;
    }
    if (day.kind == TrainingDayKind.completed || day.kind == TrainingDayKind.rest) {
      await WorkoutLauncher.launch(context, ref, routine, independent: true);
    } else {
      await WorkoutLauncher.launch(context, ref, routine);
    }
  }

  Widget _routineMenu(BuildContext context, WidgetRef ref, Routine routine) {
    final colors = AppColors.of(context);
    final tokens = AppUiTokens.of(context);
    PopupMenuItem<String> item(String value, String label, IconData icon,
        {bool destructive = false}) {
      final color = destructive ? colors.error : colors.textPrimary;
      return PopupMenuItem<String>(
        value: value,
        child: Row(children: [
          Icon(icon, size: 20, color: destructive ? color : colors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(label,
            style: AppTypography.bodyMedium.copyWith(color: color))),
        ]),
      );
    }

    return PopupMenuButton<String>(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.buttonRadius),
        side: BorderSide(color: colors.surfaceBorder, width: tokens.borderWidth),
      ),
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        fixedSize: const Size(48, 48),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      tooltip: 'Opciones de ${routine.name}',
      onSelected: (action) {
        switch (action) {
          case 'edit':
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => CreateRoutinePage(editingRoutine: routine)));
            break;
          case 'notes': _editRoutineNotes(context, ref, routine); break;
          case 'duplicate': _duplicateRoutine(context, ref, routine); break;
          case 'delete': _confirmDelete(context, ref, routine); break;
        }
      },
      itemBuilder: (_) => [
        item('edit', 'Editar', Icons.edit_outlined),
        item('notes', 'Nota', Icons.sticky_note_2_outlined),
        item('duplicate', 'Duplicar', Icons.copy_outlined),
        const PopupMenuDivider(height: 1),
        item('delete', 'Eliminar', Icons.delete_outline, destructive: true),
      ],
    );
  }

  Future<void> _showTrainingManagement(
    BuildContext context, {
    required bool canCreatePlan,
  }) async {
    final destination = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.of(context).surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUiTokens.of(context).cardRadius),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppUiTokens.of(sheetContext).cardPadding, 0,
            AppUiTokens.of(sheetContext).cardPadding, AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text('Gestionar', style: AppTypography.headlineLarge)),
                IconButton(tooltip: 'Cerrar gestión',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: AppSpacing.sm),
              ActionNavigationGroup(children: [
                ActionNavigationTile(
                  key: const ValueKey('train_manage_programs'),
                  icon: Icons.tune_rounded,
                  title: 'Administrar programas',
                  subtitle: 'Editar, activar y organizar programas',
                  onTap: () => Navigator.pop(sheetContext, 'programs'),
                ),
                ActionNavigationTile(
                  key: const ValueKey('train_manage_routine_templates'),
                  icon: Icons.fitness_center_outlined,
                  title: 'Plantillas de rutinas',
                  subtitle: 'Explorar y reutilizar rutinas',
                  onTap: () => Navigator.pop(sheetContext, 'routineTemplates'),
                ),
                ActionNavigationTile(
                  key: const ValueKey('train_manage_program_templates'),
                  icon: Icons.layers_outlined,
                  title: 'Plantillas de programas',
                  subtitle: 'Explorar y reutilizar programas',
                  onTap: () => Navigator.pop(sheetContext, 'programTemplates'),
                ),
                if (canCreatePlan)
                  ActionNavigationTile(
                    key: const ValueKey('train_create_plan'),
                    icon: Icons.add_rounded,
                    title: 'Crear plan',
                    subtitle: 'Organizar tus rutinas guardadas',
                    onTap: () => Navigator.pop(sheetContext, 'create'),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (destination) {
      case 'programs':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const TrainingProgramsPage()));
        break;
      case 'routineTemplates':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const RoutineTemplatesPage()));
        break;
      case 'programTemplates':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const TrainingProgramsPage(templatesOnly: true)));
        break;
      case 'create':
        QuickTrainingPlanSheet.show(context);
        break;
    }
  }

  Future<void> _editRoutineNotes(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    final controller = TextEditingController(text: routine.notes);
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.of(context).textDisabled,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Nota de la rutina', style: AppTypography.headlineLarge),
            const SizedBox(height: 4),
            Text(routine.name, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Ej. Priorizar técnica, subir peso la próxima sesión...',
                border: OutlineInputBorder(),
              ),
            ),
            Row(
              children: [
                if (routine.hasNotes)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, ''),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Borrar nota'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pop(sheetContext, controller.text.trim()),
                  icon: const Icon(Icons.check),
                  label: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) return;
    ref
        .read(routineListProvider.notifier)
        .updateRoutine(routine.copyWith(notes: result));
  }

  void _duplicateRoutine(BuildContext context, WidgetRef ref, Routine routine) {
    final copy = Routine(
      id: 'routine_${DateTime.now().microsecondsSinceEpoch}',
      name: '${routine.name} (copia)',
      scheduledDays: List<int>.from(routine.scheduledDays),
      exercises: routine.exercises
          .map((exercise) => exercise.copyWith())
          .toList(growable: false),
      createdAt: DateTime.now(),
      notes: routine.notes,
    );
    ref.read(routineListProvider.notifier).addRoutine(copy);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Se creó “${copy.name}”.')));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.of(context).surfaceHigh,
        title: const Text('Eliminar rutina'),
        content: Text(
          '¿Eliminar “${routine.name}”? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: AppColors.of(context).error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(routineListProvider.notifier).deleteRoutine(routine.id);
    }
  }

  Future<void> _showWeeklyPlan(
    BuildContext context,
    WidgetRef ref,
    List<Routine> routines,
  ) async {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final rawPlan = ref.read(activeTrainingProgramProvider);
    final activePlan = rawPlan == null ? null : ProgramRotationCoordinator.reconcile(
        rawPlan, ref.read(workoutHistoryProvider));
    if (activePlan != null) {
      final selection = await AdaptivePlanningSheet.show(context);
      if (selection != null && context.mounted) {
        final latest = ref.read(routineListProvider);
        for (final routine in latest) {
          if (routine.id == selection.routineId) {
            await WorkoutLauncher.launch(context, ref, routine,
                occurrenceId: selection.occurrenceId);
            break;
          }
        }
      }
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Días opcionales de rutinas',
              style: AppTypography.headlineLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Días opcionales cuando no hay un programa activo. Puedes mover tus rutinas.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...List.generate(7, (index) {
              final weekday = index + 1;
              final dayRoutines = routines
                  .where((routine) => routine.scheduledDays.contains(weekday))
                  .toList(growable: false);
              final today = DateTime.now().weekday == weekday;
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: today
                      ? AppColors.of(context).primaryFaded
                      : AppColors.of(context).surface,
                  borderRadius: AppRadius.md_,
                  border: Border.all(
                    color: today
                        ? AppColors.of(context).primary.withValues(alpha: 0.4)
                        : AppColors.of(context).surfaceBorder,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 88,
                      child: Text(
                        days[index],
                        style: AppTypography.labelMedium.copyWith(
                          color: today
                              ? AppColors.of(context).primary
                              : AppColors.of(context).textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: dayRoutines.isEmpty
                          ? Text(
                              'Descanso',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.of(context).textDisabled,
                              ),
                            )
                          : Column(
                              children: dayRoutines
                                  .map(
                                    (routine) => Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            routine.name,
                                            style: AppTypography.headlineSmall,
                                          ),
                                        ),
                                        IconButton(
                                            tooltip: 'Mover a otro día',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => _moveRoutineToDay(
                                              sheetContext, ref, routine, weekday,
                                            ),
                                            icon: const Icon(Icons.swap_horiz, size: 20),
                                          ),
                                      ],
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _moveRoutineToDay(
    BuildContext planContext,
    WidgetRef ref,
    Routine routine,
    int fromDay,
  ) async {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final availableDays = List<int>.generate(7, (index) => index + 1)
        .where((day) => day != fromDay && !routine.scheduledDays.contains(day))
        .toList(growable: false);

    if (availableDays.isEmpty) {
      ScaffoldMessenger.of(planContext).showSnackBar(
        const SnackBar(
          content: Text('Esta rutina ya está programada todos los días.'),
        ),
      );
      return;
    }

    final destination = await showModalBottomSheet<int>(
      context: planContext,
      useSafeArea: true,
      backgroundColor: AppColors.of(planContext).surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (destinationContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mover rutina', style: AppTypography.headlineLarge),
            const SizedBox(height: 4),
            Text(
              '${routine.name} · desde ${days[fromDay - 1]}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.of(planContext).textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...availableDays.map(
              (day) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.of(planContext).primary,
                ),
                title: Text(days[day - 1]),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(destinationContext, day),
              ),
            ),
          ],
        ),
      ),
    );
    if (destination == null || !planContext.mounted) return;

    final moved = await ref
        .read(routineListProvider.notifier)
        .moveRoutineToDay(
          routineId: routine.id,
          fromDay: fromDay,
          toDay: destination,
        );
    if (!planContext.mounted) return;

    if (!moved) {
      ScaffoldMessenger.of(planContext).showSnackBar(
        const SnackBar(content: Text('No se pudo mover la rutina.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(planContext);
    Navigator.of(planContext).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('“${routine.name}” se movió a ${days[destination - 1]}.'),
      ),
    );
  }
}

String _canonicalMuscleLabel(String raw) {
  final clean = raw.trim();
  const synonyms = <String, String>{
    'hombro': 'Hombros', 'hombros': 'Hombros',
    'pierna': 'Piernas', 'piernas': 'Piernas',
    'pantorrilla': 'Pantorrillas', 'pantorrillas': 'Pantorrillas',
    'brazo': 'Brazos', 'brazos': 'Brazos',
    'pectoral': 'Pecho', 'pecho': 'Pecho',
    'espalda': 'Espalda',
    'glúteo': 'Glúteos', 'glúteos': 'Glúteos',
    'abdominal': 'Abdominales', 'abdominales': 'Abdominales',
  };
  return synonyms[clean.toLowerCase()] ?? clean;
}

/// Light quick links, with adaptive wrapping instead of a blocky 2x2 grid.
class _TrainingQuickLink extends StatelessWidget {
  const _TrainingQuickLink({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PremiumCard(
    onTap: onTap,
    child: Row(children: [
      Icon(icon, color: AppColors.of(context).primary),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(label, style: AppTypography.bodyMedium)),
    ]),
  );
}

/// A compact context indicator. Full planning and settings live one tap away.
/// Program context without a second heavy card competing with the workout.
class _ProgramOrganizerCard extends ConsumerWidget {
  const _ProgramOrganizerCard({required this.routines, required this.onPlanning});
  final List<Routine> routines;
  final VoidCallback onPlanning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeTrainingProgramProvider);
    final programs = ref.watch(trainingProgramListProvider);
    final history = ref.watch(workoutHistoryProvider);
    ref.watch(trainingDayClockProvider);
    final now = DateTime.now();
    final plan = active == null ? null : ProgramRotationCoordinator.reconcile(active, history);
    final insights = plan == null ? null : ProgramPlanInsights.calculate(
      program: plan, routines: routines, now: now);
    final colors = AppColors.of(context);
    final mode = switch (plan?.scheduleMode) {
      ProgramScheduleMode.flexible => 'Flexible',
      ProgramScheduleMode.continuous => 'Continuo',
      ProgramScheduleMode.fixed => 'Fijo',
      null => '',
    };
    return PremiumCard(
      key: const ValueKey('train_compact_program'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.layers_outlined, color: colors.primary, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plan == null ? (programs.any((p) => !p.isTemplate)
                ? 'Programa pausado' : 'Sin programa activo') : 'Programa ${plan.name}',
                style: AppTypography.headlineSmall),
            Text(plan == null ? 'Tus rutinas siguen disponibles.'
                : '$mode · ${plan.scheduleMode == ProgramScheduleMode.fixed ? '' : plan.repeatsWeekly ? 'Semanal · ' : 'Rotativo · '}${insights!.targetSessionsPerWeek} sesiones/sem',
                style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
          ])),
          IconButton(key: const ValueKey('train_open_planning'), tooltip: 'Planificación',
              onPressed: onPlanning, icon: Icon(Icons.calendar_month_outlined, color: colors.primary)),
        ]),
        if (plan != null && insights != null) ...[
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(value: insights.weeklyCompletionRatio ?? 0,
              minHeight: 5, borderRadius: BorderRadius.circular(AppRadius.full)),
          const SizedBox(height: AppSpacing.xs),
          Text('Semana ${plan.weekAt(now)}/${plan.durationWeeks} · ${insights.completedThisWeek}/${insights.plannedThisWeek} sesiones',
              style: AppTypography.bodySmall),
        ],
      ]),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({super.key, required this.routine, required this.muscleGroups,
    required this.evidence, required this.allowStart, required this.onStart,
    required this.onEdit, required this.menu});
  final Routine routine;
  final List<String> muscleGroups;
  final RoutineCardEvidence? evidence;
  final bool allowStart;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final minutes = evidence?.typicalMinutes;
    final ui = AppUiTokens.of(context);
    final actions = <Widget>[
      menu,
      if (allowStart)
        IconButton(tooltip: 'Iniciar ${routine.name}', onPressed: onStart,
          style: IconButton.styleFrom(minimumSize: const Size(48, 48),
            fixedSize: const Size(48, 48), visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.padded),
          icon: Icon(Icons.play_circle_outline_rounded, color: colors.primary)),
    ];
    return PremiumCard(
      padding: EdgeInsets.symmetric(horizontal: ui.cardPadding,
          vertical: ui.cardPadding - AppSpacing.xxs),
      child: LayoutBuilder(builder: (context, constraints) {
        final labels = InkWell(
          onTap: onEdit,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(routine.name, style: AppTypography.headlineSmall),
            if (muscleGroups.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(muscleGroups.join(' · '),
                  style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
            ],
            const SizedBox(height: AppSpacing.xxs),
            Text('${routine.exercises.length} ejercicios${minutes == null ? '' : ' · ~$minutes min'}',
                style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
          ]),
        );
        if (constraints.maxWidth < 230 || MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            labels,
            Align(alignment: Alignment.centerRight, child: Wrap(children: actions)),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: labels), ...actions,
        ]);
      }),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 64,
              color: AppColors.of(context).textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('No tienes rutinas aún', style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Crea una desde cero o parte de una plantilla.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: 'CREAR RUTINA', onPressed: onCreate),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
