import 'package:flutter/material.dart';

import 'dashboard_page.dart';

/// Roadmap 3 keeps Home as a single surface. DashboardPage itself consumes the
/// canonical nextProgramSessionProvider, so it can show the continuous program
/// sequence without rendering a second, conflicting "today" card.
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
      DashboardPage(onOpenProgress: onOpenProgress, isVisible: isVisible);
}
