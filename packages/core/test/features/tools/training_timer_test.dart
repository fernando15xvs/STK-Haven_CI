import 'package:core/features/tools/application/training_timer.dart';
import 'package:test/test.dart';
void main(){
  test('countdown survives delayed ticks and pauses without losing elapsed time',(){
    final start=DateTime(2026,11,27,12);
    final timer=TrainingTimerState(duration:90,startedAt:start);
    expect(timer.displayAt(start.add(const Duration(seconds:37))),53);
    expect(timer.deadline,start.add(const Duration(seconds:90)));
    final paused=timer.pause(start.add(const Duration(seconds:37)));
    expect(paused.displayAt(start.add(const Duration(minutes:4))),53);
    expect(timer.completeAt(start.add(const Duration(minutes:4))),isTrue);
    expect(timer.displayAt(start.add(const Duration(minutes:4))),0);
  });
  test('stopwatch never schedules a deadline',(){
    final start=DateTime(2026,11,27);
    final timer=TrainingTimerState(stopwatch:true,startedAt:start,elapsed:10);
    expect(timer.deadline,isNull);
    expect(timer.displayAt(start.add(const Duration(seconds:15))),25);
    expect(timer.completeAt(start.add(const Duration(hours:1))),isFalse);
  });
}
