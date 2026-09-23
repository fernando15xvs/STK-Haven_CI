import 'dart:convert';

import 'package:core/core/services/backup_service.dart';
import 'package:core/features/exercises/data/exercise_favorites_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup validation preserves favorite exercise ids in metadata settings', () {
    final service = BackupService();
    final backup = jsonEncode({
      'format': 'gym_tracker_backup',
      'schemaVersion': BackupService.currentBackupSchemaVersion,
      'data': {
        'settings': {
          ExerciseFavoritesRepository.storageKey: ['bench', 'row'],
        },
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

    final result = service.validateBackup(backup);
    final settings = result.parsedData?['settings'] as Map<String, dynamic>;

    expect(result.isValid, true);
    expect(
      settings[ExerciseFavoritesRepository.storageKey],
      ['bench', 'row'],
    );
  });
}
