import 'package:flutter/material.dart';
import '../app_colors.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) ...[
                  Text(
                    subtitle!.toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  style: AppTypography.headlineMedium,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
