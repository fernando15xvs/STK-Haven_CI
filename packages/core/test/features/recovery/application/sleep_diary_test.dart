import 'package:core/features/recovery/application/sleep_diary.dart';
import 'package:test/test.dart';
void main(){
  test('manual nights distinguish missing and zero, replace by wake date and preserve history',(){
    final today=DateTime(2026,11,25);
    final yesterday=DateTime(2026,11,24);
    final empty=SleepDiary.empty();
    expect(empty.minutesFor(today),isNull);
    expect(empty.goalMinutes,isNull);
    final saved=empty.withEntry(today,0).withEntry(yesterday,420).withGoal(480);
    expect(saved.minutesFor(today),0);
    final edited=saved.withEntry(today,450);
    expect(edited.entries.length,2);
    expect(edited.recent().first.value,450);
    expect(SleepDiary.fromJson(edited.toJson()).toJson(),edited.toJson());
    expect(edited.withoutEntry(today).minutesFor(yesterday),420);
    expect(edited.withGoal(null).goalMinutes,isNull);
    expect(()=>edited.withEntry(today,1441),throwsArgumentError);
    expect(()=>edited.withGoal(0),throwsArgumentError);
  });
  test('malformed legacy data is ignored without inventing sleep',(){
    final restored=SleepDiary.fromJson({'entries':{'2026-11-25':450,'bad':500,'2026-11-24':-1},'goalMinutes':-1});
    expect(restored.entries,{'2026-11-25':450});
    expect(restored.goalMinutes,isNull);
  });
}
