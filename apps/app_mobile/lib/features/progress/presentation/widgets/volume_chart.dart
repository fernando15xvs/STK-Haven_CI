import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
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
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('Sin datos en este periodo',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    // Convert all canonical kg volumes to the active display unit for the chart
    final displayData = data
        .map((e) => _DisplayPoint(e.date, WeightConverter.displayWeight(e.volume, weightUnit)))
        .toList();

    final maxY = displayData.map((e) => e.volume).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppColors.surfaceHigh, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value == displayData.length - 1) {
                    final date = displayData[value.toInt()].date;
                    return Text(
                      '${date.day}/${date.month}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (displayData.length - 1).toDouble(),
          minY: 0,
          maxY: maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: displayData
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.volume))
                  .toList(),
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.2),
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
