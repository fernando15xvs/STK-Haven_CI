import 'package:core/domain/models/routine.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/core/theme/components/primary_button.dart';
import 'package:gym_tracker/features/routines/presentation/pages/create_routine_page.dart';
import 'package:gym_tracker/features/routines/presentation/pages/routine_templates_page.dart';
import 'package:gym_tracker/features/routines/presentation/widgets/quick_training_plan_sheet.dart';
import 'package:core/features/programs/presentation/pages/training_programs_page.dart';
import 'package:gym_tracker/features/workout/application/workout_launcher.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:gym_tracker/features/routines/presentation/widgets/next_training_session_hero.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:gym_tracker/features/routines/application/routine_card_evidence.dart';
import 'package:intl/intl.dart';

class RoutinesPage extends ConsumerWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      ref.watch(workoutHistoryProvider),
    );

    void createRoutine() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateRoutinePage()),
      );
    }

    void openTemplates() { _showTemplatesChooser(context); }

    return Scaffold(
      // The bottom dock already identifies Entrenar.
      body: SafeArea(
        bottom: false,
        child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl,
              ),
              itemCount: routines.length + (routines.isEmpty ? 2 : 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Entrenar', style: AppTypography.headlineLarge),
                      const SizedBox(height: AppSpacing.md),
                      NextTrainingSessionHero(
                        routines: routines,
                        historyByRoutine: usageByRoutine,
                        musclesFor: musclesFor,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ProgramOrganizerCard(routines: routines),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _TrainingQuickLink(
                            key: const ValueKey('train_open_planning'),
                            label: 'Planificación',
                            icon: Icons.calendar_month_outlined,
                            onTap: () => _showWeeklyPlan(context, ref, routines),
                          ),
                          _TrainingQuickLink(
                            key: const ValueKey('train_open_manage'),
                            label: 'Administrar',
                            icon: Icons.tune_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TrainingProgramsPage(),
                              ),
                            ),
                          ),
                          _TrainingQuickLink(
                            key: const ValueKey('train_open_templates'),
                            label: 'Plantillas',
                            icon: Icons.layers_outlined,
                            onTap: openTemplates,
                          ),
                          if (activeProgram == null && routines.isNotEmpty)
                            _TrainingQuickLink(
                              key: const ValueKey('train_create_plan'),
                              label: 'Crear plan',
                              icon: Icons.add_rounded,
                              onTap: () => QuickTrainingPlanSheet.show(context),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: Text('MIS RUTINAS', style: AppTypography.labelLarge),
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

                final routine = routines[index - 1];
                final muscleGroups = musclesFor(routine);
                final linkedToActiveProgram =
                    activeProgram?.routineIds.contains(routine.id) ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _RoutineCard(
                    routine: routine,
                    muscleGroups: muscleGroups,
                    isSuggested: !workoutActive &&
                        (nextProgramSession?.routine.id ??
                                legacyTodaySession?.routine.id) ==
                            routine.id,
                    programName:
                        linkedToActiveProgram ? activeProgram!.name : null,
                    evidence: usageByRoutine[routine.id],
                    onStart: () => WorkoutLauncher.launch(context, ref, routine),
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateRoutinePage(editingRoutine: routine),
                      ),
                    ),
                    onNotes: () => _editRoutineNotes(context, ref, routine),
                    onDuplicate: () => _duplicateRoutine(context, ref, routine),
                    onDelete: () => _confirmDelete(context, ref, routine),
                  ),
                );
              },
        ),
      ),
    );
  }

  Future<void> _showTemplatesChooser(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.of(context).surfaceHigh,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Plantillas', style: AppTypography.headlineLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.fitness_center_outlined),
              title: const Text('Plantillas de rutinas'),
              subtitle: const Text('Crea una rutina y personaliza sus ejercicios'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const RoutineTemplatesPage(),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.layers_outlined),
              title: const Text('Plantillas de programas'),
              subtitle: const Text('Administra planes y plantillas reutilizables'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const TrainingProgramsPage(templatesOnly: true),
                ));
              },
            ),
          ],
        ),
      ),
    );
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
    final activePlan = ref.read(activeTrainingProgramProvider);
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - DateTime.monday));
    final projections = activePlan == null
        ? const <ProgramScheduledSession>[]
        : ProgramScheduleProjector.projectWeek(
            program: activePlan, routines: routines, weekStart: monday,
          );
    final routineById = <String, Routine>{
      for (final routine in routines) routine.id: routine,
    };
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
              activePlan == null ? 'Días opcionales de rutinas' : 'Semana del programa',
              style: AppTypography.headlineLarge,
            ),
            const SizedBox(height: 4),
            Text(
              activePlan == null
                  ? 'Días opcionales cuando no hay un programa activo. Puedes mover tus rutinas.'
                  : activePlan.scheduleMode == ProgramScheduleMode.flexible
                      ? 'Distribución orientativa: los días no son obligatorios en un plan flexible.'
                      : 'Calendario de “${activePlan.name}”. El plan prevalece sobre los días opcionales de cada rutina.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...List.generate(7, (index) {
              final weekday = index + 1;
              final dayRoutines = activePlan == null
                  ? routines
                      .where((routine) => routine.scheduledDays.contains(weekday))
                      .toList(growable: false)
                  : projections
                      .where((item) => item.date.weekday == weekday)
                      .map((item) => routineById[item.routineId])
                      .whereType<Routine>()
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
                                        if (activePlan == null)
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
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 2),
      );
}

/// A compact context indicator. Full planning and settings live one tap away.
class _ProgramOrganizerCard extends ConsumerWidget {
  const _ProgramOrganizerCard({required this.routines});

  final List<Routine> routines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeTrainingProgramProvider);
    final programs = ref.watch(trainingProgramListProvider);
    final hasExisting = programs.any((program) => !program.isTemplate);
    final colors = AppColors.of(context);
    final week = active?.weekAt(DateTime.now()) ?? 0;
    final target = active == null
        ? 0
        : ProgramScheduleProjector.effectiveTargetSessionsPerWeek(
            active, routines,
          );
    final name = active?.name ??
        (hasExisting ? 'Programa pausado' : 'Sin programa activo');

    return PremiumCard(
      key: const ValueKey('train_compact_program'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, color: colors.primary, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.headlineMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (active != null) ...[
                  Text(
                    'Semana $week/${active.durationWeeks} · $target sesiones/sem',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(
                    value: (week / active.durationWeeks.clamp(1, 9999))
                        .clamp(0.0, 1.0).toDouble(),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(99),
                    backgroundColor: colors.surfaceHigh,
                  ),
                ] else
                  Text(
                    hasExisting
                        ? 'Administra tus planes para reanudar.'
                        : 'Tus rutinas funcionan sin plan.',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (active != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              'ACTIVO',
              style: AppTypography.labelSmall.copyWith(
                color: colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final List<String> muscleGroups;
  final String? programName;
  final RoutineCardEvidence? evidence;
  final bool isSuggested;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onNotes;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _RoutineCard({
    required this.routine,
    required this.muscleGroups,
    required this.programName,
    required this.evidence,
    this.isSuggested = false,
    required this.onStart,
    required this.onEdit,
    required this.onNotes,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final lastFinishedAt = evidence?.lastFinishedAt;
    final typicalMinutes = evidence?.typicalMinutes;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  routine.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineMedium,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones de ${routine.name}',
                color: colors.surfaceHigh,
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'notes':
                      onNotes();
                      break;
                    case 'duplicate':
                      onDuplicate();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit',
                    child: ListTile(dense: true,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar'))),
                  const PopupMenuItem(value: 'notes',
                    child: ListTile(dense: true,
                      leading: Icon(Icons.sticky_note_2_outlined),
                      title: Text('Nota'))),
                  const PopupMenuItem(value: 'duplicate',
                    child: ListTile(dense: true,
                      leading: Icon(Icons.copy_all_outlined),
                      title: Text('Duplicar'))),
                  PopupMenuItem(value: 'delete',
                    child: ListTile(dense: true,
                      leading: Icon(Icons.delete_outline,
                        color: colors.error),
                      title: const Text('Eliminar'))),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${routine.exercises.length} ejercicios',
                style: AppTypography.bodyMedium),
              if (muscleGroups.isNotEmpty)
                Text(muscleGroups.join(' · '),
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary)),
            ],
          ),
          if (routine.hasNotes)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onNotes,
                icon: const Icon(Icons.sticky_note_2_outlined, size: 17),
                label: const Text('Ver nota'),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, available) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final sideBySide = available.maxWidth >= 290 && scale <= 1.3;
              final metadata = Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  Text(
                    programName == null
                        ? 'Rutina guardada' : 'En: $programName',
                    style: AppTypography.labelMedium.copyWith(
                      color: programName == null
                          ? colors.textSecondary : colors.primary),
                  ),
                  if (lastFinishedAt != null)
                    Text(
                      'Última vez: ${DateFormat('d MMM yyyy', 'es').format(lastFinishedAt.toLocal())}',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary),
                    ),
                  if (typicalMinutes != null)
                    Text(
                      '~$typicalMinutes min',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary),
                    ),
                ],
              );
              // Suggested workout owns the hero CTA above this list.
              final Widget? start = isSuggested
                  ? null
                  : FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Iniciar'),
                    );
              if (!sideBySide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    metadata,
                    if (start != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      start,
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: metadata),
                  if (start != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    start,
                  ],
                ],
              );
            },
          ),
        ],
      ),
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
