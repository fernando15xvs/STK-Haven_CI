import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/application/exercise_anatomy_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audits stored labels independently without modifying snapshots', () {
    final catalog = [
      Exercise(
        id: 'press', name: 'Press',
        muscleGroup: 'Hombros',
        secondaryMuscles: const ['Tríceps y hombro', 'Deltoides posterior'],
      ),
      Exercise(id: 'hip', name: 'Hip thrust', muscleGroup: 'Glúteos'),
    ];
    final routine = Routine(
      id: 'r', name: 'Rutina', scheduledDays: const [],
      createdAt: DateTime(2026, 1, 1),
      exercises: const [
        RoutineExercise(
          exerciseId: 'press', order: 0, targetSets: 2,
          targetRepsMin: 8, targetRepsMax: 12, restSeconds: 90,
        ),
        RoutineExercise(
          exerciseId: 'deleted', order: 1, targetSets: 1,
          targetRepsMin: 8, targetRepsMax: 12, restSeconds: 90,
        ),
      ],
    );
    final session = WorkoutSession(
      id: 'session', routineNameSnapshot: 'Antigua',
      startedAt: DateTime(2026, 1, 2),
      finishedAt: DateTime(2026, 1, 2, 1),
      durationSeconds: 3600,
      exercises: const [
        WorkoutExercise(
          exerciseId: 'press',
          exerciseNameSnapshot: 'Press antiguo',
          muscleGroupSnapshot: 'Glúteos e isquios',
          sets: [WorkoutSet(weight: 20, reps: 10, completed: true)],
        ),
        WorkoutExercise(
          exerciseId: 'removed',
          exerciseNameSnapshot: 'Ejercicio borrado',
          muscleGroupSnapshot: 'Hombros',
          sets: [],
        ),
      ],
    );
    final report = ExerciseAnatomyAudit.inspect(
      catalog: catalog, routines: [routine], history: [session],
    );
    expect(report.catalogExercises, 2);
    expect(report.routineReferences, 2);
    expect(report.historicalExercises, 2);
    expect(report.missingRoutineExerciseIds, ['deleted']);
    expect(report.missingHistoricalExerciseIds, ['removed']);
    expect(report.findings.any((f) =>
        f.source == AnatomyAuditSource.catalogPrimary &&
        f.originalLabel == 'Hombros' &&
        f.safeGroupId == 'mg_shoulders'), true);
    expect(report.findings.any((f) =>
        f.source == AnatomyAuditSource.catalogSecondary &&
        f.originalLabel == 'Tríceps y hombro' && f.isUnresolved), true);
    expect(report.findings.any((f) =>
        f.source == AnatomyAuditSource.historySnapshot &&
        f.originalLabel == 'Glúteos e isquios' && f.isUnresolved), true);
    expect(report.unresolvedOccurrences, 2);
    expect(session.exercises.first.muscleGroupSnapshot, 'Glúteos e isquios');
    expect(session.exercises.first.sets.length, 1);
    expect(catalog.first.muscleGroup, 'Hombros');
  });

  test('repeated aliases are counted without creating fictitious anatomy', () {
    final report = ExerciseAnatomyAudit.inspect(catalog: [
      Exercise(id: 'a', name: 'A', muscleGroup: 'Hombros'),
      Exercise(id: 'b', name: 'B', muscleGroup: 'hombros'),
      Exercise(id: 'c', name: 'C', muscleGroup: 'Deltoides posterior'),
      Exercise(id: 'd', name: 'D', muscleGroup: '???'),
    ]);
    final broad = report.findings.singleWhere(
      (f) => f.source == AnatomyAuditSource.catalogPrimary &&
          f.originalLabel == 'Hombros',
    );
    expect(broad.occurrences, 2);
    expect(broad.safeGroupId, 'mg_shoulders');
    expect(report.unresolvedOccurrences, 1);
    expect(report.broadOrAmbiguousOccurrences, 3);
    expect(report.historicalExercises, 0);
    expect(report.missingHistoricalExerciseIds, isEmpty);
  });

  test('empty input returns a non-destructive, empty report', () {
    final report = ExerciseAnatomyAudit.inspect(catalog: const []);
    expect(report.hasFindings, false);
    expect(report.findings, isEmpty);
    expect(report.unresolvedOccurrences, 0);
  });
}
