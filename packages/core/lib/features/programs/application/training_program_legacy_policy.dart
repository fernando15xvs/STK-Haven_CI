import 'package:core/domain/models/active_program_state.dart';
import 'package:core/domain/models/training_program.dart';

/// A legacy onboarding snapshot is a fallback only for pre-migration users.
class TrainingProgramLegacyPolicy {
  const TrainingProgramLegacyPolicy._();

  static ActiveProgramState? dashboardFallback({
    required Iterable<TrainingProgram> programs,
    required ActiveProgramState? legacy,
  }) {
    if (legacy == null || !legacy.isActive) return null;
    // Paused modern programs are still authoritative; never revive the old plan.
    if (programs.any((program) => !program.isTemplate)) return null;
    return legacy;
  }

  /// A deleted modern onboarding plan must not reappear as legacy state.
  static bool shouldClearLegacyOnDelete({
    required TrainingProgram deleted,
    required ActiveProgramState? legacy,
  }) {
    if (legacy == null || deleted.isTemplate) return false;
    final previousIds = legacy.generatedRoutineIds.toSet();
    final deletedIds = deleted.routineIds.toSet();
    return previousIds.isNotEmpty &&
        previousIds.length == deletedIds.length &&
        previousIds.containsAll(deletedIds);
  }
}
