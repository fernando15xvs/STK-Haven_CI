import 'package:flutter/material.dart';

import 'dashboard_page.dart';

/// Roadmap 3 keeps Home as a single surface. DashboardPage itself consumes the
/// canonical nextProgramSessionProvider, so it can show the continuous program
/// sequence without rendering a second, conflicting "today" card.
class ProgramDashboardPage extends StatelessWidget {
  const ProgramDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => const DashboardPage();
}
