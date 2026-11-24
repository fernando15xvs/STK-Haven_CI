import 'package:flutter/material.dart';
import '../app_colors.dart';

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Widget? icon;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.of(context);
    return Container(
      padding: EdgeInsets.all(ui.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(ui.cardRadius),
        border: Border.all(
          color: AppColors.of(context).surfaceBorder, width: ui.borderWidth),
        boxShadow: AppColors.of(context).shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Flexible(child: Text(label.toUpperCase(), style: AppTypography.labelSmall)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.headlineLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTypography.bodySmall),
          ],
        ],
      ),
    );
  }
}
