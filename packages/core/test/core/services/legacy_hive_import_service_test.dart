import 'dart:io';

import 'package:core/core/services/legacy_hive_import_service.dart';
import 'package:core/database/hive/hive_adapters.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/database/hive/models/hive_body_measurement.dart';
import 'package:core/database/hive/models/hive_exercise.dart';
import 'package:core/database/hive/models/hive_personal_record.dart';
import 'package:core/database/hive/models/hive_routine.dart';
import 'package:core/database/hive/models/hive_workout_session.dart';
import 'package:core/domain/models/hive_favorite_verse.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

HiveWorkoutSession oldWorkout(String id, String name) => HiveWorkoutSession(
  id: id,
  routineNameSnapshot: name,
  startedAt: DateTime.utc(2026, 8, 30, 7),
  finishedAt: DateTime.utc(2026, 8, 30, 8),
  durationSeconds: 3600,
  exercises: [
    HiveWorkoutExercise(
      exerciseId: 'press',
      sets: [HiveWorkoutSet(weight: 62.5, reps: 9, completed: true)],
    ),
  ],
);

Future<void> openCurrentHiveBoxes() async {
  await Hive.openBox<dynamic>(HiveBoxes.metadata);
  await Hive.openBox<HiveExercise>(HiveBoxes.exercises);
  await Hive.openBox<HiveRoutine>(HiveBoxes.routines);
  await Hive.openBox<HiveWorkoutSession>(HiveBoxes.history);
  await Hive.openBox<HivePersonalRecord>(HiveBoxes.personalRecords);
  await Hive.openBox<HiveBodyMeasurement>(HiveBoxes.bodyMeasurements);
  await Hive.openBox<HiveFavoriteVerse>(HiveBoxes.favoriteVerses);
  await Hive.openBox<dynamic>(HiveBoxes.gamification);
  await Hive.openBox<dynamic>(HiveBoxes.hydration);
  await Hive.openBox<dynamic>(HiveBoxes.recovery);
  await Hive.openBox<dynamic>(HiveBoxes.habitTasks);
  await Hive.openBox<dynamic>(HiveBoxes.restoreJournal);
}

void main() {
  late Directory tempDir;
  var adaptersRegistered = false;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stk_legacy_import_');
    Hive.init(tempDir.path);
    if (!adaptersRegistered) {
      registerHiveAdapters();
      adaptersRegistered = true;
    }
    await openCurrentHiveBoxes();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('B1.7 imports known v1 typed workout/routine/exercise without loss',
      () async {
    final metadata = Hive.box<dynamic>(HiveBoxes.metadata);
    final workouts = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    await metadata.put('db_version', 2);
    await metadata.put('user_experience_profile_v1', {'trainingDaysPerWeek': 4});
    await workouts.put('existing', oldWorkout('existing', 'Actual'));

    final oldHistory = await Hive.openBox<dynamic>('historyBox_v1');
    await oldHistory.put('old', oldWorkout('old', 'Registro antiguo'));
    await oldHistory.close();
    final oldRoutines = await Hive.openBox<dynamic>('routinesBox_v1');
    await oldRoutines.put('routine-old', HiveRoutine(
      id: 'routine-old',
      name: 'Rutina antigua',
      scheduledDays: const [1, 3, 5],
      exercises: const [],
      createdAt: DateTime.utc(2026, 8, 25),
    ));
    await oldRoutines.close();
    final oldExercises = await Hive.openBox<dynamic>('exercisesBox_v1');
    await oldExercises.put('exercise-old', HiveExercise(
      id: 'exercise-old',
      name: 'Press histórico',
      muscleGroup: 'Pecho',
    ));
    await oldExercises.close();

    final importer = LegacyHiveImportService();
    final scan = await importer.inspect();
    expect(scan.safeToImport, isTrue);
    expect(scan.recognized, 3);
    expect(scan.archivesFound, 3);
    final result = await importer.importRecognized();
    expect(result.imported, 3);
    expect(result.workouts, 1);
    expect(result.routines, 1);
    expect(result.exercises, 1);
    expect(workouts.containsKey('existing'), isTrue);
    expect(workouts.get('existing')!.routineNameSnapshot, 'Actual');
    expect(workouts.get('old')!.routineNameSnapshot, 'Registro antiguo');
    expect(workouts.get('old')!.exercises.single.sets.single.weight, 62.5);
    expect(Hive.box<HiveRoutine>(HiveBoxes.routines)
        .get('routine-old')!.scheduledDays, [1, 3, 5]);
    expect(Hive.box<HiveExercise>(HiveBoxes.exercises)
        .get('exercise-old')!.name, 'Press histórico');
    expect(metadata.get('db_version'), 2);
    expect((metadata.get('user_experience_profile_v1') as Map)
        ['trainingDaysPerWeek'], 4);
    expect(Hive.box(HiveBoxes.restoreJournal).isEmpty, isTrue);

    // Source archives are never deleted, cleared, renamed or modified.
    final original = await Hive.openBox<dynamic>('historyBox_v1');
    expect(original.containsKey('old'), isTrue);
    expect((original.get('old') as HiveWorkoutSession).exercises
        .single.sets.single.reps, 9);
  });

  test('B1.7 pre-existing modern record wins over same-ID legacy record',
      () async {
    final workouts = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    await workouts.put('shared', oldWorkout('shared', 'Actual'));
    final legacy = await Hive.openBox<dynamic>('historyBox');
    await legacy.put('shared', oldWorkout('shared', 'Archivado'));
    await legacy.close();

    final result = await const LegacyHiveImportService().importRecognized();
    expect(result.imported, 0);
    expect(result.duplicateIds, 1);
    expect(workouts.get('shared')!.routineNameSnapshot, 'Actual');
    final unchanged = await Hive.openBox<dynamic>('historyBox');
    expect((unchanged.get('shared') as HiveWorkoutSession)
        .routineNameSnapshot, 'Archivado');
  });

  test('B1.7 unrecognized archive records block import without data loss',
      () async {
    final workouts = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    await workouts.put('current', oldWorkout('current', 'Actual'));
    final legacy = await Hive.openBox<dynamic>('historyBox_v1');
    await legacy.put('unknown', {'legacyCodec': 'not-a-HiveWorkoutSession'});
    await legacy.close();

    final scan = await const LegacyHiveImportService().inspect();
    expect(scan.safeToImport, isFalse);
    expect(scan.unsupportedRecords, 1);
    await expectLater(
      const LegacyHiveImportService().importRecognized(),
      throwsA(isA<StateError>()),
    );
    expect(workouts.keys, contains('current'));
    expect(Hive.box(HiveBoxes.restoreJournal).isEmpty, isTrue);
    final untouched = await Hive.openBox<dynamic>('historyBox_v1');
    expect(untouched.containsKey('unknown'), isTrue);
  });
}
