import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_set_record_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('historical unfinished sets remain pending, not skipped or failed', () {
    for (final set in [
      const WorkoutSet(weight: 0, reps: 0, completed: false),
      const WorkoutSet(weight: 80, reps: 0, completed: false),
      const WorkoutSet(weight: 80, reps: 10, completed: false),
      const WorkoutSet(weight: 80, reps: 10, completed: false, rir: 0),
      const WorkoutSet(weight: 80, reps: 10, completed: false,
          leftCompleted: true, rightCompleted: false),
    ]) {
      expect(WorkoutSetRecordStatusPolicy.fromSet(set),
          WorkoutSetRecordStatus.pending);
    }
  });

  test('completed wins over contradictory outcome evidence', () {
    const set = WorkoutSet(weight: 30, reps: 8, completed: true);
    expect(WorkoutSetRecordStatusPolicy.fromSet(set),
        WorkoutSetRecordStatus.completed);
    for (final evidence in WorkoutSetOutcomeEvidence.values) {
      expect(WorkoutSetRecordStatusPolicy.fromSet(set,
          recordedOutcome: evidence), WorkoutSetRecordStatus.completed);
    }
  });

  test('skipped and failed demand distinct explicitly recorded evidence', () {
    const set = WorkoutSet(weight: 30, reps: 8, completed: false);
    expect(WorkoutSetRecordStatusPolicy.fromSet(set,
      recordedOutcome: WorkoutSetOutcomeEvidence.skipped),
      WorkoutSetRecordStatus.skipped);
    expect(WorkoutSetRecordStatusPolicy.fromSet(set,
      recordedOutcome: WorkoutSetOutcomeEvidence.failed),
      WorkoutSetRecordStatus.failed);
    expect(WorkoutSetRecordStatusPolicy.fromSet(set),
      WorkoutSetRecordStatus.pending);
  });

  test('labels distinguish all four outcomes without changing stored flags', () {
    expect(WorkoutSetRecordStatus.values.map((s) => s.label).toList(), [
      'Pendiente', 'Completada', 'Omitida', 'Fallida',
    ]);
  });
  test('explicit persisted evidence is read, reset, and cleared on completion', () {
    const skipped = WorkoutSet(
      weight: 80, reps: 0, completed: false, recordedOutcome: 'skipped');
    const failed = WorkoutSet(
      weight: 80, reps: 0, completed: false, recordedOutcome: 'failed');
    expect(WorkoutSetRecordStatusPolicy.fromSet(skipped),
        WorkoutSetRecordStatus.skipped);
    expect(WorkoutSetRecordStatusPolicy.fromSet(failed),
        WorkoutSetRecordStatus.failed);
    expect(WorkoutSetRecordStatusPolicy.fromSet(
        skipped.copyWith(clearRecordedOutcome: true)),
        WorkoutSetRecordStatus.pending);
    expect(WorkoutSetRecordStatusPolicy.fromSet(
        failed.copyWith(completed: true)),
        WorkoutSetRecordStatus.completed);
    expect(failed.copyWith(completed: true).recordedOutcome, isNull);
    expect(WorkoutSetRecordStatusPolicy.fromSet(const WorkoutSet(
      weight: 20, reps: 8, completed: false, recordedOutcome: 'unknown')),
      WorkoutSetRecordStatus.pending);
  });

}
