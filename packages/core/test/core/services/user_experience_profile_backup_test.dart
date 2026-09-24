import 'dart:convert';

import 'package:core/core/services/backup_service.dart';
import 'package:core/features/profile/data/user_experience_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Roadmap 3 profile backup compatibility', () {
    test('schema v9 preserves serialized user experience profile metadata', () {
      final service = BackupService();
      final json = jsonEncode({
        'format': 'gym_tracker_backup',
        'schemaVersion': 9,
        'data': {
          'settings': {
            UserExperienceProfileRepository.storageKey: {
              'capabilities': ['athlete', 'coach'],
              'trainingGoal': 'hypertrophy',
              'trainingExperience': 'intermediate',
              'trainingDaysPerWeek': 4,
              'sessionDuration': 'minutes60',
              'trainingEnvironment': 'fullGym',
              'planningPreference': 'recommendation',
              'weightUnit': 'kg',
              'workoutRemindersWanted': true,
              'faithPreference': 'enabled',
              'faithEnabled': true,
              'habitsEnabled': true,
              'onboardingVersion': 2,
            },
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

      final result = service.validateBackup(json);
      final settings =
          result.parsedData?['settings'] as Map<String, dynamic>? ?? {};
      final profile = Map<String, dynamic>.from(
        settings[UserExperienceProfileRepository.storageKey] as Map,
      );

      expect(result.isValid, isTrue);
      expect(profile['trainingDaysPerWeek'], 4);
      expect(profile['faithPreference'], 'enabled');
      expect(profile['capabilities'], ['athlete', 'coach']);
    });

    test('older backup without experience profile remains valid', () {
      final service = BackupService();
      final json = jsonEncode({
        'format': 'gym_tracker_backup',
        'schemaVersion': 8,
        'data': {
          'settings': {
            'app_settings': {
              'weightUnit': 'kg',
              'hasCompletedOnboarding': true,
            },
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

      final result = service.validateBackup(json);

      expect(result.isValid, isTrue);
      expect(result.schemaVersion, 8);
    });
  });
}
