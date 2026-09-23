import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';

import '../../../core/theme/app_colors.dart';

class SupersetManagerDialogWeb {
  const SupersetManagerDialogWeb._();

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final session = ref.read(activeWorkoutProvider).session;
    if (session == null) return;
    if (session.exercises.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Necesitas al menos dos ejercicios para crear una superserie.',
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(activeWorkoutProvider).session;
          if (current == null) return const SizedBox.shrink();

          final groups = <String, List<int>>{};
          for (var index = 0; index < current.exercises.length; index++) {
            final groupId = current.exercises[index].supersetGroupId;
            if (groupId != null) {
              groups.putIfAbsent(groupId, () => <int>[]).add(index);
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.link, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Superseries'),
              ],
            ),
            content: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entrena A → B y descansa al cerrar la ronda. El descanso usa el mayor tiempo configurado entre los dos ejercicios.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (groups.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: AppRadius.md_,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Todavía no has creado superseries en esta sesión.',
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView(
                        shrinkWrap: true,
                        children: groups.entries.map((entry) {
                          final indexes = entry.value;
                          if (indexes.isEmpty) return const SizedBox.shrink();
                          final names = indexes
                              .map(
                                (index) => current
                                    .exercises[index].exerciseNameSnapshot,
                              )
                              .join('  +  ');
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryFaded,
                              borderRadius: AppRadius.md_,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.link,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    names,
                                    style: AppTypography.bodyMedium,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Quitar superserie',
                                  onPressed: () => ref
                                      .read(activeWorkoutProvider.notifier)
                                      .removeSuperset(indexes.first),
                                  icon: const Icon(
                                    Icons.link_off,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context, ref, current),
                icon: const Icon(Icons.add_link),
                label: const Text('Crear superserie'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    WorkoutSession session,
  ) async {
    if (session.exercises.length < 2) return;
    var firstIndex = 0;
    var secondIndex = 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Crear superserie'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona dos ejercicios. Si alguno ya pertenecía a otra superserie, se liberará su grupo anterior.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: firstIndex,
                  decoration: const InputDecoration(labelText: 'Ejercicio A'),
                  items: List.generate(
                    session.exercises.length,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(
                        session.exercises[index].exerciseNameSnapshot,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      firstIndex = value;
                      if (secondIndex == firstIndex) {
                        secondIndex = firstIndex == 0 ? 1 : 0;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey('second-$firstIndex-$secondIndex'),
                  initialValue: secondIndex,
                  decoration: const InputDecoration(labelText: 'Ejercicio B'),
                  items: List.generate(session.exercises.length, (index) => index)
                      .where((index) => index != firstIndex)
                      .map(
                        (index) => DropdownMenuItem(
                          value: index,
                          child: Text(
                            session.exercises[index].exerciseNameSnapshot,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => secondIndex = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.link),
              label: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      ref
          .read(activeWorkoutProvider.notifier)
          .createSuperset(firstIndex, secondIndex);
    }
  }
}
