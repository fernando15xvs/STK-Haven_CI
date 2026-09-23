import 'package:hive/hive.dart';
import 'models/hive_routine.dart';
import 'models/hive_workout_session.dart';
import 'models/hive_exercise.dart';
import 'models/hive_personal_record.dart';
import 'models/hive_body_measurement.dart';
import '../../domain/models/hive_favorite_verse.dart';

void registerHiveAdapters() {
  Hive.registerAdapter(HiveRoutineAdapter());
  Hive.registerAdapter(HiveRoutineExerciseAdapter());
  Hive.registerAdapter(HiveWorkoutSessionAdapter());
  Hive.registerAdapter(HiveWorkoutExerciseAdapter());
  Hive.registerAdapter(HiveWorkoutSetAdapter());
  Hive.registerAdapter(HiveExerciseAdapter());
  Hive.registerAdapter(HivePersonalRecordAdapter());
  Hive.registerAdapter(HivePRTypeAdapter());
  Hive.registerAdapter(HiveBodyMeasurementAdapter());
  Hive.registerAdapter(HiveFavoriteVerseAdapter());
}
