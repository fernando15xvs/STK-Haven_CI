class HiveBoxes {
  static const String routines = 'routinesBox_v2';
  static const String history = 'historyBox_v2';
  static const String exercises = 'exercisesBox_v2';
  static const String metadata = 'metadataBox';
  static const String activeWorkout = 'activeWorkoutBox_v2';
  static const String personalRecords = 'personalRecordsBox_v2';
  static const String bodyMeasurements = 'bodyMeasurementsBox';
  static const String favoriteVerses = 'favoriteVersesBox';
  static const String gamification = 'gamificationBox';
  static const String hydration = 'hydrationBox';
  static const String bible = 'bibleBox';
  static const String recovery = 'recoveryBox';
  static const String habitTasks = 'habitTasksBox_v1';

  /// Roadmap 2.0 user-owned A/B/C programs. Stored as JSON-compatible maps so
  /// program schema can evolve without consuming/changing Hive TypeAdapter IDs.
  static const String trainingPrograms = 'trainingProgramsBox_v2';

  /// Incremental progress/analytics cache. Derived data only; it may be safely
  /// rebuilt from workout history if invalidated or missing.
  static const String analyticsCache = 'analyticsCacheBox_v2';
}
