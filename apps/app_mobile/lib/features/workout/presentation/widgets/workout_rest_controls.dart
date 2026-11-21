import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Compact, in-flow rest controls. No countdown progress is fabricated:
/// the remaining seconds come solely from activeWorkoutProvider.
class WorkoutRestControls extends StatelessWidget {
  const WorkoutRestControls({
    super.key,
    required this.remainingSeconds,
    required this.onSkip,
    required this.onAdd15,
    required this.onAdd30,
    required this.onCustomize,
  });

  final int remainingSeconds;
  final VoidCallback onSkip;
  final VoidCallback onAdd15;
  final VoidCallback onAdd30;
  final VoidCallback onCustomize;

  String get formattedTime {
    final safe = remainingSeconds < 0 ? 0 : remainingSeconds;
    final minutes = (safe ~/ 60).toString().padLeft(2, '0');
    final seconds = (safe % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textStyle = AppTypography.labelMedium.copyWith(
      color: palette.primary,
    );
    final actionStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.compact,
    );

    return Container(
      key: const ValueKey('rest_banner'),
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: AppRadius.md_,
        border: Border.all(
          color: palette.surfaceBorder.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: palette.warning, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 7,
                  children: [
                    Text(
                      'Descanso',
                      style: AppTypography.labelMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    Text(
                      formattedTime,
                      key: const ValueKey('workout_rest_countdown'),
                      style: AppTypography.headlineSmall.copyWith(
                        color: palette.warning,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onSkip,
                style: actionStyle,
                child: Text('Omitir', style: textStyle),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            runSpacing: 0,
            children: [
              TextButton(
                onPressed: onAdd15,
                style: actionStyle,
                child: Text('+15 s', style: textStyle),
              ),
              TextButton(
                onPressed: onAdd30,
                style: actionStyle,
                child: Text('+30 s', style: textStyle),
              ),
              TextButton(
                onPressed: onCustomize,
                style: actionStyle,
                child: Text('Personalizar', style: textStyle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
