import 'package:flutter_test/flutter_test.dart';
import 'package:core/domain/models/gamification_state.dart';

void main() {
  test('processed workout ids survive serialization', () {
    const state = GamificationState(
      xp: 120,
      level: 2,
      processedWorkoutIds: ['workout-1', 'workout-2'],
    );

    final restored = GamificationState.fromJson(state.toJson());

    expect(restored.xp, 120);
    expect(restored.level, 2);
    expect(restored.hasProcessedWorkout('workout-1'), isTrue);
    expect(restored.hasProcessedWorkout('workout-2'), isTrue);
    expect(restored.hasProcessedWorkout('workout-3'), isFalse);
  });

  test('older state without processed ids remains compatible', () {
    final restored = GamificationState.fromJson({
      'xp': 50,
      'level': 1,
      'totalVolumeLifted': 250.0,
      'workoutStreak': 0,
      'achievements': <Map<String, dynamic>>[],
    });

    expect(restored.processedWorkoutIds, isEmpty);
  });
}
