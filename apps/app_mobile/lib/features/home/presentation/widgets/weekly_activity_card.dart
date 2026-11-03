import 'package:core/domain/models/workout_session.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';

/// Inicio muestra el ritmo semanal. El análisis numérico vive en Progreso.
class WeeklyActivityCard extends StatelessWidget {
  const WeeklyActivityCard({
    super.key,
    required this.history,
    required this.onOpenProgress,
    this.referenceDate,
  });

  final List<WorkoutSession> history;
  final VoidCallback onOpenProgress;

  /// An injectable date keeps the weekday tests deterministic.
  final DateTime? referenceDate;

  @override
  Widget build(BuildContext context) {
    final now = referenceDate ?? DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final trainedDays = <int>{
      for (final session in history)
        // Match Progreso's calendar: group activity by the recorded
        // completion day, including sessions that cross midnight.
        if (!session.finishedAt.isBefore(startOfWeek) &&
            !session.finishedAt.isAfter(now))
          session.finishedAt.weekday,
    };
    const initials = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    const fullNames = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ESTA SEMANA',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PremiumCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final weekday = index + 1;
                  final trained = trainedDays.contains(weekday);
                  final today = weekday == now.weekday;
                  return Semantics(
                    label: '${fullNames[index]}: ${trained ? 'entrenamiento registrado' : today ? 'hoy, sin entrenamiento registrado' : 'sin entrenamiento registrado'}',
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          Text(initials[index],
                              style: AppTypography.labelSmall),
                          const SizedBox(height: AppSpacing.xs),
                          AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : AppMotion.fast,
                            width: 31,
                            height: 31,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: trained
                                  ? AppColors.of(context).primary
                                  : Colors.transparent,
                              border: Border.all(
                                color: trained
                                    ? AppColors.of(context).primary
                                    : today
                                        ? AppColors.of(context).primary
                                            .withValues(alpha: 0.65)
                                        : AppColors.of(context).surfaceBorder,
                              ),
                            ),
                            child: trained
                                ? Icon(Icons.check,
                                    size: 15,
                                    color: AppColors.of(context).onPrimary)
                                : today
                                    ? Icon(Icons.circle,
                                        size: 7,
                                        color: AppColors.of(context).primary)
                                    : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('home_open_progress'),
                  onPressed: onOpenProgress,
                  icon: const Icon(Icons.insights_outlined, size: 18),
                  label: const Text('Ver análisis en Progreso'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
