import 'dart:convert';

import 'package:core/core/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Habit tasks backup schema v10', () {
    test('accepts and preserves habit task store', () {
      final service = BackupService();
      final json = jsonEncode({
        'format': 'gym_tracker_backup',
        'schemaVersion': 10,
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
          'habitTasksStore': {
            'task::read': {
              'id': 'read',
              'title': 'Leer la Biblia',
              'category': 'Fe',
              'type': 'readingTimer',
              'targetMinutes': 10,
              'recurrence': 'daily',
              'weekdays': [],
              'createdAt': '2026-09-24T08:00:00.000',
              'updatedAt': '2026-09-24T08:00:00.000',
              'source': 'user',
              'visibility': 'private',
              'faithSpecific': true,
              'reference': 'Juan 1',
              'notes': '',
              'archived': false,
            },
            'completion::c1': {
              'id': 'c1',
              'taskId': 'read',
              'completedAt': '2026-09-24T08:10:00.000',
              'minutesSpent': 10,
              'note': '',
            },
          },
        },
      });

      final result = service.validateBackup(json);
      final store =
          result.parsedData?['habitTasksStore'] as Map<String, dynamic>?;

      expect(result.isValid, isTrue);
      expect(result.schemaVersion, 10);
      expect(store?['task::read'], isNotNull);
      expect(store?['completion::c1'], isNotNull);
    });

    test('schema v9 remains valid and defaults habit store to empty', () {
      final service = BackupService();
      final json = jsonEncode({
        'format': 'gym_tracker_backup',
        'schemaVersion': 9,
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

      final result = service.validateBackup(json);

      expect(result.isValid, isTrue);
      expect(result.schemaVersion, 9);
    });
  });
}
