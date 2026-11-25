import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/todays_workout_status.dart';

enum TrainingDayKind { ready, active, completed, rest, none }

/// Daily presentation is independent of the persisted rotation pointer.
/// Completion advances rotation normally, but today's hero stays completed.
class TrainingDayDecision {
  const TrainingDayDecision(this.kind, {this.routine, this.session, this.date});
  final TrainingDayKind kind;
  final Routine? routine;
  final WorkoutSession? session;
  final DateTime? date;

  String? get featuredRoutineId => session?.routineId ?? routine?.id;

  bool get allowsSuggestedStart => kind == TrainingDayKind.ready;

  static DateTime localDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static TrainingDayDecision resolve({
    required DateTime now,
    required WorkoutSession? active,
    required Iterable<WorkoutSession> history,
    required Routine? next,
    required ProgramScheduleMode? mode,
    required DateTime? scheduledDate,
    required bool isTrainingDay,
    Routine? legacyToday,
  }) {
    if (active != null) {
      return TrainingDayDecision(TrainingDayKind.active, session: active);
    }
    final completed = TodaysWorkoutStatus.latestCompletedToday(history, now);
    if (completed != null) {
      return TrainingDayDecision(TrainingDayKind.completed, session: completed);
    }
    if (next == null) {
      return legacyToday == null
          ? const TrainingDayDecision(TrainingDayKind.none)
          : TrainingDayDecision(TrainingDayKind.ready, routine: legacyToday);
    }
    final date = scheduledDate == null ? null : localDay(scheduledDate);
    final today = localDay(now);
    if (date != null && date.isAfter(today)) {
      return TrainingDayDecision(TrainingDayKind.rest, routine: next, date: date);
    }
    if (mode == ProgramScheduleMode.flexible) {
      return TrainingDayDecision(TrainingDayKind.ready, routine: next);
    }
    if (date == today || (date == null && isTrainingDay &&
        mode != ProgramScheduleMode.fixed)) {
      return TrainingDayDecision(TrainingDayKind.ready, routine: next);
    }
    return const TrainingDayDecision(TrainingDayKind.none);
  }

  /// One cycle, in the saved order starting at the reconciled next slot.
  /// No synthetic calendar dates or rest days are assigned in flexible mode.
  static List<String> rotationOrder(TrainingProgram program, {DateTime? now}) {
    if (program.repeatsWeekly) {
      final sequence = program.weeklySequence;
      final start = program.weeklySlotIndexAt(now ?? DateTime.now());
      return List<String>.unmodifiable(sequence.skip(start));
    }
    final ids = program.routineIds;
    if (ids.isEmpty) return const [];
    final start = program.normalizedNextRotationIndex;
    return List<String>.unmodifiable([
      for (var i = 0; i < ids.length; i++) ids[(start + i) % ids.length],
    ]);
  }
}
