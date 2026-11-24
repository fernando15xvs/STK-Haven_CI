import 'dart:convert';
import 'dart:io';

import 'package:core/core/services/backup_service.dart';
import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:core/features/nutrition/data/stk_nutrition_intent_repository.dart';
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

void main() {
  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'stk_haven_roadmap2_backup_',
    );
    Hive.init(tempDirectory.path);
    registerHiveAdapters();

    await Hive.openBox(HiveBoxes.metadata);
    await Hive.openBox<HiveExercise>(HiveBoxes.exercises);
    await Hive.openBox<HiveRoutine>(HiveBoxes.routines);
    await Hive.openBox<HiveWorkoutSession>(HiveBoxes.history);
    await Hive.openBox<HivePersonalRecord>(HiveBoxes.personalRecords);
    await Hive.openBox<HiveBodyMeasurement>(HiveBoxes.bodyMeasurements);
    await Hive.openBox<HiveFavoriteVerse>(HiveBoxes.favoriteVerses);
    await Hive.openBox(HiveBoxes.gamification);
    await Hive.openBox(HiveBoxes.hydration);
    await Hive.openBox(HiveBoxes.recovery);
    await Hive.openBox(HiveBoxes.habitTasks);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('schema 8 workout restores with safe unilateral defaults', () async {
    final payload = jsonEncode({
      'format': 'gym_tracker_backup',
      'schemaVersion': 8,
      'exportedAt': '2026-08-01T12:00:00.000Z',
      'appVersion': '1.0.0',
      'data': {
        'settings': {},
        'exercises': [],
        'routines': [],
        'workouts': [
          {
            'id': 'legacy-session',
            'routineId': 'push-a',
            'routineNameSnapshot': 'Push A',
            'startedAt': '2026-08-01T12:00:00.000Z',
            'finishedAt': '2026-08-01T13:00:00.000Z',
            'durationSeconds': 3600,
            'notes': '',
            'exercises': [
              {
                'exerciseId': 'press',
                'exerciseNameSnapshot': 'Press',
                'muscleGroupSnapshot': 'Pecho',
                'notes': '',
                'sets': [
                  {
                    'weight': 50,
                    'reps': 10,
                    'completed': true,
                    'rir': 2,
                    'warmup': false,
                    'restSeconds': 120,
                  }
                ],
              }
            ],
          }
        ],
        'personalRecords': [],
        'bodyMeasurements': [],
        'favoriteVerses': [],
        'gamification': {},
        'hydration': {},
        'recovery': {},
      },
    });

    final service = BackupService();
    final validation = service.validateBackup(payload);

    expect(validation.isValid, isTrue);
    expect(validation.schemaVersion, 8);

    await service.restoreBackup(
      validation.parsedData!,
      schemaVersion: validation.schemaVersion!,
    );

    final workouts = Hive.box<HiveWorkoutSession>(HiveBoxes.history).values;
    final exercise = workouts.single.exercises.single;
    final set = exercise.sets.single;

    expect(exercise.unilateral, isFalse);
    expect(exercise.supersetGroupId, isNull);
    expect(set.weight, 50);
    expect(set.reps, 10);
    expect(set.leftCompleted, isFalse);
    expect(set.rightCompleted, isFalse);
    expect(set.leftWeight, isNull);
    expect(set.rightWeight, isNull);
    expect(set.leftReps, isNull);
    expect(set.rightReps, isNull);
    expect(set.leftRir, isNull);
    expect(set.rightRir, isNull);
    expect(set.sideRestSeconds, 60);
    expect(set.recordedOutcome, isNull);
    expect(set.setType, 'working');
  });

  test('schema 9 preserves detailed unilateral side values', () async {
    final payload = jsonEncode({
      'format': 'gym_tracker_backup',
      'schemaVersion': 9,
      'exportedAt': '2026-09-01T12:00:00.000Z',
      'appVersion': '1.0.0',
      'data': {
        'settings': {},
        'exercises': [],
        'routines': [],
        'workouts': [
          {
            'id': 'detailed-session',
            'routineId': 'legs',
            'routineNameSnapshot': 'Pierna',
            'startedAt': '2026-09-01T12:00:00.000Z',
            'finishedAt': '2026-09-01T13:00:00.000Z',
            'durationSeconds': 3600,
            'notes': '',
            'exercises': [
              {
                'exerciseId': 'split-squat',
                'exerciseNameSnapshot': 'Split squat',
                'muscleGroupSnapshot': 'Piernas',
                'notes': '',
                'unilateral': true,
                'unilateralTarget': 'leg',
                'sets': [
                  {
                    'weight': 20,
                    'reps': 8,
                    'completed': true,
                    'rir': 2,
                    'warmup': false,
                    'setType': 'working',
                    'restSeconds': 120,
                    'leftCompleted': true,
                    'rightCompleted': true,
                    'leftWeight': 20,
                    'leftReps': 10,
                    'leftRir': 2,
                    'rightWeight': 22,
                    'rightReps': 8,
                    'rightRir': 1,
                    'sideRestSeconds': 45,
                  }
                ],
              }
            ],
          }
        ],
        'personalRecords': [],
        'bodyMeasurements': [],
        'favoriteVerses': [],
        'gamification': {},
        'hydration': {},
        'recovery': {},
      },
    });

    final service = BackupService();
    final validation = service.validateBackup(payload);
    expect(validation.isValid, isTrue);

    await service.restoreBackup(
      validation.parsedData!,
      schemaVersion: validation.schemaVersion!,
    );

    final workouts = Hive.box<HiveWorkoutSession>(HiveBoxes.history).values;
    final set = workouts.single.exercises.single.sets.single;
    expect(set.leftWeight, 20);
    expect(set.leftReps, 10);
    expect(set.leftRir, 2);
    expect(set.rightWeight, 22);
    expect(set.rightReps, 8);
    expect(set.rightRir, 1);
    expect(set.sideRestSeconds, 45);
  });
  test('DATA-09: current backups preserve explicit set outcomes', () async {
    final history = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    await history.clear();
    await history.put('outcomes', HiveWorkoutSession(
      id: 'outcomes',
      routineNameSnapshot: 'Outcomes',
      startedAt: DateTime(2026, 11, 5, 8),
      finishedAt: DateTime(2026, 11, 5, 9),
      durationSeconds: 3600,
      exercises: [
        HiveWorkoutExercise(
          exerciseId: 'press',
          sets: [
            HiveWorkoutSet(weight: 50, reps: 0,
                completed: false, recordedOutcome: 'skipped'),
            HiveWorkoutSet(weight: 50, reps: 0,
                completed: false, recordedOutcome: 'failed'),
            HiveWorkoutSet(weight: 50, reps: 0, completed: false),
            HiveWorkoutSet(weight: 50, reps: 8, completed: true),
          ],
        ),
      ],
    ));
    final backup = BackupService().createBackup();
    final validated = BackupService().validateBackup(backup);
    expect(validated.isValid, true);
    final rawWorkouts = validated.parsedData!['workouts'] as List;
    final rawSets = ((rawWorkouts.single as Map)['exercises'] as List)
        .single['sets'] as List;
    expect(rawSets.map((s) => s['recordedOutcome']).toList(),
        ['skipped', 'failed', null, null]);

    await BackupService().restoreBackup(validated.parsedData!,
        schemaVersion: validated.schemaVersion!);
    final restored = history.get('outcomes')!;
    expect(restored.exercises.single.sets
        .map((s) => s.recordedOutcome).toList(),
        ['skipped', 'failed', null, null]);
  });

  test('A5 guest backup roundtrip retains history, wellness and metadata',
      () async {
    final metadata = Hive.box(HiveBoxes.metadata);
    final history = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    final hydration = Hive.box(HiveBoxes.hydration);
    final recovery = Hive.box(HiveBoxes.recovery);
    final habitTasks = Hive.box(HiveBoxes.habitTasks);

    await metadata.clear();
    await history.clear();
    await hydration.clear();
    await recovery.clear();
    await habitTasks.clear();

    await metadata.put('db_version', 16);
    await metadata.put('user_experience_profile_v1', {
      'onboardingVersion': 2,
      'trainingDaysPerWeek': 3,
      'faithPreference': 'undecided',
      'hasCompletedOnboarding': true,
    });
    await history.put('guest-offline-session', HiveWorkoutSession(
      id: 'guest-offline-session',
      routineNameSnapshot: 'Full body',
      startedAt: DateTime.utc(2026, 11, 16, 7),
      finishedAt: DateTime.utc(2026, 11, 16, 8),
      durationSeconds: 3600,
      exercises: [
        HiveWorkoutExercise(
          exerciseId: 'squat',
          sets: [
            HiveWorkoutSet(weight: 42.5, reps: 8, completed: true),
            HiveWorkoutSet(weight: 0, reps: 0,
                completed: false, recordedOutcome: 'skipped'),
          ],
        ),
      ],
    ));
    await hydration.put('2026-11-16', {
      'dateString': '2026-11-16',
      'waterMl': 1300,
    });
    await recovery.put('2026-11-16', {'sleepHours': 7.5});
    await habitTasks.put('habit::reading', {'completed': true});
    await habitTasks.put('runtime::session_flag', 'never export this');

    final service = BackupService();
    final json = service.createBackup();
    final validated = service.validateBackup(json);
    expect(validated.isValid, isTrue);
    expect(validated.schemaVersion,
        BackupService.currentBackupSchemaVersion);
    final data = validated.parsedData!;
    final settings = data['settings'] as Map<String, dynamic>;
    expect(settings.containsKey('db_version'), isFalse);
    final storedHabits = data['habitTasksStore'] as Map<String, dynamic>;
    expect(storedHabits.containsKey('runtime::session_flag'), isFalse);
    expect(storedHabits.containsKey('habit::reading'), isTrue);

    // Simulate reinstall/restore: the installed DB version must survive.
    await metadata.put('db_version', 17);
    await metadata.delete('user_experience_profile_v1');
    await history.clear();
    await hydration.clear();
    await recovery.clear();
    await habitTasks.clear();
    await service.restoreBackup(data,
        schemaVersion: validated.schemaVersion!);

    final restoredProfile =
        metadata.get('user_experience_profile_v1') as Map;
    expect(restoredProfile['trainingDaysPerWeek'], 3);
    expect(restoredProfile['faithPreference'], 'undecided');
    expect(metadata.get('db_version'), 17);
    expect(history.keys, contains('guest-offline-session'));
    final restored = history.get('guest-offline-session')!;
    expect(restored.exercises.single.sets.first.weight, 42.5);
    expect(restored.exercises.single.sets.first.reps, 8);
    expect(restored.exercises.single.sets.first.completed, isTrue);
    expect(restored.exercises.single.sets.first.recordedOutcome, isNull);
    expect(restored.exercises.single.sets.last.recordedOutcome, 'skipped');
    expect((hydration.get('2026-11-16') as Map)['waterMl'], 1300);
    expect((recovery.get('2026-11-16') as Map)['sleepHours'], 7.5);
    expect(habitTasks.containsKey('habit::reading'), isTrue);
    expect(habitTasks.containsKey('runtime::session_flag'), isFalse);
  });

  test('C07 nutrition preference remains owner-scoped across full restore',
      () async {
    final metadata = Hive.box(HiveBoxes.metadata);
    final alice = StkNutritionIntentRepository(metadata, ownerId: 'alice');
    final bob = StkNutritionIntentRepository(metadata, ownerId: 'bob');
    final guest = StkNutritionIntentRepository(metadata, ownerId: null);
    await alice.save(StkNutritionIntent.volume);
    await bob.save(StkNutritionIntent.maintenance);
    await guest.save(StkNutritionIntent.deficit);

    final service = BackupService();
    final validated = service.validateBackup(service.createBackup());
    expect(validated.isValid, isTrue);
    final settings = validated.parsedData!['settings'] as Map<String, dynamic>;
    expect(settings[alice.storageKey]['intent'], 'volume');
    expect(settings[bob.storageKey]['intent'], 'maintenance');
    expect(settings[guest.storageKey]['intent'], 'deficit');

    await alice.clear();
    await bob.clear();
    await guest.clear();
    expect(alice.read(), isNull);
    expect(bob.read(), isNull);
    expect(guest.read(), isNull);
    await service.restoreBackup(validated.parsedData!,
        schemaVersion: validated.schemaVersion!);

    expect(alice.read(), StkNutritionIntent.volume);
    expect(bob.read(), StkNutritionIntent.maintenance);
    expect(guest.read(), StkNutritionIntent.deficit);
    await guest.clear();
    expect(alice.read(), StkNutritionIntent.volume);
    expect(bob.read(), StkNutritionIntent.maintenance);
  });

  test('A5 corrupt restore preflight leaves populated Hive boxes intact',
      () async {
    final metadata = Hive.box(HiveBoxes.metadata);
    final history = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    final beforeHistory = history.toMap();
    final beforeSettings = metadata.toMap();
    await expectLater(
      BackupService().restoreBackup({
        'settings': {'user_experience_profile_v1': {}},
        'workouts': [
          {'id': 'collision'},
          {'id': 'collision'},
        ],
      }, schemaVersion: BackupService.currentBackupSchemaVersion),
      throwsA(isA<FormatException>()),
    );
    expect(history.toMap(), beforeHistory);
    expect(metadata.toMap(), beforeSettings);
  });



  test('A5 concurrent local/cloud restores are serialized without data loss',
      () async {
    final metadata = Hive.box(HiveBoxes.metadata);
    final history = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    final payload = <String, dynamic>{
      'settings': {'backup_owner_hint': 'guest-device'},
      'workouts': [
        {
          'id': 'only-approved-restore',
          'routineNameSnapshot': 'Rutina original',
          'startedAt': '2026-11-16T07:00:00.000Z',
          'finishedAt': '2026-11-16T08:00:00.000Z',
          'durationSeconds': 3600,
          'exercises': <dynamic>[],
        },
      ],
    };
    // First call acquires the shared lock synchronously before clearing Hive.
    final first = BackupService().restoreBackup(payload);
    await expectLater(
      BackupService().restoreBackup({
        'settings': {'backup_owner_hint': 'other-account'},
      }),
      throwsA(isA<StateError>()),
    );
    await first;
    expect(metadata.get('backup_owner_hint'), 'guest-device');
    expect(history.containsKey('only-approved-restore'), isTrue);

    // The lock is released after successful restore and can be used again.
    await BackupService().restoreBackup(payload);
    expect(history.containsKey('only-approved-restore'), isTrue);

    // A rejected malformed import must also release the lock.
    await expectLater(
      BackupService().restoreBackup({
        'settings': {},
        'workouts': [
          {'id': 'duplicate-id'},
          {'id': 'duplicate-id'},
        ],
      }),
      throwsA(isA<FormatException>()),
    );
    await BackupService().restoreBackup(payload);
    expect(metadata.get('backup_owner_hint'), 'guest-device');
  });

}
