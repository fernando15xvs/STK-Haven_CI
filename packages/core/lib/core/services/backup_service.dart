import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/database/hive/models/hive_body_measurement.dart';
import 'package:core/database/hive/models/hive_exercise.dart';
import 'package:core/database/hive/models/hive_personal_record.dart';
import 'package:core/database/hive/models/hive_routine.dart';
import 'package:core/database/hive/models/hive_workout_session.dart';
import 'package:core/domain/models/hive_favorite_verse.dart';

class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic>? parsedData;
  final int? schemaVersion;

  const BackupValidationResult({
    required this.isValid,
    this.errorMessage,
    this.parsedData,
    this.schemaVersion,
  });
}

/// Counts only records actually merged into current v2 stores.
class BackupLegacyMergeResult {
  final int exercises;
  final int routines;
  final int workouts;
  final int duplicateIds;

  const BackupLegacyMergeResult({
    required this.exercises,
    required this.routines,
    required this.workouts,
    required this.duplicateIds,
  });

  int get imported => exercises + routines + workouts;
}

class BackupService {
  static const int currentBackupSchemaVersion = 11;
  static const String pendingRestoreJournalKey = 'pending_restore_v1';
  static const String _journalFormat = 'stk_haven_restore_journal_v1';

  // All BackupService instances (local + cloud) share one writer and one
  // recovery lock. The on-disk journal below protects against process death.
  static bool _restoreInProgress = false;

  String createBackup() {
    final metaBox = Hive.box(HiveBoxes.metadata);
    final exercisesBox = Hive.box<HiveExercise>(HiveBoxes.exercises);
    final routinesBox = Hive.box<HiveRoutine>(HiveBoxes.routines);
    final historyBox = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    final prBox = Hive.box<HivePersonalRecord>(HiveBoxes.personalRecords);
    final bodyBox = Hive.box<HiveBodyMeasurement>(HiveBoxes.bodyMeasurements);
    final favVerseBox = Hive.box<HiveFavoriteVerse>(HiveBoxes.favoriteVerses);
    final gamificationBox = Hive.box(HiveBoxes.gamification);
    final hydrationBox = Hive.box(HiveBoxes.hydration);
    final recoveryBox = Hive.box(HiveBoxes.recovery);
    final habitTasksBox = Hive.box(HiveBoxes.habitTasks);

    final settings = _normalizeMap(metaBox.toMap())..remove('db_version');

    final data = <String, dynamic>{
      'settings': settings,
      'exercises': exercisesBox.values.map(_exerciseToMap).toList(),
      'routines': routinesBox.values.map(_routineToMap).toList(),
      'workouts': historyBox.values.map(_workoutToMap).toList(),
      'personalRecords': prBox.values.map(_prToMap).toList(),
      'bodyMeasurements':
          bodyBox.values.map(_bodyMeasurementToMap).toList(),
      'favoriteVerses': favVerseBox.values.map(_favVerseToMap).toList(),
      'gamification': _normalizeMap(gamificationBox.toMap()),
      'hydration': _normalizeMap(hydrationBox.toMap()),
      'recovery': _normalizeMap(recoveryBox.toMap()),
      'habitTasksStore': _habitTasksBackupMap(habitTasksBox.toMap()),
    };

    final backup = <String, dynamic>{
      'format': 'gym_tracker_backup',
      'schemaVersion': currentBackupSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
      'data': data,
    };

    return jsonEncode(backup);
  }

  /// User-confirmed, non-destructive migration of compatible old Hive
  /// records. Merge into the CURRENT backup and use the same durable restore
  /// journal; never clear or overwrite an old source box.
  Future<BackupLegacyMergeResult> mergeLegacyRecords({
    List<HiveExercise> exercises = const [],
    List<HiveRoutine> routines = const [],
    List<HiveWorkoutSession> workouts = const [],
  }) async {
    if (_restoreInProgress) {
      throw StateError('Ya hay una restauración de datos en curso.');
    }
    _restoreInProgress = true;
    try {
      return await _mergeLegacyRecordsLocked(
        exercises: exercises,
        routines: routines,
        workouts: workouts,
      );
    } finally {
      _restoreInProgress = false;
    }
  }

  Future<BackupLegacyMergeResult> _mergeLegacyRecordsLocked({
    required List<HiveExercise> exercises,
    required List<HiveRoutine> routines,
    required List<HiveWorkoutSession> workouts,
  }) async {
    final existing = validateBackup(createBackup());
    if (!existing.isValid || existing.parsedData == null) {
      throw StateError('Los datos locales no permiten una migración segura.');
    }
    final updated = existing.parsedData!;
    var duplicates = 0;
    int append<T>(
      String collection,
      List<T> legacy,
      Map<String, dynamic> Function(T) encode,
    ) {
      final target = updated[collection] as List<dynamic>;
      final ids = <String>{
        for (final entry in target)
          (entry as Map)['id'] as String,
      };
      var added = 0;
      for (final record in legacy) {
        final payload = encode(record);
        final id = payload['id'];
        if (id is! String || id.trim().isEmpty) {
          throw StateError('El archivo antiguo tiene identificadores inválidos.');
        }
        // Never overwrite current records with an archived ID, and never
        // rename history records because personal records may reference IDs.
        if (!ids.add(id)) {
          duplicates++;
          continue;
        }
        target.add(payload);
        added++;
      }
      return added;
    }

    final nExercises = append('exercises', exercises, _exerciseToMap);
    final nRoutines = append('routines', routines, _routineToMap);
    final nWorkouts = append('workouts', workouts, _workoutToMap);
    final result = BackupLegacyMergeResult(
      exercises: nExercises,
      routines: nRoutines,
      workouts: nWorkouts,
      duplicateIds: duplicates,
    );
    if (result.imported > 0) {
      await _restoreBackupWithJournal(
        updated, schemaVersion: currentBackupSchemaVersion);
    }
    return result;
  }

  BackupValidationResult validateBackup(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'Formato inválido: no es un objeto JSON.',
        );
      }
      if (decoded['format'] != 'gym_tracker_backup') {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'El archivo no es un backup compatible de STK Haven.',
        );
      }
      final schemaVersion = decoded['schemaVersion'];
      if (schemaVersion is! int ||
          schemaVersion < 1 ||
          schemaVersion > currentBackupSchemaVersion) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'Versión del backup no compatible.',
        );
      }
      final rawData = decoded['data'];
      if (rawData is! Map) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'Datos corruptos o no encontrados.',
        );
      }
      final data = Map<String, dynamic>.from(rawData);
      _mapDataToHiveObjects(data, schemaVersion);
      return BackupValidationResult(
        isValid: true,
        parsedData: data,
        schemaVersion: schemaVersion,
      );
    } on FormatException catch (error) {
      // JSON/DateTime errors can quote a user's private original backup
      // contents, including local file paths. Only fixed service-generated
      // collection messages are safe to display to the user.
      const safePrefixes = [
        'Metadatos de respaldo inválidos:',
        'Datos de respaldo inválidos:',
        'Colección de respaldo inválida:',
        'Registro de respaldo inválido:',
        'Identificador de respaldo inválido:',
        'Identificador duplicado en respaldo:',
      ];
      final safeMessage = safePrefixes.any(
        (prefix) => error.message.startsWith(prefix),
      );
      return BackupValidationResult(
        isValid: false,
        errorMessage: safeMessage
            ? error.message
            : 'El archivo está corrupto o mal formado.',
      );
    } catch (_) {
      return const BackupValidationResult(
        isValid: false,
        errorMessage: 'El archivo está corrupto o mal formado.',
      );
    }
  }

  Future<void> restoreBackup(
    Map<String, dynamic> data, {
    int schemaVersion = currentBackupSchemaVersion,
    // Cloud callers can withdraw authority during a long-running restore.
    // If it changes, the durable journal rolls back ALL local box writes.
    bool Function()? allowCommit,
  }) async {
    if (allowCommit != null && !allowCommit()) {
      throw StateError('La cuenta cambió antes de restaurar la copia.');
    }
    if (_restoreInProgress) {
      throw StateError('Ya hay una restauración de datos en curso.');
    }
    _restoreInProgress = true;
    try {
      await _restoreBackupWithJournal(
        data, schemaVersion: schemaVersion, allowCommit: allowCommit,
      );
    } finally {
      _restoreInProgress = false;
    }
  }

  Future<void> _restoreBackupWithJournal(
    Map<String, dynamic> data, {
    required int schemaVersion,
    bool Function()? allowCommit,
  }) async {
    // Preflight must run before even opening a journal or touching a box.
    // A malformed imported file cannot trigger a destructive write.
    _mapDataToHiveObjects(data, schemaVersion);
    final journal = await Hive.openBox<dynamic>(HiveBoxes.restoreJournal);
    if (journal.containsKey(pendingRestoreJournalKey)) {
      throw StateError(
        'Existe una restauración anterior incompleta. '
        'Reinicia STK Haven antes de restaurar otra copia.',
      );
    }

    // Persist the previous device state BEFORE the first box.clear().
    // A power loss then restores the previous snapshot on next app launch,
    // rather than booting with a partially replaced training history.
    final snapshot = createBackup();
    final check = validateBackup(snapshot);
    if (!check.isValid) {
      throw StateError(
        'No se puede crear una copia de seguridad de los datos actuales.',
      );
    }
    await journal.put(pendingRestoreJournalKey, <String, dynamic>{
      'format': _journalFormat,
      'backup': snapshot,
      'db_version': Hive.box(HiveBoxes.metadata).get('db_version'),
    });
    await journal.flush();

    try {
      if (allowCommit != null && !allowCommit()) {
        throw StateError('La cuenta cambió durante la restauración.');
      }
      await _restoreBackupLocked(data, schemaVersion: schemaVersion);
      // The network session may have expired while Hive awaited disk writes.
      // Abort and replay the old snapshot BEFORE removing the recovery journal.
      if (allowCommit != null && !allowCommit()) {
        throw StateError('La cuenta cambió durante la restauración.');
      }
      // Never report success before the successful restore is committed
      // and the intent journal has been removed from local storage.
      await journal.delete(pendingRestoreJournalKey);
      await journal.flush();
    } catch (_) {
      // Revert immediately if possible. If this fails (disk full, OS
      // termination), leave the original snapshot on disk for next boot.
      try {
        await _recoverInterruptedRestoreLocked(journal);
      } catch (_) {
        throw StateError(
          'La restauración falló. Existe una copia de recuperación local '
          'pendiente; conserva tus archivos y reinicia STK Haven.',
        );
      }
      rethrow;
    }
  }

  /// Called by HiveDatabase.init AFTER all typed boxes and their adapters
  /// are available, but BEFORE providers can use partially restored records.
  /// Returns false when the previous shutdown had no unfinished restore.
  static Future<bool> recoverInterruptedRestore() async {
    if (_restoreInProgress) {
      throw StateError('Ya hay una restauración de datos en curso.');
    }
    _restoreInProgress = true;
    try {
      final journal = await Hive.openBox<dynamic>(HiveBoxes.restoreJournal);
      if (!journal.containsKey(pendingRestoreJournalKey)) return false;
      await BackupService()._recoverInterruptedRestoreLocked(journal);
      return true;
    } finally {
      _restoreInProgress = false;
    }
  }

  Future<void> _recoverInterruptedRestoreLocked(Box<dynamic> journal) async {
    final raw = journal.get(pendingRestoreJournalKey);
    if (raw is! Map ||
        raw['format'] != _journalFormat ||
        raw['backup'] is! String) {
      throw StateError(
        'La copia de recuperación local no es válida. '
        'No se ha eliminado ni modificado automáticamente.',
      );
    }
    final validation = validateBackup(raw['backup'] as String);
    if (!validation.isValid ||
        validation.parsedData == null ||
        validation.schemaVersion == null) {
      throw StateError(
        'La copia de recuperación local está dañada. '
        'No se ha eliminado ni modificado automáticamente.',
      );
    }

    // Recovery is idempotent. A crash during recovery leaves the journal
    // intact, so the next launch can safely retry the same old snapshot.
    await _restoreBackupLocked(
      validation.parsedData!,
      schemaVersion: validation.schemaVersion!,
    );
    final savedVersion = raw['db_version'];
    if (savedVersion is int) {
      await Hive.box(HiveBoxes.metadata).put('db_version', savedVersion);
    }
    await journal.delete(pendingRestoreJournalKey);
    await journal.flush();
  }

  Future<void> _restoreBackupLocked(
    Map<String, dynamic> data, {
    required int schemaVersion,
  }) async {
    final parsed = _mapDataToHiveObjects(data, schemaVersion);

    final metaBox = Hive.box(HiveBoxes.metadata);
    final exercisesBox = Hive.box<HiveExercise>(HiveBoxes.exercises);
    final routinesBox = Hive.box<HiveRoutine>(HiveBoxes.routines);
    final historyBox = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
    final prBox = Hive.box<HivePersonalRecord>(HiveBoxes.personalRecords);
    final bodyBox = Hive.box<HiveBodyMeasurement>(HiveBoxes.bodyMeasurements);
    final favVerseBox = Hive.box<HiveFavoriteVerse>(HiveBoxes.favoriteVerses);
    final gamificationBox = Hive.box(HiveBoxes.gamification);
    final hydrationBox = Hive.box(HiveBoxes.hydration);
    final recoveryBox = Hive.box(HiveBoxes.recovery);
    final habitTasksBox = Hive.box(HiveBoxes.habitTasks);

    final snapshotMeta = metaBox.toMap();
    final snapshotExercises = exercisesBox.toMap();
    final snapshotRoutines = routinesBox.toMap();
    final snapshotHistory = historyBox.toMap();
    final snapshotPRs = prBox.toMap();
    final snapshotBody = bodyBox.toMap();
    final snapshotFavs = favVerseBox.toMap();
    final snapshotGamification = gamificationBox.toMap();
    final snapshotHydration = hydrationBox.toMap();
    final snapshotRecovery = recoveryBox.toMap();
    final snapshotHabitTasks = habitTasksBox.toMap();
    final installedDbVersion = snapshotMeta['db_version'];

    try {
      await metaBox.clear();
      await exercisesBox.clear();
      await routinesBox.clear();
      await historyBox.clear();
      await prBox.clear();
      await bodyBox.clear();
      await favVerseBox.clear();
      await gamificationBox.clear();
      await hydrationBox.clear();
      await recoveryBox.clear();
      await habitTasksBox.clear();

      final settings = parsed['settings'] as Map<String, dynamic>;
      if (settings.isNotEmpty) await metaBox.putAll(settings);
      if (installedDbVersion != null) {
        await metaBox.put('db_version', installedDbVersion);
      }

      for (final exercise in parsed['exercises'] as List<HiveExercise>) {
        await exercisesBox.put(exercise.id, exercise);
      }
      for (final routine in parsed['routines'] as List<HiveRoutine>) {
        await routinesBox.put(routine.id, routine);
      }
      for (final workout in parsed['workouts'] as List<HiveWorkoutSession>) {
        await historyBox.put(workout.id, workout);
      }
      for (final record
          in parsed['personalRecords'] as List<HivePersonalRecord>) {
        await prBox.put(record.id, record);
      }
      for (final measurement
          in parsed['bodyMeasurements'] as List<HiveBodyMeasurement>) {
        await bodyBox.put(measurement.id, measurement);
      }
      for (final verse
          in parsed['favoriteVerses'] as List<HiveFavoriteVerse>) {
        await favVerseBox.put(verse.id, verse);
      }

      final gamification = parsed['gamification'] as Map<String, dynamic>;
      if (gamification.isNotEmpty) await gamificationBox.putAll(gamification);
      final hydration = parsed['hydration'] as Map<String, dynamic>;
      if (hydration.isNotEmpty) await hydrationBox.putAll(hydration);
      final recovery = parsed['recovery'] as Map<String, dynamic>;
      if (recovery.isNotEmpty) await recoveryBox.putAll(recovery);
      final habitTasksStore =
          parsed['habitTasksStore'] as Map<String, dynamic>;
      if (habitTasksStore.isNotEmpty) {
        await habitTasksBox.putAll(habitTasksStore);
      }
    } catch (_) {
      // Rollback is best-effort across multiple Hive boxes, not an atomic
      // transaction. Never claim success if rollback itself fails.
      try {
        await metaBox.clear();
        await exercisesBox.clear();
        await routinesBox.clear();
        await historyBox.clear();
        await prBox.clear();
        await bodyBox.clear();
        await favVerseBox.clear();
        await gamificationBox.clear();
        await hydrationBox.clear();
        await recoveryBox.clear();
        await habitTasksBox.clear();

        await metaBox.putAll(snapshotMeta);
        await exercisesBox.putAll(snapshotExercises);
        await routinesBox.putAll(snapshotRoutines);
        await historyBox.putAll(snapshotHistory);
        await prBox.putAll(snapshotPRs);
        await bodyBox.putAll(snapshotBody);
        await favVerseBox.putAll(snapshotFavs);
        await gamificationBox.putAll(snapshotGamification);
        await hydrationBox.putAll(snapshotHydration);
        await recoveryBox.putAll(snapshotRecovery);
        await habitTasksBox.putAll(snapshotHabitTasks);
      } catch (_) {
        throw StateError(
          'La restauración falló y no se pudo confirmar la reversión. '
          'Conserva el archivo de respaldo y revisa los datos del dispositivo.',
        );
      }
      throw StateError(
        'No se pudo completar la restauración. '
        'Se recuperaron los datos locales anteriores.',
      );
    }
  }

  Map<String, dynamic> _exerciseToMap(HiveExercise exercise) => {
        'id': exercise.id,
        'name': exercise.name,
        'muscleGroup': exercise.muscleGroup,
        'secondaryMuscles': exercise.secondaryMuscles,
        'equipment': exercise.equipment,
        'instructions': exercise.instructions,
        'media': exercise.media,
      };

  Map<String, dynamic> _routineToMap(HiveRoutine routine) => {
        'id': routine.id,
        'name': routine.name,
        'notes': routine.notes,
        'scheduledDays': routine.scheduledDays,
        'createdAt': routine.createdAt.toIso8601String(),
        'exercises': routine.exercises
            .map(
              (exercise) => {
                'exerciseId': exercise.exerciseId,
                'order': exercise.order,
                'targetSets': exercise.targetSets,
                'targetRepsMin': exercise.targetRepsMin,
                'targetRepsMax': exercise.targetRepsMax,
                'restSeconds': exercise.restSeconds,
                'warmupSets': exercise.warmupSets,
                'approachSets': exercise.approachSets,
                'warmupRestSeconds': exercise.warmupRestSeconds,
                'approachRestSeconds': exercise.approachRestSeconds,
                'unilateral': exercise.unilateral,
                'unilateralTarget': exercise.unilateralTarget,
                'preparationUnilateral': exercise.preparationUnilateral,
                'unilateralSideRestSeconds':
                    exercise.unilateralSideRestSeconds,
                'preferredUnilateralStartSide':
                    exercise.preferredUnilateralStartSide,
                'supersetGroupId': exercise.supersetGroupId,
                'phase': exercise.phase,
              },
            )
            .toList(),
      };

  Map<String, dynamic> _workoutToMap(HiveWorkoutSession workout) => {
        'id': workout.id,
        'routineId': workout.routineId,
        'routineNameSnapshot': workout.routineNameSnapshot,
        'startedAt': workout.startedAt.toIso8601String(),
        'finishedAt': workout.finishedAt.toIso8601String(),
        'durationSeconds': workout.durationSeconds,
        'notes': workout.notes,
        'currentRestEndsAt': workout.currentRestEndsAt?.toIso8601String(),
        'exercises': workout.exercises
            .map(
              (exercise) => {
                'exerciseId': exercise.exerciseId,
                'notes': exercise.notes,
                'exerciseNameSnapshot': exercise.exerciseNameSnapshot,
                'muscleGroupSnapshot': exercise.muscleGroupSnapshot,
                'unilateral': exercise.unilateral,
                'unilateralTarget': exercise.unilateralTarget,
                'preparationUnilateral': exercise.preparationUnilateral,
                'preferredUnilateralStartSide':
                    exercise.preferredUnilateralStartSide,
                'supersetGroupId': exercise.supersetGroupId,
                'sets': exercise.sets
                    .map(
                      (set) => {
                        'weight': set.weight,
                        'reps': set.reps,
                        'completed': set.completed,
                        'recordedOutcome': set.completed ? null : set.recordedOutcome,
                        'rir': set.rir,
                        'warmup': set.warmup,
                        'setType': set.setType,
                        'restSeconds': set.restSeconds,
                        'leftCompleted': set.leftCompleted,
                        'rightCompleted': set.rightCompleted,
                        'leftWeight': set.leftWeight,
                        'leftReps': set.leftReps,
                        'leftRir': set.leftRir,
                        'rightWeight': set.rightWeight,
                        'rightReps': set.rightReps,
                        'rightRir': set.rightRir,
                        'sideRestSeconds': set.sideRestSeconds,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      };

  Map<String, dynamic> _prToMap(HivePersonalRecord record) => {
        'id': record.id,
        'workoutSessionId': record.workoutSessionId,
        'exerciseId': record.exerciseId,
        'exerciseNameSnapshot': record.exerciseNameSnapshot,
        'type': record.type.name,
        'previousValue': record.previousValue,
        'newValue': record.newValue,
        'achievedAt': record.achievedAt.toIso8601String(),
      };

  Map<String, dynamic> _bodyMeasurementToMap(
    HiveBodyMeasurement measurement,
  ) =>
      {
        'id': measurement.id,
        'date': measurement.date.toIso8601String(),
        'weightKg': measurement.weightKg,
        'bodyFatPercentage': measurement.bodyFatPercentage,
        'shouldersCm': measurement.shouldersCm,
        'chestCm': measurement.chestCm,
        'waistCm': measurement.waistCm,
        'hipsCm': measurement.hipsCm,
        'leftArmCm': measurement.leftArmCm,
        'rightArmCm': measurement.rightArmCm,
        'leftLegCm': measurement.leftLegCm,
        'rightLegCm': measurement.rightLegCm,
        'calvesCm': measurement.calvesCm,
        'heightCm': measurement.heightCm,
        'neckCm': measurement.neckCm,
        'leftForearmCm': measurement.leftForearmCm,
        'rightForearmCm': measurement.rightForearmCm,
        'leftCalfCm': measurement.leftCalfCm,
        'rightCalfCm': measurement.rightCalfCm,
      };

  Map<String, dynamic> _favVerseToMap(HiveFavoriteVerse verse) => {
        'id': verse.id,
        'book': verse.book,
        'chapter': verse.chapter,
        'verse': verse.verse,
        'text': verse.text,
        'savedAt': verse.savedAt.toIso8601String(),
      };

  Map<String, dynamic> _mapDataToHiveObjects(
    Map<String, dynamic> data,
    int schemaVersion,
  ) {
    final rawSettings = data['settings'];
    if (rawSettings != null && rawSettings is! Map) {
      throw const FormatException(
        'Metadatos de respaldo inválidos: settings');
    }
    for (final key in const [
      'gamification', 'hydration', 'recovery', 'habitTasksStore',
    ]) {
      final value = data[key];
      if (value != null && value is! Map) {
        throw FormatException('Datos de respaldo inválidos: $key');
      }
    }
    final settings = rawSettings is Map
        ? Map<String, dynamic>.from(_normalizeMap(rawSettings))
        : <String, dynamic>{};
    settings.remove('db_version');

    // Every list below is restored into a Hive map keyed by the record ID.
    // A backup with repeated IDs would silently overwrite the earlier
    // record, even when the JSON parses successfully. Validate the entire
    // payload before restoreBackup clears any user box. Older schema
    // versions with missing optional lists remain compatible.
    _rejectDuplicateRecordIds(data);

    final exercises = (data['exercises'] as List?)
            ?.map(
              (exercise) => HiveExercise(
                id: exercise['id'],
                name: exercise['name'],
                muscleGroup: exercise['muscleGroup'],
                secondaryMuscles:
                    List<String>.from(exercise['secondaryMuscles'] ?? []),
                equipment: exercise['equipment'] ?? '',
                instructions: exercise['instructions'] ?? '',
                media: exercise['media'] ?? '',
              ),
            )
            .toList() ??
        <HiveExercise>[];

    final routines = (data['routines'] as List?)
            ?.map(
              (routine) => HiveRoutine(
                id: routine['id'],
                name: routine['name'],
                notes: routine['notes'] ?? '',
                scheduledDays:
                    List<int>.from(routine['scheduledDays'] ?? []),
                createdAt: DateTime.parse(routine['createdAt']),
                exercises: (routine['exercises'] as List)
                    .map(
                      (exercise) => HiveRoutineExercise(
                        exerciseId: exercise['exerciseId'],
                        order: exercise['order'],
                        targetSets: exercise['targetSets'],
                        targetRepsMin: exercise['targetRepsMin'],
                        targetRepsMax: exercise['targetRepsMax'],
                        restSeconds: exercise['restSeconds'],
                        warmupSets: exercise['warmupSets'] ?? 0,
                        approachSets: exercise['approachSets'] ?? 0,
                        warmupRestSeconds:
                            exercise['warmupRestSeconds'] as int?,
                        approachRestSeconds:
                            exercise['approachRestSeconds'] as int?,
                        unilateral: exercise['unilateral'] ?? false,
                        unilateralTarget:
                            exercise['unilateralTarget'] ?? 'other',
                        preparationUnilateral:
                            exercise['preparationUnilateral'] as bool? ?? true,
                        unilateralSideRestSeconds:
                            exercise['unilateralSideRestSeconds'] as int?,
                        preferredUnilateralStartSide:
                            exercise['preferredUnilateralStartSide'] as String?,
                        supersetGroupId: exercise['supersetGroupId'] as String?,
                        phase: exercise['phase'] ?? 'main',
                      ),
                    )
                    .toList(),
              ),
            )
            .toList() ??
        <HiveRoutine>[];

    final workouts = (data['workouts'] as List?)
            ?.map(
              (workout) => HiveWorkoutSession(
                id: workout['id'],
                routineId: workout['routineId'],
                startedAt: DateTime.parse(workout['startedAt']),
                finishedAt: DateTime.parse(workout['finishedAt']),
                durationSeconds: workout['durationSeconds'],
                notes: workout['notes'] ?? '',
                routineNameSnapshot: workout['routineNameSnapshot'] ?? '',
                currentRestEndsAt: workout['currentRestEndsAt'] != null
                    ? DateTime.parse(workout['currentRestEndsAt'])
                    : null,
                exercises: (workout['exercises'] as List)
                    .map(
                      (exercise) => HiveWorkoutExercise(
                        exerciseId: exercise['exerciseId'],
                        notes: exercise['notes'] ?? '',
                        exerciseNameSnapshot:
                            exercise['exerciseNameSnapshot'] ?? '',
                        muscleGroupSnapshot:
                            exercise['muscleGroupSnapshot'] ?? '',
                        unilateral: exercise['unilateral'] ?? false,
                        unilateralTarget:
                            exercise['unilateralTarget'] ?? 'other',
                        preparationUnilateral:
                            exercise['preparationUnilateral'] as bool? ?? true,
                        preferredUnilateralStartSide:
                            exercise['preferredUnilateralStartSide'] as String? ??
                                'automatic',
                        supersetGroupId: exercise['supersetGroupId'] as String?,
                        sets: (exercise['sets'] as List)
                            .map(
                              (set) {
                                final legacyWarmup = set['warmup'] ?? false;
                                return HiveWorkoutSet(
                                  weight: (set['weight'] as num).toDouble(),
                                  reps: set['reps'],
                                  completed: set['completed'],
                                  recordedOutcome: set['completed'] == true
                                      ? null : set['recordedOutcome'] as String?,
                                  rir: set['rir'],
                                  warmup: legacyWarmup,
                                  restSeconds: set['restSeconds'] ?? 0,
                                  setType: set['setType'] ??
                                      (legacyWarmup ? 'warmup' : 'working'),
                                  leftCompleted:
                                      set['leftCompleted'] ?? false,
                                  rightCompleted:
                                      set['rightCompleted'] ?? false,
                                  leftWeight:
                                      (set['leftWeight'] as num?)?.toDouble(),
                                  leftReps: set['leftReps'] as int?,
                                  leftRir: set['leftRir'] as int?,
                                  rightWeight:
                                      (set['rightWeight'] as num?)?.toDouble(),
                                  rightReps: set['rightReps'] as int?,
                                  rightRir: set['rightRir'] as int?,
                                  sideRestSeconds:
                                      set['sideRestSeconds'] as int? ?? 60,
                                );
                              },
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList() ??
        <HiveWorkoutSession>[];

    final personalRecords = (data['personalRecords'] as List?)
            ?.map(
              (record) => HivePersonalRecord(
                id: record['id'],
                workoutSessionId: record['workoutSessionId'],
                exerciseId: record['exerciseId'],
                exerciseNameSnapshot: record['exerciseNameSnapshot'] ?? '',
                type: HivePRType.values.firstWhere(
                  (type) => type.name == record['type'],
                  orElse: () => HivePRType.maxWeight,
                ),
                previousValue:
                    (record['previousValue'] as num).toDouble(),
                newValue: (record['newValue'] as num).toDouble(),
                achievedAt: DateTime.parse(record['achievedAt']),
              ),
            )
            .toList() ??
        <HivePersonalRecord>[];

    final bodyMeasurements = (data['bodyMeasurements'] as List?)
            ?.map(
              (measurement) => HiveBodyMeasurement(
                id: measurement['id'],
                date: DateTime.parse(measurement['date']),
                weightKg: measurement['weightKg'] != null
                    ? (measurement['weightKg'] as num).toDouble()
                    : null,
                bodyFatPercentage: measurement['bodyFatPercentage'] != null
                    ? (measurement['bodyFatPercentage'] as num).toDouble()
                    : null,
                shouldersCm: measurement['shouldersCm'] != null
                    ? (measurement['shouldersCm'] as num).toDouble()
                    : null,
                chestCm: measurement['chestCm'] != null
                    ? (measurement['chestCm'] as num).toDouble()
                    : null,
                waistCm: measurement['waistCm'] != null
                    ? (measurement['waistCm'] as num).toDouble()
                    : null,
                hipsCm: measurement['hipsCm'] != null
                    ? (measurement['hipsCm'] as num).toDouble()
                    : null,
                leftArmCm: measurement['leftArmCm'] != null
                    ? (measurement['leftArmCm'] as num).toDouble()
                    : null,
                rightArmCm: measurement['rightArmCm'] != null
                    ? (measurement['rightArmCm'] as num).toDouble()
                    : null,
                leftLegCm: measurement['leftLegCm'] != null
                    ? (measurement['leftLegCm'] as num).toDouble()
                    : null,
                rightLegCm: measurement['rightLegCm'] != null
                    ? (measurement['rightLegCm'] as num).toDouble()
                    : null,
                calvesCm: measurement['calvesCm'] != null
                    ? (measurement['calvesCm'] as num).toDouble()
                    : null,
                heightCm: measurement['heightCm'] != null
                    ? (measurement['heightCm'] as num).toDouble()
                    : null,
                neckCm: measurement['neckCm'] != null
                    ? (measurement['neckCm'] as num).toDouble()
                    : null,
                leftForearmCm: measurement['leftForearmCm'] != null
                    ? (measurement['leftForearmCm'] as num).toDouble()
                    : null,
                rightForearmCm: measurement['rightForearmCm'] != null
                    ? (measurement['rightForearmCm'] as num).toDouble()
                    : null,
                leftCalfCm: measurement['leftCalfCm'] != null
                    ? (measurement['leftCalfCm'] as num).toDouble()
                    : null,
                rightCalfCm: measurement['rightCalfCm'] != null
                    ? (measurement['rightCalfCm'] as num).toDouble()
                    : null,
              ),
            )
            .toList() ??
        <HiveBodyMeasurement>[];

    final favoriteVerses = (data['favoriteVerses'] as List?)
            ?.map(
              (verse) => HiveFavoriteVerse(
                id: verse['id'],
                book: verse['book'],
                chapter: verse['chapter'],
                verse: verse['verse'],
                text: verse['text'],
                savedAt: DateTime.parse(verse['savedAt']),
              ),
            )
            .toList() ??
        <HiveFavoriteVerse>[];

    final gamification = data['gamification'] is Map
        ? _normalizeMap(data['gamification'] as Map)
        : <String, dynamic>{};
    final hydration = data['hydration'] is Map
        ? _normalizeMap(data['hydration'] as Map)
        : <String, dynamic>{};
    final recovery = data['recovery'] is Map
        ? _normalizeMap(data['recovery'] as Map)
        : <String, dynamic>{};
    final habitTasksStore = data['habitTasksStore'] is Map
        ? _normalizeMap(data['habitTasksStore'] as Map)
        : <String, dynamic>{};

    if (schemaVersion < 1 || schemaVersion > currentBackupSchemaVersion) {
      throw StateError('Versión de backup no compatible: $schemaVersion');
    }

    return <String, dynamic>{
      'settings': settings,
      'exercises': exercises,
      'routines': routines,
      'workouts': workouts,
      'personalRecords': personalRecords,
      'bodyMeasurements': bodyMeasurements,
      'favoriteVerses': favoriteVerses,
      'gamification': gamification,
      'hydration': hydration,
      'recovery': recovery,
      'habitTasksStore': habitTasksStore,
    };
  }

  /// Reject destructive ID collisions before touching on-device records.
  /// A missing optional collection is valid for historical backup schemas.
  /// Malformed collection entries are invalid rather than silently skipped.
  void _rejectDuplicateRecordIds(Map<String, dynamic> data) {
    for (final name in const [
      'exercises', 'routines', 'workouts', 'personalRecords',
      'bodyMeasurements', 'favoriteVerses',
    ]) {
      final source = data[name];
      if (source == null) continue;
      if (source is! List) {
        throw FormatException('Colección de respaldo inválida: $name');
      }
      final seen = <String>{};
      for (final record in source) {
        if (record is! Map) {
          throw FormatException('Registro de respaldo inválido: $name');
        }
        final id = record['id'];
        if (id is! String || id.trim().isEmpty) {
          throw FormatException('Identificador de respaldo inválido: $name');
        }
        if (!seen.add(id)) {
          throw FormatException('Identificador duplicado en respaldo: $name');
        }
      }
    }
  }

  Map<String, dynamic> _habitTasksBackupMap(
    Map<dynamic, dynamic> source,
  ) {
    final filtered = <dynamic, dynamic>{};
    for (final entry in source.entries) {
      final key = entry.key.toString();
      if (key.startsWith('runtime::')) continue;
      filtered[entry.key] = entry.value;
    }
    return _normalizeMap(filtered);
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> source) {
    return source.map(
      (key, value) => MapEntry(key.toString(), _normalizeValue(value)),
    );
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is Map) return _normalizeMap(value);
    if (value is Iterable) return value.map(_normalizeValue).toList();
    if (value is DateTime) return value.toIso8601String();
    return value;
  }
}
