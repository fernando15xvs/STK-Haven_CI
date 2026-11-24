import 'package:core/domain/models/daily_steps_state.dart';
import 'package:core/features/home/application/steps_reading_freshness.dart';
import 'package:test/test.dart';

void main(){
  final now=DateTime(2026,11,15,18);
  const date='2026-11-15';

  test('a manual count is never described as a live device reading',(){
    expect(StepsReadingFreshnessPolicy.resolve(
      DailyStepsState(dateString:date,steps:3600,deviceSynced:false,
        lastSyncedAt:now),now:now),StepsReadingFreshness.manual);
  });

  test('missing device timestamp cannot be presented as fresh',(){
    expect(StepsReadingFreshnessPolicy.resolve(
      const DailyStepsState(dateString:date,deviceSynced:true),
      now:now),StepsReadingFreshness.unknownTime);
  });

  test('same-day recent device data stays recent',(){
    expect(StepsReadingFreshnessPolicy.resolve(
      DailyStepsState(dateString:date,steps:6700,deviceSynced:true,
        lastSyncedAt:now.subtract(const Duration(hours:2))),
      now:now),StepsReadingFreshness.recent);
  });

  test('old, future and previous-day samples are marked stale without erasing steps',(){
    final stale=DailyStepsState(dateString:date,steps:5700,
      deviceSynced:true,lastSyncedAt:now.subtract(const Duration(hours:7)));
    expect(StepsReadingFreshnessPolicy.resolve(stale,now:now),
      StepsReadingFreshness.stale);
    expect(stale.steps,5700);
    final future=stale.copyWith(lastSyncedAt:now.add(const Duration(minutes:10)));
    expect(StepsReadingFreshnessPolicy.resolve(future,now:now),
      StepsReadingFreshness.stale);
    final yesterday=stale.copyWith(dateString:'2026-11-14',
      lastSyncedAt:now.subtract(const Duration(minutes:1)));
    expect(StepsReadingFreshnessPolicy.resolve(yesterday,now:now),
      StepsReadingFreshness.stale);
  });
}
