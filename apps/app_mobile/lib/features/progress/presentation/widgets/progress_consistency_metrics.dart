import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Resumen: frequency and duration only. Active days live in the calendar.
class ProgressConsistencyMetrics extends StatelessWidget {
  const ProgressConsistencyMetrics({
    super.key,
    required this.workoutsPerWeek,
    required this.averageSessionMinutes,
  });

  final double workoutsPerWeek;
  final double averageSessionMinutes;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ConsistencyValue(
            label: 'ENTRENOS / SEM',
            value: workoutsPerWeek.toStringAsFixed(1),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Tooltip(
            message: 'Promedio de duración registrada, incluidas pausas y '
                'tiempo de una sesión abierta. No equivale a esfuerzo activo.',
            child: _ConsistencyValue(
              label: 'MEDIA REGISTRADA',
              value: '${averageSessionMinutes.round()}m',
            ),
          ),
        ),
      ],
    );
  }
}

class _ConsistencyValue extends StatelessWidget {
  const _ConsistencyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceHigh,
        borderRadius: AppRadius.sm_,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.headlineMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
