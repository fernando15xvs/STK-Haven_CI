import 'package:core/features/progress/application/calendar_heatmap_calculator.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class CalendarHeatmapPanelWeb extends StatelessWidget {
  final CalendarHeatmapSnapshot snapshot;
  final String periodLabel;

  const CalendarHeatmapPanelWeb({
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;
              final title = Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryFaded,
                      borderRadius: AppRadius.md_,
                    ),
                    child: const Icon(
                      Icons.calendar_view_month_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calendario de actividad',
                          style: AppTypography.headlineLarge,
                        ),
                        Text(
                          '${_formatDate(snapshot.startDate)} – ${_formatDate(snapshot.endDate)} · $periodLabel',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final stats = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SummaryValueWeb(
                    value: '${snapshot.activeDays}',
                    label: 'DÍAS CON SESIÓN',
                  ),
                  const SizedBox(width: 8),
                  _SummaryValueWeb(
                    value: '${snapshot.totalWorkouts}',
                    label:
                        snapshot.totalWorkouts == 1 ? 'SESIÓN' : 'SESIONES',
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 14),
                    stats,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 16),
                  stats,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: _weekdayLabels
                      .map(
                        (label) => SizedBox(
                          width: 18,
                          height: 20,
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
                const SizedBox(width: 8),
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LegendDotWeb(active: false),
                  const SizedBox(width: 6),
                  Text('Sin sesión', style: AppTypography.labelSmall),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LegendDotWeb(active: true),
                  const SizedBox(width: 6),
                  Text('Con sesión', style: AppTypography.labelSmall),
                ],
              ),
              Text(
                'Una sesión guardada marca el día; el color no puntúa descanso, carga ni calidad.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(CalendarHeatmapDay day) {
    if (!day.isInPeriod) {
      return const SizedBox(width: 20, height: 20);
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
          width: 16,
          height: 16,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: day.isActive
                ? AppColors.primary.withValues(alpha: 0.82)
                : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: day.isActive ? AppColors.primary : AppColors.border,
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

class _SummaryValueWeb extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryValueWeb({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.md_,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTypography.headlineMedium),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.labelSmall),
        ],
      ),
    );
  }
}

class _LegendDotWeb extends StatelessWidget {
  final bool active;

  const _LegendDotWeb({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary.withValues(alpha: 0.82)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }
}
