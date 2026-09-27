import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_plan_insights.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final monday = DateTime(2026, 9, 28);
  final routines = <Routine>[
    _routine('ua', 'Upper A'),
    _routine('la', 'Lower A'),
    _routine('ub', 'Upper B'),
    _routine('lb', 'Lower B'),
  ];

  test('five-day plan exposes useful weekly status and next session', () {
    final program = TrainingProgram(
      id: 'p',
      name: 'Upper / Lower continuo',
      routineIds: const ['ua', 'la', 'ub', 'lb'],
      createdAt: monday,
      startedAt: monday,
      durationWeeks: 12,
      trainingWeekdays:
          ProgramScheduleProjector.recommendedTrainingWeekdays(5),
    );

    final insights = ProgramPlanInsights.calculate(
      program: program,
      routines: routines,
      now: DateTime(2026, 9, 30, 12),
    );

    expect(insights.plannedThisWeek, 5);
    expect(insights.completedThisWeek, 0);
    expect(insights.dueThroughToday, 2);
    expect(insights.pendingDue, 2);
    expect(insights.remainingThisWeek, 5);
    expect(insights.nextScheduledDate, DateTime(2026, 10, 1));
    expect(insights.nextScheduledRoutineId, 'ua');
    expect(insights.next14SessionCount, 10);
  });

  test('completed sessions reduce pending and remaining counts', () {
    final program = TrainingProgram(
      id: 'p',
      name: 'Upper / Lower continuo',
      routineIds: const ['ua', 'la', 'ub', 'lb'],
      createdAt: monday,
      startedAt: monday,
      durationWeeks: 12,
      trainingWeekdays:
          ProgramScheduleProjector.recommendedTrainingWeekdays(5),
      nextRotationIndex: 2,
      completions: [
        ProgramCompletion(
          workoutSessionId: 'w1',
          routineId: 'ua',
          completedAt: DateTime(2026, 9, 28, 18),
          rotationIndex: 0,
          programWeek: 1,
        ),
        ProgramCompletion(
          workoutSessionId: 'w2',
          routineId: 'la',
          completedAt: DateTime(2026, 9, 29, 18),
          rotationIndex: 1,
          programWeek: 1,
        ),
      ],
    );

    final insights = ProgramPlanInsights.calculate(
      program: program,
      routines: routines,
      now: DateTime(2026, 9, 30, 12),
    );

    expect(insights.completedThisWeek, 2);
    expect(insights.pendingDue, 0);
    expect(insights.remainingThisWeek, 3);
    expect(insights.paceLabel, 'Vas al día con tu calendario.');
    expect(insights.nextScheduledDate, DateTime(2026, 10, 1));
    expect(insights.nextScheduledRoutineId, 'ub');
  });
}

Routine _routine(String id, String name) {
  return Routine(
    id: id,
    name: name,
    scheduledDays: const [],
    createdAt: DateTime(2026, 9, 1),
    exercises: const [],
  );
}
