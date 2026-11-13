import 'package:core/domain/models/workout_session.dart';

/// A historical session belongs to the local calendar day it finished.
/// Same convention as Inicio's completed-today tile and Progreso.
class WorkoutHistoryDatePolicy {
  const WorkoutHistoryDatePolicy._();

  static DateTime localCompletionTime(WorkoutSession session) =>
      session.finishedAt.toLocal();

  static int latestFirst(WorkoutSession a, WorkoutSession b) =>
      b.finishedAt.compareTo(a.finishedAt);
}
