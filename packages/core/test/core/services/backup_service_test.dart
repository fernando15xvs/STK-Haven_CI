import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:core/core/services/backup_service.dart';

void main() {
  group('BackupService', () {
    test('validateBackup returns false for invalid JSON', () {
      final service = BackupService();
      final result = service.validateBackup('not json');
      expect(result.isValid, false);
      expect(result.errorMessage, contains('El archivo está corrupto'));
    });

    test('validateBackup returns false for invalid format', () {
      final service = BackupService();
      final result = service.validateBackup('{"format": "wrong_format"}');
      expect(result.isValid, false);
    });

    test('validateBackup keeps compatibility with valid v2 backups', () {
      final service = BackupService();
      final validJson = jsonEncode({
        'format': 'gym_tracker_backup',
        'schemaVersion': 2,
        'data': {
          'settings': {},
          'exercises': [],
          'routines': [],
          'workouts': [],
          'personalRecords': [],
          'bodyMeasurements': [],
        },
      });

      final result = service.validateBackup(validJson);

      expect(result.isValid, true);
      expect(result.schemaVersion, 2);
    });

    test('validateBackup accepts v4 hydration and gamification payloads', () {
      final service = BackupService();
      final validJson = jsonEncode({
        'format': 'gym_tracker_backup',
        'schemaVersion': 4,
        'data': {
          'settings': {'db_version': 1},
          'exercises': [],
          'routines': [],
          'workouts': [],
          'personalRecords': [],
          'bodyMeasurements': [],
          'favoriteVerses': [],
          'gamification': {
            'gamification_state': {
              'xp': 100,
              'processedWorkoutIds': ['workout-1'],
            },
          },
          'hydration': {
            '2026-08-21': {
              'dateString': '2026-08-21',
              'waterMl': 750,
            },
          },
        },
      });

      final result = service.validateBackup(validJson);

      expect(result.isValid, true);
      expect(result.schemaVersion, 4);
      expect(result.parsedData?['gamification'], isNotNull);
      expect(result.parsedData?['hydration'], isNotNull);
    });

    test('validateBackup accepts v6 recovery payloads', () {
      final service = BackupService();
      final validJson = jsonEncode({
        'format': 'gym_tracker_backup',
        'schemaVersion': 6,
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
          'recovery': {
            '2026-08-31': {
              'date': '2026-08-31T00:00:00.000',
              'energy': 4,
              'sleep': 5,
              'stress': 2,
              'soreness': 2,
              'updatedAt': '2026-08-31T19:00:00.000',
            },
          },
        },
      });

      final result = service.validateBackup(validJson);

      expect(result.isValid, true);
      expect(result.schemaVersion, 6);
      expect(result.parsedData?['recovery'], isNotNull);
    });

    test('validateBackup accepts v7 workout superset payloads', () {
      final service = BackupService();
      final validJson = jsonEncode({
        'format': 'gym_tracker_backup',
        'schemaVersion': 7,
        'data': {
          'settings': {},
          'exercises': [],
          'routines': [],
          'workouts': [
            {
              'id': 'workout-1',
              'routineId': 'routine-1',
              'routineNameSnapshot': 'Push',
              'startedAt': '2026-09-01T10:00:00.000',
              'finishedAt': '2026-09-01T11:00:00.000',
              'durationSeconds': 3600,
              'notes': '',
              'currentRestEndsAt': null,
              'exercises': [
                {
                  'exerciseId': 'bench',
                  'notes': '',
                  'exerciseNameSnapshot': 'Press banca',
                  'muscleGroupSnapshot': 'Pecho',
                  'unilateral': false,
                  'unilateralTarget': 'other',
                  'supersetGroupId': 'superset-1',
                  'sets': [
                    {
                      'weight': 80.0,
                      'reps': 8,
                      'completed': true,
                      'rir': 2,
                      'warmup': false,
                      'setType': 'working',
                      'restSeconds': 90,
                      'leftCompleted': false,
                      'rightCompleted': false,
                    },
                  ],
                },
                {
                  'exerciseId': 'row',
                  'notes': '',
                  'exerciseNameSnapshot': 'Remo',
                  'muscleGroupSnapshot': 'Espalda',
                  'unilateral': false,
                  'unilateralTarget': 'other',
                  'supersetGroupId': 'superset-1',
                  'sets': [
                    {
                      'weight': 60.0,
                      'reps': 10,
                      'completed': true,
                      'rir': 2,
                      'warmup': false,
                      'setType': 'working',
                      'restSeconds': 120,
                      'leftCompleted': false,
                      'rightCompleted': false,
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

      final result = service.validateBackup(validJson);

      expect(result.isValid, true);
      expect(result.schemaVersion, 7);
    });

    test('validateBackup preserves v7 routine superset groups', () {
      final service = BackupService();
      final validJson = jsonEncode({
        'format': 'gym_tracker_backup',
        'schemaVersion': 7,
        'data': {
          'settings': {},
          'exercises': [],
          'routines': [
            {
              'id': 'routine-1',
              'name': 'Upper',
              'scheduledDays': [1, 4],
              'createdAt': '2026-09-01T09:00:00.000',
              'exercises': [
                {
                  'exerciseId': 'bench',
                  'order': 0,
                  'targetSets': 3,
                  'targetRepsMin': 8,
                  'targetRepsMax': 12,
                  'restSeconds': 90,
                  'warmupSets': 1,
                  'approachSets': 0,
                  'unilateral': false,
                  'unilateralTarget': 'other',
                  'supersetGroupId': 'routine-pair-1',
                },
                {
                  'exerciseId': 'row',
                  'order': 1,
                  'targetSets': 3,
                  'targetRepsMin': 8,
                  'targetRepsMax': 12,
                  'restSeconds': 120,
                  'warmupSets': 0,
                  'approachSets': 1,
                  'unilateral': false,
                  'unilateralTarget': 'other',
                  'supersetGroupId': 'routine-pair-1',
                },
              ],
            },
          ],
          'workouts': [],
          'personalRecords': [],
          'bodyMeasurements': [],
          'favoriteVerses': [],
          'gamification': {},
          'hydration': {},
          'recovery': {},
        },
      });

      final result = service.validateBackup(validJson);
      final routines = result.parsedData?['routines'] as List;
      final routine = Map<String, dynamic>.from(routines.single as Map);
      final routineExercises = routine['exercises'] as List;
      final first = Map<String, dynamic>.from(routineExercises[0] as Map);
      final second = Map<String, dynamic>.from(routineExercises[1] as Map);

      expect(result.isValid, true);
      expect(routines, hasLength(1));
      expect(routineExercises, hasLength(2));
      expect(first['supersetGroupId'], 'routine-pair-1');
      expect(second['supersetGroupId'], 'routine-pair-1');
    });

    test('validateBackup accepts v8 routine notes and keeps old defaults', () {
      final service = BackupService();
      final validJson = jsonEncode({
        'format': 'gym_tracker_backup',
        'schemaVersion': 8,
        'data': {
          'settings': {},
          'exercises': [],
          'routines': [
            {
              'id': 'routine-1',
              'name': 'Push A',
              'notes': 'Priorizar técnica y subir 2.5 kg si completo el rango.',
              'scheduledDays': [1],
              'createdAt': '2026-09-01T09:00:00.000',
              'exercises': [],
            },
            {
              'id': 'routine-legacy',
              'name': 'Legacy',
              'scheduledDays': [],
              'createdAt': '2026-08-01T09:00:00.000',
              'exercises': [],
            },
          ],
          'workouts': [],
          'personalRecords': [],
          'bodyMeasurements': [],
          'favoriteVerses': [],
          'gamification': {},
          'hydration': {},
          'recovery': {},
        },
      });

      final result = service.validateBackup(validJson);
      final routines = result.parsedData?['routines'] as List;
      final first = Map<String, dynamic>.from(routines[0] as Map);
      final legacy = Map<String, dynamic>.from(routines[1] as Map);

      expect(result.isValid, true);
      expect(result.schemaVersion, 8);
      expect(
        first['notes'],
        'Priorizar técnica y subir 2.5 kg si completo el rango.',
      );
      expect(legacy['notes'], isNull);
    });

    test('validateBackup rejects future unsupported schema versions', () {
      final service = BackupService();
      final invalidJson = jsonEncode({
        'format': 'gym_tracker_backup',
        'schemaVersion': BackupService.currentBackupSchemaVersion + 1,
        'data': {},
      });

      final result = service.validateBackup(invalidJson);

      expect(result.isValid, false);
      expect(result.errorMessage, contains('Versión del backup'));
    });
  });
}
