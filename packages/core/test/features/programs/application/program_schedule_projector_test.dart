import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgramScheduleProjector', () {
    final monday = DateTime(2026, 9, 7);
    final routines = <Routine>[
      _routine('ua', 'Upper A', {DateTime.monday, DateTime.saturday}),
      _routine('la', 'Lower A', {DateTime.tuesday}),
      _routine('ub', 'Upper B', {DateTime.thursday}),
      _routine('lb', 'Lower B', {DateTime.friday}),
    ];

    TrainingProgram program({
      Set<int> weekdays = const {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
      },
      int nextIndex = 0,
      ProgramScheduleMode scheduleMode = ProgramScheduleMode.continuous,
      int targetSessionsPerWeek = 0,
      Map<int, String> fixedWeekdayRoutineIds = const {},
    }) {
      return TrainingProgram(
        id: 'upper-lower',
        name: 'Upper / Lower continuo',
        routineIds: const ['ua', 'la', 'ub', 'lb'],
        createdAt: monday,
        startedAt: monday,
        scheduleMode: scheduleMode,
        targetSessionsPerWeek: targetSessionsPerWeek,
        trainingWeekdays: weekdays,
        fixedWeekdayRoutineIds: fixedWeekdayRoutineIds,
        nextRotationIndex: nextIndex,
      );
    }

    test('projects the exact continuous three-week Upper/Lower example', () {
      final projected = ProgramScheduleProjector.project(
        program: program(),
        routines: routines,
        from: monday,
        days: 20,
      );

      final first15 = projected.take(15).toList(growable: false);

      expect(
        first15.map((item) => item.routineId).toList(),
        [
          'ua', 'la', 'ub', 'lb', 'ua',
          'la', 'ub', 'lb', 'ua', 'la',
          'ub', 'lb', 'ua', 'la', 'ub',
        ],
      );

      expect(
        first15.map((item) => item.date.weekday).toList(),
        [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.monday,
          DateTime.tuesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.monday,
          DateTime.tuesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
        ],
      );
    });

    test('recommended five-day schedule matches the adaptive default', () {
      expect(
        ProgramScheduleProjector.recommendedTrainingWeekdays(5),
        {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
        },
      );
    });

    test('five-day weeks alternate 3/2 distribution without resetting', () {
      final adaptive = program(
        weekdays: ProgramScheduleProjector.recommendedTrainingWeekdays(5),
      );

      final week1 = ProgramScheduleProjector.projectWeek(
        program: adaptive,
        routines: routines,
        weekStart: monday,
      );
      final afterWeek1 = adaptive.copyWith(
        nextRotationIndex: 1,
        completions: [
          for (var i = 0; i < week1.length; i++)
            ProgramCompletion(
              workoutSessionId: 'w1-$i',
              routineId: week1[i].routineId,
              completedAt: week1[i].date.add(const Duration(hours: 18)),
              rotationIndex: week1[i].rotationIndex,
              programWeek: 1,
            ),
        ],
      );
      final week2 = ProgramScheduleProjector.projectWeek(
        program: afterWeek1,
        routines: routines,
        weekStart: monday.add(const Duration(days: 7)),
      );

      expect(
        week1.map((item) => item.routineId).toList(),
        ['ua', 'la', 'ub', 'lb', 'ua'],
      );
      expect(
        week2.map((item) => item.routineId).toList(),
        ['la', 'ub', 'lb', 'ua', 'la'],
      );
    });

    test('continuous frequency follows selected training days', () {
      final continuous = program(
        weekdays: const {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.thursday,
          DateTime.friday,
        },
        targetSessionsPerWeek: 5, // stale value from an older editor
      );

      final projected = ProgramScheduleProjector.projectWeek(
        program: continuous,
        routines: routines,
        weekStart: monday,
      );

      expect(
        ProgramScheduleProjector.effectiveTargetSessionsPerWeek(
          continuous,
          routines,
        ),
        4,
      );
      expect(projected.length, 4);
    });

    test('continuous seven-day calendar means seven weekly sessions', () {
      final everyDay = program(
        weekdays: const {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        },
        targetSessionsPerWeek: 4,
      );

      expect(
        ProgramScheduleProjector.effectiveTargetSessionsPerWeek(
          everyDay,
          routines,
        ),
        7,
      );
      expect(
        ProgramScheduleProjector.projectWeek(
          program: everyDay,
          routines: routines,
          weekStart: monday,
        ).length,
        7,
      );
    });

    test('flexible plan ignores routine weekdays and follows frequency', () {
      final flexible = program(
        weekdays: const {},
        scheduleMode: ProgramScheduleMode.flexible,
        targetSessionsPerWeek: 4,
      );

      final projected = ProgramScheduleProjector.projectWeek(
        program: flexible,
        routines: routines,
        weekStart: monday,
      );

      expect(
        ProgramScheduleProjector.effectiveTrainingWeekdays(
          flexible,
          routines,
        ),
        isEmpty,
      );
      expect(projected.length, 4);
      expect(projected.every((item) => item.isFlexibleEstimate), isTrue);
      expect(
        ProgramScheduleProjector.isTrainingDay(
          flexible,
          routines,
          monday.add(const Duration(days: 2)),
        ),
        isTrue,
      );
    });

    test('fixed plan owns weekday to routine assignments', () {
      final fixed = program(
        weekdays: const {},
        scheduleMode: ProgramScheduleMode.fixed,
        targetSessionsPerWeek: 3,
        fixedWeekdayRoutineIds: const {
          DateTime.monday: 'lb',
          DateTime.wednesday: 'ua',
          DateTime.friday: 'lb',
        },
      );

      final projected = ProgramScheduleProjector.projectWeek(
        program: fixed,
        routines: routines,
        weekStart: monday,
      );

      expect(
        projected.map((item) => item.routineId).toList(),
        ['lb', 'ua', 'lb'],
      );
      expect(
        projected.map((item) => item.date.weekday).toList(),
        [DateTime.monday, DateTime.wednesday, DateTime.friday],
      );
      expect(
        ProgramScheduleProjector.effectiveTargetSessionsPerWeek(
          fixed,
          routines,
        ),
        3,
      );
    });

    test('new week does not reset the routine sequence', () {
      final projected = ProgramScheduleProjector.project(
        program: program(),
        routines: routines,
        from: monday,
        days: 8,
      );

      expect(projected[4].routineId, 'ua');
      expect(projected[4].date.weekday, DateTime.saturday);
      expect(projected[5].routineId, 'la');
      expect(projected[5].date.weekday, DateTime.monday);
    });

    test('nextRotationIndex is respected when projecting future sessions', () {
      final projected = ProgramScheduleProjector.project(
        program: program(nextIndex: 2),
        routines: routines,
        from: monday,
        days: 3,
      );

      expect(projected.map((item) => item.routineId), ['ub', 'lb']);
    });

    test('legacy frequency is inferred from effective routine weekdays', () {
      final legacy = program(
        weekdays: const {},
        targetSessionsPerWeek: 0,
      );

      expect(
        ProgramScheduleProjector.effectiveTargetSessionsPerWeek(
          legacy,
          routines,
        ),
        5,
      );
      expect(legacy.effectiveTargetSessionsPerWeek, 4);
    });

    test('legacy program derives opportunity days from routine schedules', () {
      final legacy = program(weekdays: const {});

      final effective =
          ProgramScheduleProjector.effectiveTrainingWeekdays(legacy, routines);

      expect(
        effective,
        {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
        },
      );
    });

    test('program without any configured days can run on any day', () {
      final noScheduleRoutines = <Routine>[
        _routine('ua', 'Upper A', const {}),
        _routine('la', 'Lower A', const {}),
      ];
      final noSchedule = TrainingProgram(
        id: 'free-days',
        name: 'Libre',
        routineIds: const ['ua', 'la'],
        createdAt: monday,
        startedAt: monday,
      );

      expect(
        ProgramScheduleProjector.isTrainingDay(
          noSchedule,
          noScheduleRoutines,
          monday.add(const Duration(days: 2)),
        ),
        isTrue,
      );
    });

    test('training weekdays survive JSON round-trip', () {
      final original = program();

      final restored = TrainingProgram.fromJson(original.toJson());

      expect(restored.trainingWeekdays, original.trainingWeekdays);
      expect(restored.nextRoutineId, 'ua');
    });

    test('schedule mode, target frequency and fixed map survive JSON', () {
      final original = program(
        weekdays: const {},
        scheduleMode: ProgramScheduleMode.fixed,
        targetSessionsPerWeek: 4,
        fixedWeekdayRoutineIds: const {
          DateTime.monday: 'ua',
          DateTime.tuesday: 'la',
          DateTime.thursday: 'ub',
          DateTime.friday: 'lb',
        },
      );

      final restored = TrainingProgram.fromJson(original.toJson());

      expect(restored.scheduleMode, ProgramScheduleMode.fixed);
      expect(restored.targetSessionsPerWeek, 4);
      expect(restored.fixedWeekdayRoutineIds, original.fixedWeekdayRoutineIds);
    });

    test('old JSON infers frequency from stored plan weekdays', () {
      final json = program().toJson()
        ..remove('targetSessionsPerWeek')
        ..remove('scheduleMode')
        ..remove('fixedWeekdayRoutineIds');

      final restored = TrainingProgram.fromJson(json);

      expect(restored.scheduleMode, ProgramScheduleMode.continuous);
      expect(restored.effectiveTargetSessionsPerWeek, 5);
    });

    test('old JSON without trainingWeekdays remains compatible', () {
      final json = program().toJson()..remove('trainingWeekdays');

      final restored = TrainingProgram.fromJson(json);

      expect(restored.trainingWeekdays, isEmpty);
      expect(restored.nextRoutineId, 'ua');
    });
  });
}

Routine _routine(String id, String name, Set<int> days) {
  return Routine(
    id: id,
    name: name,
    scheduledDays: days.toList()..sort(),
    createdAt: DateTime(2026, 9, 1),
    exercises: const [],
  );
}
