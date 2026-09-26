import '../../core/config/storage_namespace.dart';

class HiveBoxes {
  static String get routines => StorageNamespace.scope('routinesBox_v2');
  static String get history => StorageNamespace.scope('historyBox_v2');
  static String get exercises => StorageNamespace.scope('exercisesBox_v2');
  static String get metadata => StorageNamespace.scope('metadataBox');
  static String get activeWorkout =>
      StorageNamespace.scope('activeWorkoutBox_v2');
  static String get personalRecords =>
      StorageNamespace.scope('personalRecordsBox_v2');
  static String get bodyMeasurements =>
      StorageNamespace.scope('bodyMeasurementsBox');
  static String get favoriteVerses =>
      StorageNamespace.scope('favoriteVersesBox');
  static String get gamification => StorageNamespace.scope('gamificationBox');
  static String get hydration => StorageNamespace.scope('hydrationBox');
  static String get bible => StorageNamespace.scope('bibleBox');
  static String get recovery => StorageNamespace.scope('recoveryBox');
  static String get habitTasks => StorageNamespace.scope('habitTasksBox_v1');

  /// Roadmap 2.0 user-owned A/B/C programs. Stored as JSON-compatible maps so
  /// program schema can evolve without consuming/changing Hive TypeAdapter IDs.
  static String get trainingPrograms =>
      StorageNamespace.scope('trainingProgramsBox_v2');

  /// Incremental progress/analytics cache. Derived data only; it may be safely
  /// rebuilt from workout history if invalidated or missing.
  static String get analyticsCache =>
      StorageNamespace.scope('analyticsCacheBox_v2');
}
