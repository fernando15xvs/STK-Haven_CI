import 'dart:io';

import 'package:core/core/services/backup_service.dart';
import 'package:core/features/recovery/application/sleep_diary.dart';
import 'package:core/database/hive/hive_adapters.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/database/hive/models/hive_body_measurement.dart';
import 'package:core/database/hive/models/hive_exercise.dart';
import 'package:core/database/hive/models/hive_personal_record.dart';
import 'package:core/database/hive/models/hive_routine.dart';
import 'package:core/database/hive/models/hive_workout_session.dart';
import 'package:core/domain/models/hive_favorite_verse.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_adaptation_policy.dart';
import 'package:core/features/programs/data/training_program_repository.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/profile/data/settings_repository.dart';
import 'package:core/features/profile/data/user_experience_profile_repository.dart';
import 'package:riverpod/riverpod.dart';
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

  test('F: appearance survives real Hive restart and backup restore without data loss', () async {
    final meta = Hive.box<dynamic>(HiveBoxes.metadata);
    await meta.put(SettingsRepository.storageKey, {
      'hasCompletedOnboarding': true,
      'weightUnit': 'lb',
      'defaultIncrement': 5.0,
      'unilateralSideRestSeconds': 75,
      'timerSoundEnabled': false,
      'appearance': {'mode': 'light', 'accent': 'violet'},
    });
    const profile = UserExperienceProfile(
      displayName: 'Fixture offline',
      trainingDaysPerWeek: 4,
      trainingGoal: TrainingGoal.hypertrophy,
      onboardingVersion: 2,
      optionalDemographicsConsented: false,
    );
    await UserExperienceProfileRepository(meta).saveProfile(profile);
    await Hive.box<HiveWorkoutSession>(HiveBoxes.history)
        .put('original', originalWorkout('original'));
    final container = ProviderContainer();
    const appearance = AppearanceSettings(
      mode: AppThemeMode.system,
      accent: AppAccent.emerald,
      oledBlack: true,
      uiStyle: AppUiStyle.compact,
      fontFamily: AppFontFamily.manrope,
      textSize: AppTextSize.custom,
      customTextScale: 1.45,
    );
    final before = container.read(settingsProvider);
    expect(before.appearance.fontFamily, AppFontFamily.outfit);
    expect(before.hasCompletedOnboarding, isTrue);
    await container.read(settingsProvider.notifier).setAppearance(appearance);
    final expected = before.copyWith(appearance: appearance).toJson();
    expect(container.read(settingsProvider).toJson(), expected);
    container.dispose();

    await Hive.close();
    Hive.init(tempDir.path);
    await openRestoreBoxes();
    final reopened = Hive.box<dynamic>(HiveBoxes.metadata);
    expect(SettingsRepository(reopened).getSettings().toJson(), expected);
    expect(UserExperienceProfileRepository(reopened).getStoredProfile()?.toJson(),
        profile.toJson());
    final service = BackupService();
    final backup = service.validateBackup(service.createBackup());
    expect(backup.isValid, isTrue, reason: backup.errorMessage);
    // Simulated replacement only in these disposable test boxes.
    await SettingsRepository(reopened).saveSettings(const SettingsState());
    await service.restoreBackup(
      backup.parsedData!, schemaVersion: backup.schemaVersion!,
    );
    expect(SettingsRepository(reopened).getSettings().toJson(), expected);
    expect(UserExperienceProfileRepository(reopened).getStoredProfile()?.toJson(),
        profile.toJson());
    final restored = Hive.box<HiveWorkoutSession>(HiveBoxes.history)
        .get('original')!;
    expect(restored.exercises.single.sets.first.weight, 50);
    expect(restored.exercises.single.sets.first.reps, 8);
    expect(restored.exercises.single.sets.last.recordedOutcome, 'skipped');
  });

  test('A: legacy and weekly programs survive Hive restart and actual backup restore', () async {
    final box = await Hive.openBox<dynamic>(HiveBoxes.trainingPrograms);
    final repository = TrainingProgramRepository(box);
    final start = DateTime(2026, 11, 23);
    final legacy = TrainingProgram(id: 'old', name: 'Stoker', routineIds: ['A','B','C','D'],
      createdAt: start, startedAt: start, targetSessionsPerWeek: 5,
      scheduleMode: ProgramScheduleMode.flexible, nextRotationIndex: 1,
      completions: [ProgramCompletion(workoutSessionId: 'old-a', routineId: 'A',
        completedAt: DateTime(2026,11,23,12), rotationIndex: 0, programWeek: 1)]);
    final raw = legacy.toJson()..remove('sequencePolicy')..remove('weeklySequenceRoutineIds');
    await Hive.box<dynamic>(HiveBoxes.metadata).put(TrainingProgramRepository.backupMetadataKey, [raw]);
    expect(repository.getById('old')!.nextRoutineId, 'B');
    final weekly = legacy.copyWith(id: 'weekly', isActive: false,
      sequencePolicy: ProgramSequencePolicy.weekly,
      weeklySequenceRoutineIds: ['A','B','C','D','A'],
      sequenceEffectiveAt: DateTime(2026,11,24));
    final adapted = ProgramAdaptationPolicy.pause(weekly, const [], DateTime(2026,11,25),
        routineIds: {'B'}, until: DateTime(2026,11,27));
    await repository.save(adapted);
    await Hive.close();
    Hive.init(tempDir.path);
    await openRestoreBoxes();
    final reopened = TrainingProgramRepository(await Hive.openBox<dynamic>(HiveBoxes.trainingPrograms));
    expect(reopened.getById('old')!.sequencePolicy, ProgramSequencePolicy.rolling);
    expect(reopened.getById('weekly')!.toJson(), adapted.toJson());
    final backup = BackupService().validateBackup(BackupService().createBackup());
    expect(backup.isValid, isTrue, reason: backup.errorMessage);
    // Only disposable fixture boxes are overwritten.
    await reopened.delete('weekly');
    await BackupService().restoreBackup(backup.parsedData!, schemaVersion: backup.schemaVersion!);
    await reopened.hydrateFromBackupMetadata();
    expect(reopened.getById('weekly')!.toJson(), adapted.toJson());
    expect(reopened.getById('old')!.nextRoutineId, 'B');
    expect(reopened.getById('old')!.completions.single.workoutSessionId, 'old-a');
  });

  test('Home sleep duration and personal goal survive restart and real backup restore', () async {
    final now = DateTime(2026,11,25);
    final repository = SleepDiaryRepository(Hive.box<dynamic>(HiveBoxes.metadata));
    await repository.save(SleepDiary.empty().withEntry(now, 450).withGoal(510));
    await Hive.close();
    Hive.init(tempDir.path);
    await openRestoreBoxes();
    final reopened = SleepDiaryRepository(Hive.box<dynamic>(HiveBoxes.metadata));
    expect(reopened.read().minutesFor(now), 450);
    expect(reopened.read().goalMinutes, 510);
    final service = BackupService();
    final backup = service.validateBackup(service.createBackup());
    expect(backup.isValid, isTrue, reason: backup.errorMessage);
    await reopened.save(SleepDiary.empty());
    await service.restoreBackup(backup.parsedData!, schemaVersion: backup.schemaVersion!);
    expect(reopened.read().minutesFor(now), 450);
    expect(reopened.read().goalMinutes, 510);
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
