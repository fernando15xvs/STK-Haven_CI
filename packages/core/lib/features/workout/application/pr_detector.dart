import 'package:uuid/uuid.dart';
import '../../../core/utils/fitness_math.dart';
import '../../../domain/models/personal_record.dart';
import '../../../domain/models/workout_session.dart';

class PRDetector {
  static List<PersonalRecordEvent> analyze({
    required WorkoutSession session,
    required double? Function(String exerciseId, PRType type)
        getBestPreviousValue,
  }) {
    final List<PersonalRecordEvent> newPRs = [];
    const uuid = Uuid();

    for (final exercise in session.exercises) {
      double maxWeightInSession = 0.0;
      double max1RMInSession = 0.0;
      double maxSetVolumeInSession = 0.0;

      for (final set in exercise.sets) {
        if (!set.completed || set.warmup || set.performanceReps <= 0) continue;

        if (set.performanceWeight > maxWeightInSession) {
          maxWeightInSession = set.performanceWeight;
        }

        final setVolume = set.performedVolume;
        if (setVolume > maxSetVolumeInSession) {
          maxSetVolumeInSession = setVolume;
        }

        final est = FitnessMath.estimated1RM(
          set.performanceWeight,
          set.performanceReps,
        );
        if (est != null && est > max1RMInSession) {
          max1RMInSession = est;
        }
      }

      final prevMaxWeight =
          getBestPreviousValue(exercise.exerciseId, PRType.maxWeight) ?? 0.0;
      if (maxWeightInSession > prevMaxWeight && maxWeightInSession > 0) {
        newPRs.add(PersonalRecordEvent(
          id: uuid.v4(),
          workoutSessionId: session.id,
          exerciseId: exercise.exerciseId,
          exerciseNameSnapshot: exercise.exerciseNameSnapshot,
          type: PRType.maxWeight,
          previousValue: prevMaxWeight,
          newValue: maxWeightInSession,
          achievedAt: session.finishedAt,
        ));
      }

      final prevMax1RM =
          getBestPreviousValue(exercise.exerciseId, PRType.estimated1RM) ?? 0.0;
      if (max1RMInSession > prevMax1RM && max1RMInSession > 0) {
        newPRs.add(PersonalRecordEvent(
          id: uuid.v4(),
          workoutSessionId: session.id,
          exerciseId: exercise.exerciseId,
          exerciseNameSnapshot: exercise.exerciseNameSnapshot,
          type: PRType.estimated1RM,
          previousValue: prevMax1RM,
          newValue: max1RMInSession,
          achievedAt: session.finishedAt,
        ));
      }

      final prevMaxVolume =
          getBestPreviousValue(exercise.exerciseId, PRType.bestSetVolume) ?? 0.0;
      if (maxSetVolumeInSession > prevMaxVolume && maxSetVolumeInSession > 0) {
        newPRs.add(PersonalRecordEvent(
          id: uuid.v4(),
          workoutSessionId: session.id,
          exerciseId: exercise.exerciseId,
          exerciseNameSnapshot: exercise.exerciseNameSnapshot,
          type: PRType.bestSetVolume,
          previousValue: prevMaxVolume,
          newValue: maxSetVolumeInSession,
          achievedAt: session.finishedAt,
        ));
      }
    }

    return newPRs;
  }
}
