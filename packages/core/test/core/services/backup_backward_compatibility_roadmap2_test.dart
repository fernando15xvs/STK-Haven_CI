import 'dart:convert';
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
import 'package:flutter_test/flutter_test.dart';
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
}
