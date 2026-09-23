import 'package:core/features/workout/presentation/widgets/active_workout_memory_overlay.dart';
import 'package:flutter/material.dart';

import 'active_workout_page_content.dart' as content;

/// Stable route boundary for the active workout experience.
///
/// The memory/quick-action surface lives inside the route, below the app's
/// Navigator/Overlay. This keeps Tooltip and modal routes on Flutter's normal
/// lifecycle and avoids a persistent app-level OverlayEntry.
class ActiveWorkoutPage extends StatelessWidget {
  const ActiveWorkoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ActiveWorkoutMemoryOverlay(
      child: content.ActiveWorkoutPage(),
    );
  }
}
