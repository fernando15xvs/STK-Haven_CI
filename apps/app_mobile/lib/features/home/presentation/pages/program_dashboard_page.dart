import 'package:flutter/material.dart';

import 'dashboard_page.dart';

/// Roadmap 3 keeps Home as a single surface. DashboardPage itself consumes the
/// canonical nextProgramSessionProvider, so it can show the continuous program
/// sequence without rendering a second, conflicting "today" card.
class ProgramDashboardPage extends StatelessWidget {
  const ProgramDashboardPage({super.key, this.onOpenProgress});

  /// Opens the persistent Progreso tab when hosted inside HomeScreen.
  final VoidCallback? onOpenProgress;

  @override
  Widget build(BuildContext context) =>
      DashboardPage(onOpenProgress: onOpenProgress);
}
