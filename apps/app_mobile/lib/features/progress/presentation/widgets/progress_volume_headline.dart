import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_chart_style.dart';

/// Responsive volume KPI, shared format with chart tooltips.
class ProgressVolumeHeadline extends StatelessWidget {
  final double volumeKg;
  final WeightUnit weightUnit;
  final Widget? trailing;

  const ProgressVolumeHeadline({
    super.key,
    required this.volumeKg,
    required this.weightUnit,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final displayVolume =
        WeightConverter.displayWeight(volumeKg, weightUnit);
    final formatted = ProgressChartStyle.number(displayVolume);
    final unit = weightUnit.label.toUpperCase();

    return Semantics(
      label: 'Volumen total: ${ProgressChartStyle.measurement(displayVolume, weightUnit)}',
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatted,
                    key: const ValueKey('progress_total_volume_value'),
                    style: AppTypography.displayMedium.copyWith(
                      letterSpacing: -1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    unit,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            trailing!,
          ],
        ],
      ),
    );
  }
}
