import 'package:flutter/material.dart';
import '../app_colors.dart';

class SectionHeading extends StatelessWidget {
  final String title;
  final Color? color;

  const SectionHeading({super.key, required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: AppTypography.labelMedium.copyWith(
        letterSpacing: 1.2,
        color: color ?? AppColors.textSecondary,
      ),
    );
  }
}
