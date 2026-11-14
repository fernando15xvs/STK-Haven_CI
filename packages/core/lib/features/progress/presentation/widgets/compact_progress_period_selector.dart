import 'package:core/core/theme/app_palette.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A compact, shared menu placed inside each analytical tab header.
/// The selected window is owned exclusively by timeFilterProvider.
class CompactProgressPeriodSelector extends ConsumerWidget {
  const CompactProgressPeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(timeFilterProvider);
    final colors = AppColors.of(context);
    return PopupMenuButton<TimeFilter>(
      key: const ValueKey('progress_shared_period'),
      tooltip: 'Seleccionar período de análisis',
      initialValue: selected,
      onSelected: (period) =>
          ref.read(timeFilterProvider.notifier).setFilter(period),
      itemBuilder: (_) => [
        for (final option in TimeFilter.values)
          PopupMenuItem<TimeFilter>(
            value: option,
            child: Text(option.label),
          ),
      ],
      child: Semantics(
        button: true,
        label: 'Período de análisis: ${selected.label}. Cambiar período',
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: colors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.surfaceBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined,
                  color: colors.textSecondary, size: 17),
              const SizedBox(width: 6),
              Text(
                selected.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: colors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
