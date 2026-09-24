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
    }) {
      return TrainingProgram(
        id: 'upper-lower',
        name: 'Upper / Lower continuo',
        routineIds: const ['ua', 'la', 'ub', 'lb'],
        createdAt: monday,
        startedAt: monday,
        trainingWeekdays: weekdays,
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
