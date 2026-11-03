import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// One controller for the three analytical tabs in Progreso.
/// Measurements intentionally use their own date ranges.
class ProgressSharedPeriodSelector extends ConsumerWidget {
  const ProgressSharedPeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(timeFilterProvider);
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceHigh,
          borderRadius: AppRadius.lg_,
          border: Border.all(color: colors.surfaceBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Text(
                  'PERÍODO',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.textSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                // Horizontal scrolling, rather than shrinking fonts, keeps
                // the four options legible at 320 px and text scale 1.6.
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<TimeFilter>(
                    key: const ValueKey('progress_shared_period'),
                    segments: const [
                      ButtonSegment(value: TimeFilter.week, label: Text('7D')),
                      ButtonSegment(value: TimeFilter.month, label: Text('1M')),
                      ButtonSegment(value: TimeFilter.threeMonths, label: Text('3M')),
                      ButtonSegment(value: TimeFilter.year, label: Text('1A')),
                    ],
                    selected: {filter},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        ref.read(timeFilterProvider.notifier)
                            .setFilter(selection.first);
                      }
                    },
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      textStyle: WidgetStatePropertyAll(
                        AppTypography.labelMedium),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? colors.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                      ),
                      side: const WidgetStatePropertyAll(BorderSide.none),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: AppRadius.md_),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
