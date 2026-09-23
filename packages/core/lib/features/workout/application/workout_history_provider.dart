import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/database/hive/models/hive_workout_session.dart';
import 'package:core/features/workout/data/workout_repository.dart';
import 'package:core/domain/models/workout_session.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final box = Hive.box<HiveWorkoutSession>(HiveBoxes.history);
  return WorkoutRepository(box);
});

final workoutHistoryProvider = NotifierProvider<WorkoutHistoryNotifier, List<WorkoutSession>>(
  WorkoutHistoryNotifier.new,
);

class WorkoutHistoryNotifier extends Notifier<List<WorkoutSession>> {
  @override
  List<WorkoutSession> build() {
    final sub = Hive.box<HiveWorkoutSession>(HiveBoxes.history).watch().listen((_) {
      state = _fetch();
    });
    ref.onDispose(sub.cancel);
    return _fetch();
  }

  void refresh() => state = _fetch();

  List<WorkoutSession> _fetch() {
    final sessions = ref.read(workoutRepositoryProvider).getAllSessions();
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }
}
