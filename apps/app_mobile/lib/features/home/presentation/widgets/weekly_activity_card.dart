import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';

/// Inicio: a lightweight pointer to Progreso, not a second activity calendar.
class WeeklyActivityCard extends StatelessWidget {
  const WeeklyActivityCard({
    super.key,
    required this.history,
    required this.onOpenProgress,
    this.referenceDate,
  });

  final List<WorkoutSession> history;
  final VoidCallback onOpenProgress;
  final DateTime? referenceDate;

  @override
  Widget build(BuildContext context) {
    final now = referenceDate ?? DateTime.now();
    final localNow = now.toLocal();
    final monday = DateTime(localNow.year, localNow.month, localNow.day)
        .subtract(Duration(days: localNow.weekday - DateTime.monday));
    // Same completion-date and effective-work eligibility as Progreso.
    final days = <DateTime>{
      for (final session in history)
        if (isRecordedTrainingActivityAsOf(session, now) &&
            !session.finishedAt.toLocal().isBefore(monday))
          DateUtils.dateOnly(session.finishedAt.toLocal()),
    };
    final activeDays = days.length;
    final summary = activeDays == 0
        ? 'Aún no tienes actividad registrada esta semana.'
        : activeDays == 1
            ? '1 día con entrenamiento esta semana.'
            : '$activeDays días con entrenamiento esta semana.';

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: AppColors.of(context).primary,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACTIVIDAD SEMANAL', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      summary,
                      key: const ValueKey('home_weekly_active_days'),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
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
    );
  }
}
