import 'package:core/features/programs/presentation/pages/training_programs_page.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/application/workout_launcher.dart';

import 'dashboard_page.dart';

class ProgramDashboardPage extends ConsumerWidget {
  const ProgramDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextProgramSessionProvider);
    if (next == null) return const DashboardPage();

    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, 0),
          child: Material(
            color: AppColors.surface,
            borderRadius: AppRadius.lg_,
            child: InkWell(
              borderRadius: AppRadius.lg_,
              onTap: () => WorkoutLauncher.launch(context, ref, next.routine),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.lg_,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primaryFaded,
                        borderRadius: AppRadius.md_,
                      ),
                      child: const Icon(
                        Icons.skip_next_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SIGUIENTE SESIÓN · ${next.program.name}',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            next.routine.name,
                            style: AppTypography.headlineMedium,
                          ),
                          Text(
                            'Semana ${next.week}${next.isDeloadWeek ? ' · Descarga' : ''}',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Gestionar programas',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrainingProgramsPage(),
                        ),
                      ),
                      icon: const Icon(Icons.layers_outlined),
                    ),
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: const DashboardPage(),
          ),
        ),
      ],
    );
  }
}
