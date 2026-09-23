import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';

import '../../../core/theme/app_colors.dart';
import 'active_workout_page_web_content.dart' as workout_content;
import 'superset_manager_dialog_web.dart';
import 'unilateral_quick_editor_web.dart';

/// Capa ligera sobre la experiencia de entrenamiento web validada.
///
/// Mantiene el editor principal aislado y añade herramientas de escritorio:
/// superseries y Unilateral Pro con columnas I/D independientes.
class ActiveWorkoutPageWeb extends ConsumerWidget {
  const ActiveWorkoutPageWeb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeWorkoutProvider).session;
    final groupCount = session?.exercises
            .map((exercise) => exercise.supersetGroupId)
            .whereType<String>()
            .toSet()
            .length ??
        0;
    final canManage = (session?.exercises.length ?? 0) >= 2;
    final hasPendingUnilateral = session?.exercises.any(
          (exercise) =>
              exercise.unilateral && exercise.sets.any((set) => !set.completed),
        ) ??
        false;
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Stack(
      fit: StackFit.expand,
      children: [
        const workout_content.ActiveWorkoutPageWeb(),
        if (hasPendingUnilateral && !compact)
          const Positioned(
            left: 16,
            right: 180,
            bottom: 18,
            child: SafeArea(
              top: false,
              right: false,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: UnilateralQuickEditorWeb(),
              ),
            ),
          ),
        if (canManage)
          Positioned(
            right: 16,
            bottom: 18,
            child: SafeArea(
              top: false,
              left: false,
              child: compact
                  ? FloatingActionButton.small(
                      heroTag: 'web_superset_manager',
                      tooltip: groupCount == 0
                          ? 'Crear superserie'
                          : 'Superseries activas: $groupCount',
                      onPressed: () =>
                          SupersetManagerDialogWeb.show(context, ref),
                      child: Badge(
                        isLabelVisible: groupCount > 0,
                        label: Text('$groupCount'),
                        child: const Icon(Icons.link),
                      ),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () =>
                          SupersetManagerDialogWeb.show(context, ref),
                      icon: Badge(
                        isLabelVisible: groupCount > 0,
                        label: Text('$groupCount'),
                        child: const Icon(Icons.link),
                      ),
                      label: Text(
                        groupCount == 0
                            ? 'Superseries'
                            : 'Superseries · $groupCount',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: groupCount > 0
                            ? AppColors.primaryFaded
                            : AppColors.surfaceHigh,
                        foregroundColor: groupCount > 0
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}
