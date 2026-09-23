import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/core/theme/components/primary_button.dart';
import 'package:gym_tracker/features/routines/presentation/pages/create_routine_page.dart';
import 'package:gym_tracker/features/routines/presentation/pages/routine_templates_page.dart';
import 'package:gym_tracker/features/workout/application/workout_launcher.dart';
import 'package:gym_tracker/features/workout/presentation/active_workout_page.dart';

class RoutinesPage extends ConsumerWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routineListProvider);
    final active = ref.watch(activeWorkoutProvider);
    final exercises = ref.watch(exerciseListProvider);
    final exerciseMap = {for (final exercise in exercises) exercise.id: exercise};

    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Rutinas', style: AppTypography.displaySmall),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Plantillas',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoutineTemplatesPage()),
            ),
          ),
          IconButton(
            tooltip: 'Plan semanal',
            icon: const Icon(Icons.calendar_view_week_outlined),
            onPressed: () => _showWeeklyPlan(context, ref, routines),
          ),
          IconButton(
            tooltip: 'Crear rutina',
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateRoutinePage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (active.isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: PremiumCard(
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                borderColor: AppColors.primary.withValues(alpha: 0.4),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ActiveWorkoutPage()),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fitness_center, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ENTRENAMIENTO EN CURSO',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            active.session?.routineNameSnapshot ?? 'Entrenamiento',
                            style: AppTypography.headlineMedium.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          Expanded(
            child: routines.isEmpty
                ? _EmptyState(
                    onCreate: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateRoutinePage()),
                    ),
                    onTemplates: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RoutineTemplatesPage()),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xxl,
                    ),
                    itemCount: routines.length,
                    itemBuilder: (context, index) {
                      final routine = routines[index];
                      final names = routine.exercises
                          .map(
                            (item) => exerciseMap[item.exerciseId]?.name ??
                                Exercise(id: '', name: 'Ejercicio eliminado', muscleGroup: '').name,
                          )
                          .toList(growable: false);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _RoutineCard(
                          routine: routine,
                          exerciseNames: names,
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
        ],
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
      backgroundColor: AppColors.surfaceHigh,
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
                  color: AppColors.textDisabled,
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
                hintText: 'Ej. Priorizar técnica, subir peso la próxima sesión...',
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
                  onPressed: () => Navigator.pop(sheetContext, controller.text.trim()),
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
    ref.read(routineListProvider.notifier).updateRoutine(
          routine.copyWith(notes: result),
        );
  }

  void _duplicateRoutine(BuildContext context, WidgetRef ref, Routine routine) {
    final copy = Routine(
      id: 'routine_${DateTime.now().microsecondsSinceEpoch}',
      name: '${routine.name} (copia)',
      scheduledDays: List<int>.from(routine.scheduledDays),
      exercises: routine.exercises.map((exercise) => exercise.copyWith()).toList(growable: false),
      createdAt: DateTime.now(),
      notes: routine.notes,
    );
    ref.read(routineListProvider.notifier).addRoutine(copy);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se creó “${copy.name}”.')),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('Eliminar rutina'),
        content: Text('¿Eliminar “${routine.name}”? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
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
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceHigh,
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
            Text('Plan semanal', style: AppTypography.headlineLarge),
            const SizedBox(height: 4),
            Text(
              'Usa el botón de mover para cambiar una rutina de día.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...List.generate(7, (index) {
              final weekday = index + 1;
              final dayRoutines = routines
                  .where(
                    (routine) => routine.scheduledDays.contains(weekday),
                  )
                  .toList(growable: false);
              final today = DateTime.now().weekday == weekday;
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: today ? AppColors.primaryFaded : AppColors.surface,
                  borderRadius: AppRadius.md_,
                  border: Border.all(
                    color: today
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.surfaceBorder,
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
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: dayRoutines.isEmpty
                          ? Text(
                              'Descanso',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textDisabled,
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
                                            sheetContext,
                                            ref,
                                            routine,
                                            weekday,
                                          ),
                                          icon: const Icon(
                                            Icons.swap_horiz,
                                            size: 20,
                                          ),
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
        .where(
          (day) =>
              day != fromDay && !routine.scheduledDays.contains(day),
        )
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
      backgroundColor: AppColors.surfaceHigh,
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
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...availableDays.map(
              (day) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primary,
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
        content: Text(
          '“${routine.name}” se movió a ${days[destination - 1]}.',
        ),
      ),
    );
  }

}

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final List<String> exerciseNames;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onNotes;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _RoutineCard({
    required this.routine,
    required this.exerciseNames,
    required this.onStart,
    required this.onEdit,
    required this.onNotes,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Stack(
      children: [
        PremiumCard(
          onTap: onStart,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 34),
                child: Text(routine.name, style: AppTypography.headlineLarge),
              ),
              const SizedBox(height: 4),
              Text('${routine.exercises.length} ejercicios', style: AppTypography.bodyMedium),
              if (routine.hasNotes) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFaded,
                    borderRadius: AppRadius.sm_,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          routine.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (exerciseNames.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  exerciseNames.take(3).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      children: List.generate(7, (index) {
                        final selected = routine.scheduledDays.contains(index + 1);
                        return Container(
                          width: 23,
                          height: 23,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.18)
                                : AppColors.surfaceHigh,
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.45)
                                  : AppColors.surfaceBorder,
                            ),
                          ),
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: selected ? AppColors.primary : AppColors.textDisabled,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: PopupMenuButton<String>(
            tooltip: 'Opciones',
            color: AppColors.surfaceHigh,
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'notes') onNotes();
              if (value == 'duplicate') onDuplicate();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar'), dense: true)),
              PopupMenuItem(value: 'notes', child: ListTile(leading: Icon(Icons.sticky_note_2_outlined), title: Text('Nota'), dense: true)),
              PopupMenuItem(value: 'duplicate', child: ListTile(leading: Icon(Icons.copy_all_outlined), title: Text('Duplicar'), dense: true)),
              PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: AppColors.error), title: Text('Eliminar'), dense: true)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onTemplates;

  const _EmptyState({required this.onCreate, required this.onTemplates});

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
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('No tienes rutinas aún', style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Crea una desde cero o parte de una plantilla.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: 'CREAR RUTINA', onPressed: onCreate),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onTemplates,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('VER PLANTILLAS'),
            ),
          ],
        ),
      ),
    );
  }
}
