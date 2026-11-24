import 'dart:io';

import 'package:core/core/services/backup_service.dart';
import 'package:core/database/hive/hive_adapters.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/database/hive/models/hive_body_measurement.dart';
import 'package:core/database/hive/models/hive_exercise.dart';
import 'package:core/database/hive/models/hive_personal_record.dart';
import 'package:core/database/hive/models/hive_routine.dart';
import 'package:core/database/hive/models/hive_workout_session.dart';
import 'package:core/domain/models/hive_favorite_verse.dart';
import 'package:test/test.dart';
import 'package:hive/hive.dart';

Future<void> openRestoreBoxes() async {
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

HiveWorkoutSession originalWorkout(String id) => HiveWorkoutSession(
  id: id,
  routineNameSnapshot: 'Full body sin conexión',
  startedAt: DateTime.utc(2026, 11, 16, 9),
  finishedAt: DateTime.utc(2026, 11, 16, 10),
  durationSeconds: 3600,
  exercises: [
    HiveWorkoutExercise(exerciseId: 'press', sets: [
      HiveWorkoutSet(weight: 50, reps: 8, completed: true),
      HiveWorkoutSet(
        weight: 52.5, reps: 0, completed: false,
        recordedOutcome: 'skipped',
      ),
    ]),
  ],
);

void main() {
  late Directory tempDir;
  var adaptersRegistered = false;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stk_haven_restore_journal_');
    Hive.init(tempDir.path);
    // Hive.close() closes boxes but preserves registered TypeAdapters.
    if (!adaptersRegistered) {
      registerHiveAdapters();
      adaptersRegistered = true;
    }
    await openRestoreBoxes();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('B1.8: interrupted Hive restore survives process restart', () async {
    final oldHistory = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    final oldMeta = Hive.box<dynamic>(HiveBoxes.metadata);
    await oldHistory.put('original', originalWorkout('original'));
    await oldMeta.put('db_version', 2);
    await oldMeta.put('user_experience_profile_v1', {
      'onboardingVersion': 2,
      'trainingDaysPerWeek': 4,
    });
    await Hive.box<dynamic>(HiveBoxes.hydration)
        .put('2026-11-16', {'waterMl': 1700});
    final snapshot = BackupService().createBackup();
    final journal = Hive.box<dynamic>(HiveBoxes.restoreJournal);
    await journal.put(BackupService.pendingRestoreJournalKey, {
      'format': 'stk_haven_restore_journal_v1',
      'backup': snapshot,
      'db_version': 2,
    });
    await journal.flush();

    // Simulate a process being killed halfway through destructive box writes.
    await oldHistory.clear();
    await oldMeta.clear();
    await Hive.box<dynamic>(HiveBoxes.hydration).clear();
    await Hive.close();

    Hive.init(tempDir.path);
    await openRestoreBoxes();
    expect(Hive.box<HiveWorkoutSession>(HiveBoxes.history).isEmpty, isTrue);

    expect(await BackupService.recoverInterruptedRestore(), isTrue);
    final restored = Hive.box<HiveWorkoutSession>(HiveBoxes.history)
        .get('original')!;
    expect(restored.exercises.single.sets.first.weight, 50);
    expect(restored.exercises.single.sets.first.reps, 8);
    expect(restored.exercises.single.sets.last.recordedOutcome, 'skipped');
    expect(Hive.box(HiveBoxes.metadata).get('db_version'), 2);
    expect(
      (Hive.box(HiveBoxes.metadata).get('user_experience_profile_v1') as Map)
          ['trainingDaysPerWeek'],
      4,
    );
    expect(
      (Hive.box(HiveBoxes.hydration).get('2026-11-16') as Map)['waterMl'],
      1700,
    );
    expect(
      Hive.box<dynamic>(HiveBoxes.restoreJournal)
          .containsKey(BackupService.pendingRestoreJournalKey),
      isFalse,
    );
    expect(await BackupService.recoverInterruptedRestore(), isFalse);
  });

  test('B1.8: malformed journal fails closed and is not deleted', () async {
    final history = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    await history.put('original', originalWorkout('original'));
    final journal = Hive.box<dynamic>(HiveBoxes.restoreJournal);
    await journal.put(BackupService.pendingRestoreJournalKey, {
      'format': 'invalid',
      'backup': 'private/corrupt.json',
    });
    await expectLater(
      BackupService.recoverInterruptedRestore(),
      throwsA(isA<StateError>()),
    );
    expect(history.containsKey('original'), isTrue);
    expect(journal.containsKey(BackupService.pendingRestoreJournalKey), isTrue);
    await expectLater(
      BackupService().restoreBackup({'settings': {}}),
      throwsA(isA<StateError>()),
    );
    expect(history.containsKey('original'), isTrue);
  });

  test('B1.8: successful restore clears journal before success', () async {
    final history = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    await history.put('previous', originalWorkout('previous'));
    await BackupService().restoreBackup({'settings': {}});
    expect(history.isEmpty, isTrue);
    expect(
      Hive.box<dynamic>(HiveBoxes.restoreJournal)
          .containsKey(BackupService.pendingRestoreJournalKey),
      isFalse,
    );
    expect(await BackupService.recoverInterruptedRestore(), isFalse);
  });

  test('B1.8: malformed import is rejected before writing journal', () async {
    final history = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    await history.put('previous', originalWorkout('previous'));
    await expectLater(
      BackupService().restoreBackup({
        'settings': {},
        'workouts': [
          {'id': 'duplicate'},
          {'id': 'duplicate'},
        ],
      }),
      throwsA(isA<FormatException>()),
    );
    expect(history.containsKey('previous'), isTrue);
    expect(
      Hive.box<dynamic>(HiveBoxes.restoreJournal)
          .containsKey(BackupService.pendingRestoreJournalKey),
      isFalse,
    );
  });

  test('cloud restoration refuses to start after the session changes', () async {
    final history = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    await history.put('original', originalWorkout('original'));
    await expectLater(
      BackupService().restoreBackup(
        {'settings': {}},
        allowCommit: () => false,
      ),
      throwsA(isA<StateError>()),
    );
    expect(history.containsKey('original'), isTrue);
    expect(Hive.box<dynamic>(HiveBoxes.restoreJournal)
        .containsKey(BackupService.pendingRestoreJournalKey), isFalse);
  });

  test('cloud restoration rolls back if account changes during disk writes',
      () async {
    final history = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    await history.put('original', originalWorkout('original'));
    var checks = 0;
    await expectLater(
      BackupService().restoreBackup(
        {'settings': {}},
        // The first two checks allow journaling and the destructive restore.
        // The third denies committing it after the account switches.
        allowCommit: () => ++checks < 3,
      ),
      throwsA(isA<StateError>()),
    );
    expect(checks, 3);
    expect(history.get('original')?.exercises.single.sets.first.weight, 50);
    expect(Hive.box<dynamic>(HiveBoxes.restoreJournal)
        .containsKey(BackupService.pendingRestoreJournalKey), isFalse);
    expect(await BackupService.recoverInterruptedRestore(), isFalse);
  });

  test('B1.8: database startup recovery runs after opening typed boxes', () {
    final source = File('lib/database/hive/hive_database.dart')
        .readAsStringSync();
    final open = source.indexOf('Hive.openBox(HiveBoxes.restoreJournal)');
    final finished = source.indexOf('    ]);', open);
    final recovered = source.indexOf(
      'await BackupService.recoverInterruptedRestore();');
    expect(open, greaterThanOrEqualTo(0));
    expect(finished, greaterThan(open));
    expect(recovered, greaterThan(finished));
  });
}
