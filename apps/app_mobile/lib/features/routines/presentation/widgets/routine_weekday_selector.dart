import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Accessible weekday selector shared by standalone-routine scheduling.
/// At <= 320dp available screen width it uses four + three 44dp targets.
class RoutineWeekdaySelector extends StatelessWidget {
  const RoutineWeekdaySelector({
    super.key,
    required this.selectedDays,
    required this.onDayTapped,
  });

  final Set<int> selectedDays;
  final ValueChanged<int> onDayTapped;

  static const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const fullNames = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves',
    'Viernes', 'Sábado', 'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const daySize = 44.0;
        final compact = constraints.maxWidth < 7 * daySize + 6 * gap;
        final compactCellWidth = (constraints.maxWidth - 3 * gap) / 4;
        final buttons = List.generate(7, (index) {
          final day = index + 1;
          final selected = selectedDays.contains(day);
          return SizedBox(
            width: compact ? compactCellWidth : daySize,
            child: Center(
              child: Semantics(
                button: true,
                selected: selected,
                label: fullNames[index],
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onDayTapped(day),
                  child: Container(
                    width: daySize,
                    height: daySize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppColors.of(context).primary
                          : AppColors.of(context).surfaceHigh,
                      border: Border.all(
                        color: selected
                            ? AppColors.of(context).primary
                            : AppColors.of(context).border,
                      ),
                    ),
                    child: Text(
                      labels[index],
                      style: AppTypography.labelLarge.copyWith(
                        color: selected
                            ? AppColors.of(context).onPrimary
                            : AppColors.of(context).textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
        return compact
            ? Wrap(spacing: gap, runSpacing: gap, children: buttons)
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: buttons,
              );
      },
    );
  }
}
