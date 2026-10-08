/// Wire values are an allowlist shared with stk_list_coach_pro_clients.
enum CoachProClientStatusFilter { all, active, paused }

enum CoachProClientSort {
  review('review'),
  name('name'),
  recentWorkout('recent_workout'),
  adherence('adherence');

  final String wireValue;
  const CoachProClientSort(this.wireValue);
}
