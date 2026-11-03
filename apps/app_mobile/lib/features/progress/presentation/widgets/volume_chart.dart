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

  const VolumeChart({super.key, required this.data, required this.weightUnit});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
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

    final sorted = [...data]..sort((a, b) => a.date.compareTo(b.date));
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

    return Semantics(
      label: 'Volumen de entrenamiento: ${ProgressChartStyle.detailedDate(first)}'
          ' a ${ProgressChartStyle.detailedDate(last)}',
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
                      getTooltipColor: (_) =>
                          ProgressChartStyle.tooltipBackground(context),
                      getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                        final selected = displayData[spot.spotIndex];
                        return LineTooltipItem(
                          '${ProgressChartStyle.detailedDate(selected.date)}\n'
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
                        ProgressChartStyle.date(first),
                        style: ProgressChartStyle.axisText(context),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ProgressChartStyle.date(first),
                            style: ProgressChartStyle.axisText(context)),
                        Text(ProgressChartStyle.date(last),
                            style: ProgressChartStyle.axisText(context)),
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
