import 'package:core/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Keeps the web experience mobile-first without changing phone layouts.
class MobileContentFrame extends StatelessWidget {
  const MobileContentFrame({
    required this.child,
    super.key,
    this.maxWidth = 600,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.of(context).background,
      child: Center(
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }
}
