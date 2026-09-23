import 'package:core/features/workout/presentation/widgets/active_workout_memory_overlay.dart';
import 'package:flutter/material.dart';

import 'active_workout_page_web_route_content.dart' as content;

/// Web route boundary for workout memory/quick actions.
///
/// The controls are mounted inside the active workout route so Flutter's
/// Navigator/Overlay lifecycle remains authoritative for Tooltip and dialogs.
class ActiveWorkoutPageWeb extends StatelessWidget {
  const ActiveWorkoutPageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return const ActiveWorkoutMemoryOverlay(
      child: content.ActiveWorkoutPageWeb(),
    );
  }
}
