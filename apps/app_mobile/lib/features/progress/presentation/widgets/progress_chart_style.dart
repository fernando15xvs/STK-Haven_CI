import 'dart:math' as math;

import 'package:core/domain/models/settings_state.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

/// Shared chart tokens: use Outfit and semantic colors in both themes.
class ProgressChartStyle {
  ProgressChartStyle._();

  static TextStyle axisText(BuildContext context) =>
      AppTypography.labelLarge.copyWith(
        color: AppColors.of(context).textSecondary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle tooltipText(BuildContext context) =>
      AppTypography.bodyMedium.copyWith(
        color: AppColors.of(context).textPrimary,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// A shared tooltip size avoids clipped date/weight at 160% text scale.
  static const double tooltipMaxContentWidth = 184;
  static const double tooltipMargin = 14;
  static const EdgeInsets tooltipPadding =
      EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs);

  /// Shared selection indicator: a neutral dashed vertical guide and an
  /// outlined point visible on bright/dark/OLED surfaces. The tooltip stays
  /// offset from the touched point instead of hiding its position.
  static List<TouchedSpotIndicatorData> selectedIndicators(
    BuildContext context,
    List<int> indexes,
  ) => [
        for (var i = 0; i < indexes.length; i++)
          TouchedSpotIndicatorData(
            FlLine(
              color: AppColors.of(context).textSecondary,
              strokeWidth: 1.5,
              dashArray: const [4, 4],
            ),
            FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 5,
                color: AppColors.of(context).surfaceHigh,
                strokeWidth: 2.5,
                strokeColor: AppColors.of(context).primary,
              ),
            ),
          ),
      ];

  static Color tooltipBackground(BuildContext context) =>
      AppColors.of(context).surfaceHigh;

  static Color gridColor(BuildContext context) =>
      AppColors.of(context).surfaceBorder.withValues(alpha: 0.7);

  static String date(DateTime date) =>
      DateFormat('d MMM', 'es').format(date);

  static String detailedDate(DateTime date) =>
      DateFormat('d MMM yyyy', 'es').format(date);

  static String calendarMonth(DateTime date) =>
      DateFormat('MMM yyyy', 'es').format(date);

  static String number(double value) {
    final formatter = NumberFormat.decimalPattern('es')
      ..maximumFractionDigits = 1;
    return formatter.format(value);
  }

  static String measurement(double value, WeightUnit unit) =>
      '${number(value)} ${unit.label}';

  /// Days on the horizontal axis, preserving gaps between real dates.
  static double elapsedDays(DateTime date, DateTime first) =>
      date.difference(first).inMilliseconds /
      Duration.millisecondsPerDay;

  /// Account for flat curves and reserve vertical space for selected values.
  /// Call with values ALREADY converted to the requested display unit.
  static ProgressChartBounds bounds(
    Iterable<double> displayValues, {
    bool includeZero = false,
  }) {
    final values =
        displayValues.where((value) => value.isFinite).toList(growable: false);
    if (values.isEmpty) return const ProgressChartBounds(0, 1);
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    if (includeZero) {
      return ProgressChartBounds(0.0, math.max(1.0, highest) * 1.18);
    }
    final range = highest - lowest;
    final padding =
        range > 0 ? range * 0.18 : math.max(1.0, highest.abs() * 0.08);
    final minimum = math.max(0.0, lowest - padding);
    final maximum = highest + padding;
    return ProgressChartBounds(minimum, math.max(minimum + 0.01, maximum));
  }
}

@immutable
class ProgressChartBounds {
  const ProgressChartBounds(this.minY, this.maxY);
  final double minY;
  final double maxY;
}
