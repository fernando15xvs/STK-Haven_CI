import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_chart_style.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';

class VolumeChart extends StatelessWidget {
  final List<VolumeDataPoint> data;
  final WeightUnit weightUnit;
  /// Identifies whether dots represent days, 7-day buckets or calendar months.
  /// Null preserves day-level labels for callers outside the shared dashboard.
  final TimeFilter? period;

  const VolumeChart({
    super.key,
    required this.data,
    required this.weightUnit,
    this.period,
  });

  String _dateLabel(DateTime date, {bool detailed = false}) {
    if (period == TimeFilter.year) {
      final month = ProgressChartStyle.calendarMonth(date);
      return detailed ? 'Mes de $month' : month;
    }
    if (period == TimeFilter.threeMonths) {
      final start = detailed
          ? ProgressChartStyle.detailedDate(date)
          : ProgressChartStyle.date(date);
      return detailed ? 'Semana desde el $start' : 'Sem. $start';
    }
    return detailed
        ? ProgressChartStyle.detailedDate(date)
        : ProgressChartStyle.date(date);
  }

  @override
  Widget build(BuildContext context) {
    // The provider already aggregates periods, but this widget is public to
    // callers with raw points. Coalesce same-day entries and ignore invalid
    // imported values so fl_chart never receives duplicate X or NaN/Inf.
    final byDay = <DateTime, double>{};
    for (final point in data) {
      if (!point.volume.isFinite || point.volume < 0) continue;
      final day = DateTime(point.date.year, point.date.month, point.date.day);
      byDay.update(
        day,
        (current) => current + point.volume,
        ifAbsent: () => point.volume,
      );
    }
    if (byDay.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Sin datos en este periodo',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ),
      );
    }

    final sorted = [
      for (final item in byDay.entries) VolumeDataPoint(item.key, item.value),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final displayData = sorted
        .map((point) => _DisplayPoint(
              point.date,
              WeightConverter.displayWeight(point.volume, weightUnit),
            ))
        .toList(growable: false);
    final first = displayData.first.date;
    final last = displayData.last.date;
    final spots = [
      for (final point in displayData)
        FlSpot(ProgressChartStyle.elapsedDays(point.date, first), point.volume),
    ];
    final maxX = spots.last.x;
    final xPadding = math.max(0.65, maxX * 0.045);
    final yBounds = ProgressChartStyle.bounds(
      displayData.map((point) => point.volume),
      includeZero: true,
    );
    final peak = displayData.reduce(
      (a, b) => a.volume >= b.volume ? a : b,
    );

    return Semantics(
      label: 'Volumen de entrenamiento: ${_dateLabel(first, detailed: true)}'
          ' a ${_dateLabel(last, detailed: true)}. '
          'Máximo mostrado: ${ProgressChartStyle.measurement(peak.volume, weightUnit)}'
          ' en ${_dateLabel(peak.date, detailed: true)}.',
      child: SizedBox(
        height: 200,
        child: Column(
          children: [
            Expanded(
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      maxContentWidth: ProgressChartStyle.tooltipMaxContentWidth,
                      tooltipPadding: ProgressChartStyle.tooltipPadding,
                      getTooltipColor: (_) =>
                          ProgressChartStyle.tooltipBackground(context),
                      getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                        final selected = displayData[spot.spotIndex];
                        return LineTooltipItem(
                          '${_dateLabel(selected.date, detailed: true)}\n'
                          '${ProgressChartStyle.measurement(selected.volume, weightUnit)}',
                          ProgressChartStyle.tooltipText(context),
                        );
                      }).toList(growable: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: ProgressChartStyle.gridColor(context),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: -xPadding,
                  maxX: maxX + xPadding,
                  minY: yBounds.minY,
                  maxY: yBounds.maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false, // Do not overshoot extreme daily volumes.
                      color: AppColors.of(context).primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: displayData.length <= 45),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.of(context)
                            .primary.withValues(alpha: 0.14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: displayData.length == 1
                  ? Center(
                      child: Text(
                        _dateLabel(first),
                        style: ProgressChartStyle.axisText(context),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _dateLabel(first),
                            maxLines: 2,
                            textAlign: TextAlign.start,
                            style: ProgressChartStyle.axisText(context),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _dateLabel(last),
                            maxLines: 2,
                            textAlign: TextAlign.end,
                            style: ProgressChartStyle.axisText(context),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplayPoint {
  final DateTime date;
  final double volume;
  const _DisplayPoint(this.date, this.volume);
}
