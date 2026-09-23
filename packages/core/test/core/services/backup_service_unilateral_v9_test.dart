import 'dart:convert';

import 'package:core/core/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema v9 accepts detailed unilateral side performance', () {
    final service = BackupService();
    final json = jsonEncode({
      'format': 'gym_tracker_backup',
      'schemaVersion': 9,
      'data': {
        'settings': {},
        'exercises': [],
        'routines': [],
        'workouts': [
          {
            'id': 'w1',
            'routineId': 'push-a',
            'routineNameSnapshot': 'Push A',
            'startedAt': '2026-09-06T10:00:00.000',
            'finishedAt': '2026-09-06T11:00:00.000',
            'durationSeconds': 3600,
            'notes': '',
            'currentRestEndsAt': null,
            'exercises': [
              {
                'exerciseId': 'unilateral-row',
                'notes': '',
                'exerciseNameSnapshot': 'Remo unilateral',
                'muscleGroupSnapshot': 'Espalda',
                'unilateral': true,
                'unilateralTarget': 'back',
                'supersetGroupId': null,
                'sets': [
                  {
                    'weight': 20.0,
                    'reps': 9,
                    'completed': true,
                    'rir': 1,
                    'warmup': false,
                    'setType': 'working',
                    'restSeconds': 90,
                    'leftCompleted': true,
                    'rightCompleted': true,
                    'leftWeight': 20.0,
                    'leftReps': 10,
                    'leftRir': 2,
                    'rightWeight': 20.0,
                    'rightReps': 9,
                    'rightRir': 1,
                    'sideRestSeconds': 45,
                  },
                ],
              },
            ],
          },
        ],
        'personalRecords': [],
        'bodyMeasurements': [],
        'favoriteVerses': [],
        'gamification': {},
        'hydration': {},
        'recovery': {},
      },
    });

    final result = service.validateBackup(json);

    expect(result.isValid, true);
    expect(result.schemaVersion, 9);
    final workouts = result.parsedData!['workouts'] as List;
    final exercise = (workouts.single['exercises'] as List).single;
    final set = (exercise['sets'] as List).single;
    expect(set['leftReps'], 10);
    expect(set['rightReps'], 9);
    expect(set['sideRestSeconds'], 45);
  });

  test('schema v8 workout without detailed sides remains valid', () {
    final service = BackupService();
    final json = jsonEncode({
      'format': 'gym_tracker_backup',
      'schemaVersion': 8,
      'data': {
        'settings': {},
        'exercises': [],
        'routines': [],
        'workouts': [],
        'personalRecords': [],
        'bodyMeasurements': [],
        'favoriteVerses': [],
        'gamification': {},
        'hydration': {},
        'recovery': {},
      },
    });

    expect(service.validateBackup(json).isValid, true);
  });
}
