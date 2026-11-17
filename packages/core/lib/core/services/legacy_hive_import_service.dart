import 'package:core/core/config/storage_namespace.dart';
import 'package:core/core/services/backup_service.dart';
import 'package:core/database/hive/models/hive_exercise.dart';
import 'package:core/database/hive/models/hive_routine.dart';
import 'package:core/database/hive/models/hive_workout_session.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Only type-adapter-compatible archived records are eligible. Unknown older
/// formats remain untouched in their original boxes for manual recovery.
class LegacyHiveScan {
  final List<HiveExercise> exercises;
  final List<HiveRoutine> routines;
  final List<HiveWorkoutSession> workouts;
  final int archivesFound;
  final int unreadableArchives;
  final int unsupportedRecords;

  const LegacyHiveScan({
    required this.exercises,
    required this.routines,
    required this.workouts,
    required this.archivesFound,
    required this.unreadableArchives,
    required this.unsupportedRecords,
  });

  int get recognized => exercises.length + routines.length + workouts.length;
  bool get safeToImport => unreadableArchives == 0 && unsupportedRecords == 0;
}

/// Explicitly invoked from Data & Sync, never automatically at app startup.
/// It cannot grant cloud permissions or delete/rename archived records.
class LegacyHiveImportService {
  const LegacyHiveImportService();

  // Newer v1 first, then older unversioned boxes. The modern v2 record wins
  // over either if IDs collide, preserving references in existing PR history.
  static const _routineSources = ['routinesBox_v1', 'routinesBox'];
  static const _workoutSources = ['historyBox_v1', 'historyBox'];
  static const _exerciseSources = ['exercisesBox_v1'];

  Future<LegacyHiveScan> inspect() async {
    final exercises = <String, HiveExercise>{};
    final routines = <String, HiveRoutine>{};
    final workouts = <String, HiveWorkoutSession>{};
    var found = 0;
    var unreadable = 0;
    var unsupported = 0;

    Future<void> scan<T>(
      List<String> sources,
      Map<String, T> recognized,
      String Function(T) recordId,
    ) async {
      for (final baseName in sources) {
        // A namespaced preview must never inspect production users' boxes.
        final name = StorageNamespace.scope(baseName);
        if (!await Hive.boxExists(name)) continue;
        found++;
        final wasOpen = Hive.isBoxOpen(name);
        Box<dynamic>? box;
        try {
          box = wasOpen
              ? Hive.box<dynamic>(name)
              : await Hive.openBox<dynamic>(name);
          for (final item in box.values) {
            if (item is! T) {
              unsupported++;
              continue;
            }
            final id = recordId(item).trim();
            if (id.isEmpty) {
              unsupported++;
              continue;
            }
            recognized.putIfAbsent(id, () => item);
          }
        } catch (_) {
          // Unreadable/mismatched TypeAdapters cannot be guessed safely:
          // block the import, preserve original files for inspection.
          unreadable++;
        } finally {
          if (!wasOpen && box != null && box.isOpen) {
            await box.close();
          }
        }
      }
    }

    await scan<HiveRoutine>(
      _routineSources, routines, (item) => item.id);
    await scan<HiveWorkoutSession>(
      _workoutSources, workouts, (item) => item.id);
    await scan<HiveExercise>(
      _exerciseSources, exercises, (item) => item.id);

    return LegacyHiveScan(
      exercises: List.unmodifiable(exercises.values),
      routines: List.unmodifiable(routines.values),
      workouts: List.unmodifiable(workouts.values),
      archivesFound: found,
      unreadableArchives: unreadable,
      unsupportedRecords: unsupported,
    );
  }

  /// Must be called ONLY after the user confirms importing the local archives
  /// into the currently selected device profile; never merge silently.
  Future<BackupLegacyMergeResult> importRecognized() async {
    final scan = await inspect();
    if (!scan.safeToImport) {
      throw StateError(
        'Hay archivos antiguos que no pueden leerse de forma segura. '
        'Se conservaron sin modificaciones.',
      );
    }
    return BackupService().mergeLegacyRecords(
      exercises: scan.exercises,
      routines: scan.routines,
      workouts: scan.workouts,
    );
  }
}
