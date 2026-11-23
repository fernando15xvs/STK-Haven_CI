import 'package:flutter/material.dart';

import 'dashboard_page.dart';

/// Inicio stays a single wellness surface. Next-session presentation belongs
/// to Entrenar; this wrapper only forwards Progreso navigation.
class ProgramDashboardPage extends StatelessWidget {
  const ProgramDashboardPage({
    super.key,
    this.onOpenProgress,
    this.isVisible = true,
  });

  /// Opens the persistent Progreso tab when hosted inside HomeScreen.
  final VoidCallback? onOpenProgress;
  final bool isVisible;

  @override
  Widget build(BuildContext context) =>
      DashboardPage(
        onOpenProgress: onOpenProgress,
        isVisible: isVisible,
      );
}
