import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../workout/presentation/active_workout_page_web.dart';
import 'create_routine_page_web.dart';
import 'routine_templates_page_web.dart';

class RoutinesPageWeb extends ConsumerWidget {
  const RoutinesPageWeb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routineListProvider);
    final exercises = ref.watch(exerciseListProvider);
    final active = ref.watch(activeWorkoutProvider);
    final exerciseMap = {for (final exercise in exercises) exercise.id: exercise};

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: _Header(
                      onTemplates: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RoutineTemplatesPageWeb()),
                      ),
                      onPlan: () => _showWeeklyPlan(context, ref, routines),
                      onCreate: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CreateRoutinePageWeb()),
                      ),
                    ),
                  ),
                ),
                if (active.isActive)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    sliver: SliverToBoxAdapter(
                      child: _ActiveWorkoutBanner(
                        name: active.routineDisplayName,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ActiveWorkoutPageWeb()),
                        ),
                      ),
                    ),
                  ),
                if (routines.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      onCreate: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CreateRoutinePageWeb()),
                      ),
                      onTemplates: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RoutineTemplatesPageWeb()),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final columns = width >= 1050 ? 3 : width >= 680 ? 2 : 1;
                        return SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: columns == 1 ? 1.85 : 1.45,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final routine = routines[index];
                              final names = routine.exercises
                                  .map((item) => exerciseMap[item.exerciseId]?.name ?? 'Ejercicio eliminado')
                                  .toList(growable: false);
                              return _RoutineCard(
                                routine: routine,
                                exerciseNames: names,
                                onStart: () => _launchWorkout(context, ref, routine, exercises),
                                onEdit: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CreateRoutinePageWeb(editingRoutine: routine),
                                  ),
                                ),
                                onNotes: () => _editRoutineNotes(context, ref, routine),
                                onDuplicate: () => _duplicateRoutine(context, ref, routine),
                                onDelete: () => _confirmDelete(context, ref, routine),
                              );
                            },
                            childCount: routines.length,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchWorkout(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
    List<Exercise> exercises,
  ) async {
    final active = ref.read(activeWorkoutProvider);
    if (active.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya tienes un entrenamiento en curso. Ábrelo o finalízalo antes de iniciar otro.'),
        ),
      );
      return;
    }
    ref.read(activeWorkoutProvider.notifier).startWorkout(routine, exercises);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutPageWeb()),
    );
  }

  Future<void> _editRoutineNotes(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    final controller = TextEditingController(text: routine.notes);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Nota de la rutina'),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: routine.name,
              hintText: 'Ej. Priorizar técnica, subir peso la próxima sesión...',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          if (routine.hasNotes)
            TextButton.icon(
              onPressed: () => Navigator.pop(dialogContext, ''),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Borrar nota'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
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
        title: const Text('Eliminar rutina'),
        content: Text('¿Eliminar “${routine.name}”? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('Plan semanal'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecciona una rutina para moverla a otro día.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(7, (index) {
                  final weekday = index + 1;
                  final today = DateTime.now().weekday == weekday;
                  final dayRoutines = routines
                      .where(
                        (routine) =>
                            routine.scheduledDays.contains(weekday),
                      )
                      .toList(growable: false);
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: today
                          ? AppColors.primaryFaded
                          : AppColors.surface,
                      borderRadius: AppRadius.md_,
                      border: Border.all(
                        color: today
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 105,
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
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: dayRoutines
                                      .map(
                                        (routine) => Tooltip(
                                          message: 'Mover a otro día',
                                          child: ActionChip(
                                            avatar: const Icon(
                                              Icons.swap_horiz,
                                              size: 16,
                                            ),
                                            label: Text(routine.name),
                                            onPressed: () =>
                                                _moveRoutineToDay(
                                              dialogContext,
                                              ref,
                                              routine,
                                              weekday,
                                            ),
                                          ),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
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

    final destination = await showDialog<int>(
      context: planContext,
      builder: (destinationContext) => AlertDialog(
        title: const Text('Mover rutina'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${routine.name} · desde ${days[fromDay - 1]}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(destinationContext),
            child: const Text('Cancelar'),
          ),
        ],
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

class _Header extends StatelessWidget {
  final VoidCallback onTemplates;
  final VoidCallback onPlan;
  final VoidCallback onCreate;

  const _Header({
    required this.onTemplates,
    required this.onPlan,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 660;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mis rutinas', style: AppTypography.displaySmall),
                  const SizedBox(height: 4),
                  Text(
                    'Crea, organiza y comienza tus entrenamientos.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (compact) ...[
              IconButton.outlined(
                tooltip: 'Plantillas',
                onPressed: onTemplates,
                icon: const Icon(Icons.auto_awesome_outlined),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: 'Plan semanal',
                onPressed: onPlan,
                icon: const Icon(Icons.calendar_view_week_outlined),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: onTemplates,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Plantillas'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onPlan,
                icon: const Icon(Icons.calendar_view_week_outlined),
                label: const Text('Plan semanal'),
              ),
            ],
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(compact ? 'Crear' : 'Crear rutina'),
            ),
          ],
        );
      },
    );
  }
}

class _ActiveWorkoutBanner extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _ActiveWorkoutBanner({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: AppRadius.lg_,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lg_,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lg_,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            boxShadow: AppElevation.accent,
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ENTRENAMIENTO EN CURSO',
                      style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(name, style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
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
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fitness_center,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 18),
              Text('Aún no tienes rutinas', style: AppTypography.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Crea una desde cero o empieza con una plantilla lista para personalizar.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onTemplates,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Ver plantillas'),
                  ),
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Crear rutina'),
                  ),
                ],
              ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  routine.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineLarge,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones',
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
            ],
          ),
          Text(
            '${routine.exercises.length} ejercicios',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          if (routine.hasNotes) ...[
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
                  const Icon(Icons.sticky_note_2_outlined, size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
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
            const SizedBox(height: 9),
          ],
          Expanded(
            child: Text(
              exerciseNames.isEmpty ? 'Sin ejercicios' : exerciseNames.take(4).join(' · '),
              maxLines: routine.hasNotes ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  children: List.generate(7, (index) {
                    final selected = routine.scheduledDays.contains(index + 1);
                    return Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.16)
                            : AppColors.surfaceHigh,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              IconButton.filled(
                tooltip: 'Comenzar entrenamiento',
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
