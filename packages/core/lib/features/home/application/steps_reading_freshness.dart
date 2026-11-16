import 'package:core/domain/models/daily_steps_state.dart';

/// Presentation-only freshness signal. A stored step count is never deleted,
/// recomputed, or treated as a calorie estimate because a reading is old.
enum StepsReadingFreshness { manual, unknownTime, recent, stale }

class StepsReadingFreshnessPolicy {
  const StepsReadingFreshnessPolicy._();

  static StepsReadingFreshness resolve(
    DailyStepsState reading, {
    required DateTime now,
  }) {
    if(!reading.deviceSynced)return StepsReadingFreshness.manual;
    final last=reading.lastSyncedAt;
    if(last==null)return StepsReadingFreshness.unknownTime;
    final elapsed=now.toUtc().difference(last.toUtc());
    final today='${now.year}-'
      '${now.month.toString().padLeft(2,'0')}-'
      '${now.day.toString().padLeft(2,'0')}';
    if(elapsed.isNegative ||
       elapsed>const Duration(hours:6) ||
       reading.dateString!=today){
      return StepsReadingFreshness.stale;
    }
    return StepsReadingFreshness.recent;
  }
}
