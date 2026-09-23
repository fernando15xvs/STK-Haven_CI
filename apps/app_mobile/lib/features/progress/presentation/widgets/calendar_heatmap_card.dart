import 'package:core/features/progress/application/calendar_heatmap_calculator.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

class CalendarHeatmapCard extends StatelessWidget {
  final CalendarHeatmapSnapshot snapshot;
  final String periodLabel;

  const CalendarHeatmapCard({
    super.key,
    required this.snapshot,
    required this.periodLabel,
  });

  static const _weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  @override
  Widget build(BuildContext context) {
    final weeks = <List<CalendarHeatmapDay>>[];
    for (var index = 0; index < snapshot.days.length; index += 7) {
      weeks.add(snapshot.days.sublist(index, index + 7));
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: AppElevation.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryFaded,
                  borderRadius: AppRadius.sm_,
                ),
                child: const Icon(
                  Icons.calendar_view_month_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CALENDARIO DE ACTIVIDAD',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${_formatDate(snapshot.startDate)} – ${_formatDate(snapshot.endDate)} · $periodLabel',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _SummaryValue(
                value: '${snapshot.activeDays}',
                label: 'DÍAS CON SESIÓN',
              ),
              const SizedBox(width: AppSpacing.sm),
              _SummaryValue(
                value: '${snapshot.totalWorkouts}',
                label: snapshot.totalWorkouts == 1 ? 'SESIÓN' : 'SESIONES',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 126,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: _weekdayLabels
                      .map(
                        (label) => SizedBox(
                          width: 16,
                          height: 18,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              label,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textDisabled,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    reverse: true,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: weeks
                          .map(
                            (week) => Column(
                              children: week
                                  .map(_buildDayCell)
                                  .toList(growable: false),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _LegendDot(active: false),
              const SizedBox(width: 5),
              Text('Sin sesión', style: AppTypography.labelSmall),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(active: true),
              const SizedBox(width: 5),
              Text('Con sesión', style: AppTypography.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cada cuadro marca un día con al menos una sesión guardada. No puntúa descanso, carga ni calidad.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(CalendarHeatmapDay day) {
    if (!day.isInPeriod) {
      return const SizedBox(width: 18, height: 18);
    }

    final label = day.workoutCount == 0
        ? '${_formatDate(day.date)} · sin sesión'
        : '${_formatDate(day.date)} · ${day.workoutCount} ${day.workoutCount == 1 ? 'sesión' : 'sesiones'}';

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: day.isActive
                ? AppColors.primary.withValues(alpha: 0.82)
                : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: day.isActive
                  ? AppColors.primary
                  : AppColors.surfaceBorder,
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }
}

class _SummaryValue extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryValue({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: AppRadius.sm_,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTypography.headlineMedium),
            const SizedBox(height: 2),
            Text(label, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final bool active;

  const _LegendDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary.withValues(alpha: 0.82)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.surfaceBorder,
        ),
      ),
    );
  }
}
