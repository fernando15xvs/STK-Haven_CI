import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

import 'package:core/core/constants/preset_exercises.dart';
import 'package:core/domain/models/preset_program.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/features/onboarding/application/program_service.dart';

enum ProgramPreviewMode { install, preview }

class ProgramPreviewModal extends ConsumerWidget {
  final PresetProgram program;
  final ProgramPreviewMode mode;

  const ProgramPreviewModal({
    super.key,
    required this.program,
    this.mode = ProgramPreviewMode.install,
  });

  Exercise? _getExercise(String id) {
    try {
      return presetExercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalExercises = program.routines.fold<int>(
      0,
      (sum, r) => sum + r.exercises.length,
    );

    // Estimate minutes
    int estimatedSeconds = 0;
    for (final routine in program.routines) {
      for (final ex in routine.exercises) {
        // Average 45s per set + rest
        estimatedSeconds += ex.targetSets * (45 + ex.restSeconds);
      }
    }
    final avgMinutes = program.routines.isEmpty
        ? 0
        : (estimatedSeconds / program.routines.length / 60).round();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.of(context).background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.of(context).surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              children: [
                Text(
                  program.name,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(context).textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${program.daysPerWeek} días / semana • ${program.level}',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.of(context).primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  program.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.of(context).textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Summary Stats
                Row(
                  children: [
                    _buildStatCard(
                      context,
                      '${program.routines.length}',
                      'Rutinas',
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _buildStatCard(context, '$totalExercises', 'Ejercicios'),
                    const SizedBox(width: AppSpacing.md),
                    _buildStatCard(context, '~$avgMinutes', 'Minutos'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Routines List
                Text(
                  'RUTINAS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(context).textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                ...program.routines.map(
                  (routine) => _buildRoutineCard(context, routine),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),

          // Bottom CTA
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              border: Border(
                top: BorderSide(color: AppColors.of(context).surfaceBorder),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: mode == ProgramPreviewMode.install
                    ? ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context); // Close modal
                          await ref
                              .read(programServiceProvider)
                              .installProgram(program);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.of(context).primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Instalar Programa',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.of(context).primary,
                          side: BorderSide(
                            color: AppColors.of(context).primary,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cerrar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.of(context).surfaceBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.of(context).textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.of(context).textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineCard(BuildContext context, PresetRoutine routine) {
    const daysMap = {
      1: 'Lunes',
      2: 'Martes',
      3: 'Miércoles',
      4: 'Jueves',
      5: 'Viernes',
      6: 'Sábado',
      7: 'Domingo',
    };
    final daysStr = routine.scheduledDays.map((d) => daysMap[d]).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.of(context).textPrimary,
          collapsedIconColor: AppColors.of(context).textSecondary,
          title: Text(
            routine.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.of(context).textPrimary,
            ),
          ),
          subtitle: Text(
            daysStr,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.of(context).primary,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                children: routine.exercises.map((ex) {
                  final exerciseData = _getExercise(ex.exerciseId);
                  final name = exerciseData?.name ?? 'Ejercicio';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '•',
                          style: TextStyle(
                            color: AppColors.of(context).textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: AppColors.of(context).textPrimary,
                                ),
                              ),
                              Text(
                                '${ex.targetSets} × ${ex.targetRepsMin}-${ex.targetRepsMax} reps',
                                style: TextStyle(
                                  color: AppColors.of(context).textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
    );
  }
}
