import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';

class ProgramMuscleFrequency {
  final String muscleGroup;

  /// Sessions in which this muscle participates, either as primary or
  /// secondary. Multiple exercises in the same session count only once.
  final int totalSessions;

  /// Sessions in which this muscle is the primary group of at least one
  /// exercise.
  final int directSessions;

  const ProgramMuscleFrequency({
    required this.muscleGroup,
    required this.totalSessions,
    required this.directSessions,
  });

  int get secondaryOnlySessions =>
      (totalSessions - directSessions).clamp(0, totalSessions).toInt();
}

class ProgramMuscleFrequencyPlanner {
  const ProgramMuscleFrequencyPlanner._();

  static List<ProgramMuscleFrequency> calculateWeek({
    required TrainingProgram program,
    required Iterable<Routine> routines,
    required Iterable<Exercise> exercises,
    required DateTime weekStart,
  }) {
    final routineById = <String, Routine>{
      for (final routine in routines) routine.id: routine,
    };
    final exerciseById = <String, Exercise>{
      for (final exercise in exercises) exercise.id: exercise,
    };

    final sessions = ProgramScheduleProjector.projectWeek(
      program: program,
      routines: routines,
      weekStart: weekStart,
    );

    final displayNameByKey = <String, String>{};
    final totalByKey = <String, int>{};
    final directByKey = <String, int>{};

    for (final session in sessions) {
      final routine = routineById[session.routineId];
      if (routine == null) continue;

      final sessionTotal = <String>{};
      final sessionDirect = <String>{};

      for (final target in routine.exercises) {
        final exercise = exerciseById[target.exerciseId];
        if (exercise == null) continue;

        final primary = exercise.muscleGroup.trim();
        if (primary.isNotEmpty) {
          final key = _key(primary);
          displayNameByKey.putIfAbsent(key, () => primary);
          sessionDirect.add(key);
          sessionTotal.add(key);
        }

        for (final secondaryRaw in exercise.secondaryMuscles) {
          final secondary = secondaryRaw.trim();
          if (secondary.isEmpty) continue;
          final key = _key(secondary);
          displayNameByKey.putIfAbsent(key, () => secondary);
          sessionTotal.add(key);
        }
      }

      for (final key in sessionTotal) {
        totalByKey[key] = (totalByKey[key] ?? 0) + 1;
      }
      for (final key in sessionDirect) {
        directByKey[key] = (directByKey[key] ?? 0) + 1;
      }
    }

    final result = totalByKey.entries
        .map(
          (entry) => ProgramMuscleFrequency(
            muscleGroup: displayNameByKey[entry.key] ?? entry.key,
            totalSessions: entry.value,
            directSessions: directByKey[entry.key] ?? 0,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) {
        final frequency = b.totalSessions.compareTo(a.totalSessions);
        if (frequency != 0) return frequency;
        return a.muscleGroup.compareTo(b.muscleGroup);
      });

    return result;
  }

  static String _key(String value) => value.trim().toLowerCase();
}
