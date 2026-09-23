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

class BackupService {
  static const int currentBackupSchemaVersion = 9;

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
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        errorMessage: 'El archivo está corrupto o mal formado: $e',
      );
    }
  }

  Future<void> restoreBackup(
    Map<String, dynamic> data, {
    int schemaVersion = currentBackupSchemaVersion,
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
    } catch (e) {
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

      throw Exception(
        'Fallo al restaurar, se ha revertido a la base de datos original. Error: $e',
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
                'unilateral': exercise.unilateral,
                'unilateralTarget': exercise.unilateralTarget,
                'supersetGroupId': exercise.supersetGroupId,
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
                'supersetGroupId': exercise.supersetGroupId,
                'sets': exercise.sets
                    .map(
                      (set) => {
                        'weight': set.weight,
                        'reps': set.reps,
                        'completed': set.completed,
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
    final settings = rawSettings is Map
        ? Map<String, dynamic>.from(_normalizeMap(rawSettings))
        : <String, dynamic>{};
    settings.remove('db_version');

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
                        unilateral: exercise['unilateral'] ?? false,
                        unilateralTarget:
                            exercise['unilateralTarget'] ?? 'other',
                        supersetGroupId: exercise['supersetGroupId'] as String?,
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
                        supersetGroupId: exercise['supersetGroupId'] as String?,
                        sets: (exercise['sets'] as List)
                            .map(
                              (set) {
                                final legacyWarmup = set['warmup'] ?? false;
                                return HiveWorkoutSet(
                                  weight: (set['weight'] as num).toDouble(),
                                  reps: set['reps'],
                                  completed: set['completed'],
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
    };
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
