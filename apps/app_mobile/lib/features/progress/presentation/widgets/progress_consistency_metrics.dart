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
    final scale =
        (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);
    // Two separate values may require a full row each at 320px or 160%
    // text; never abbreviate real figures to maintain a rigid two-column UI.
    final minTileWidth = 148.0 * scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            (constraints.maxWidth >= minTileWidth * 2 + AppSpacing.sm)
                ? 2 : 1;
        final tileWidth = columns == 2
            ? (constraints.maxWidth - AppSpacing.sm) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            SizedBox(
              key: const ValueKey('consistency_weekly_tile'),
              width: tileWidth,
              child: _ConsistencyValue(
                label: 'ENTRENOS / SEM',
                spokenLabel: 'Entrenamientos por semana',
                value: workoutsPerWeek.toStringAsFixed(1),
              ),
            ),
            SizedBox(
              key: const ValueKey('consistency_duration_tile'),
              width: tileWidth,
              child: Tooltip(
                message: 'Promedio de duración registrada, incluidas pausas y '
                    'tiempo de una sesión abierta. No equivale a esfuerzo activo.',
                child: _ConsistencyValue(
                  label: 'MEDIA REGISTRADA',
                  spokenLabel: 'Duración media registrada',
                  spokenValue: '${averageSessionMinutes.round()} minutos',
                  value: '${averageSessionMinutes.round()}m',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConsistencyValue extends StatelessWidget {
  const _ConsistencyValue({
    required this.label,
    required this.value,
    required this.spokenLabel,
    this.spokenValue,
  });

  final String label;
  final String value;
  final String spokenLabel;
  final String? spokenValue;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      label: '$spokenLabel: ${spokenValue ?? value}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surfaceHigh,
            borderRadius: AppRadius.sm_,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                softWrap: true,
                style: AppTypography.headlineMedium.copyWith(
                  color: colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                softWrap: true,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
