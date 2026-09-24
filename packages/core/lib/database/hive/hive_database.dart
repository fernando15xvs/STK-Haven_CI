import 'package:hive_flutter/hive_flutter.dart';
import 'hive_adapters.dart';
import 'hive_boxes.dart';
import '../migrations/database_version.dart';
import '../migrations/migration_runner.dart';
import 'models/hive_routine.dart';
import 'models/hive_workout_session.dart';
import 'models/hive_exercise.dart';
import 'models/hive_personal_record.dart';
import 'models/hive_body_measurement.dart';
import '../../domain/models/hive_favorite_verse.dart';

class HiveDatabase {
  static Future<void> init() async {
    await Hive.initFlutter();
    registerHiveAdapters();

    final metaBox = await Hive.openBox(HiveBoxes.metadata);
    // defaultValue is -1 to distinguish a fresh install from a legacy app.
    final int savedVersion = metaBox.get('db_version', defaultValue: -1);

    if (savedVersion == -1) {
      await metaBox.put('db_version', currentDatabaseVersion);
    } else if (savedVersion < currentDatabaseVersion) {
      await MigrationRunner.runMigrations(savedVersion, currentDatabaseVersion);
      await metaBox.put('db_version', currentDatabaseVersion);
    }

    // These boxes are independent. Opening them concurrently shortens cold-start
    // wall time compared with awaiting each disk read serially.
    await Future.wait<Object?>([
      Hive.openBox<HiveRoutine>(HiveBoxes.routines),
      Hive.openBox<HiveWorkoutSession>(HiveBoxes.history),
      Hive.openBox<HiveExercise>(HiveBoxes.exercises),
      Hive.openBox<HivePersonalRecord>(HiveBoxes.personalRecords),
      Hive.openBox<HiveBodyMeasurement>(HiveBoxes.bodyMeasurements),
      Hive.openBox<HiveFavoriteVerse>(HiveBoxes.favoriteVerses),
      Hive.openBox(HiveBoxes.activeWorkout),
      Hive.openBox(HiveBoxes.gamification),
      Hive.openBox(HiveBoxes.hydration),
      Hive.openBox(HiveBoxes.bible),
      Hive.openBox(HiveBoxes.recovery),
      Hive.openBox(HiveBoxes.habitTasks),
      Hive.openBox(HiveBoxes.trainingPrograms),
      Hive.openBox(HiveBoxes.analyticsCache),
    ]);
  }
}
