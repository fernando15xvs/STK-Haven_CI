import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_integrity_policy.dart';
import 'package:test/test.dart';

void main(){
  final monday=DateTime(2026,11,23,9);
  final task=HabitTask(id:'reading',title:'Lectura',createdAt:monday,updatedAt:monday,
    recurrence:HabitRecurrenceType.weekly,weeklyGoal:2);
  test('weekly goal counts distinct days, resets on Monday and persists',(){
    final rows=[for(final (i,d) in [0,0,1].indexed)
      HabitTaskCompletion(id:'$i',taskId:task.id,completedAt:DateTime(2026,11,23+d,10))];
    final friday=DateTime(2026,11,27);
    expect(HabitIntegrityPolicy.completedDays(task,rows,friday),2);
    expect(HabitIntegrityPolicy.pending(task,rows,friday),isFalse);
    expect(HabitIntegrityPolicy.pending(task,rows,DateTime(2026,11,30)),isTrue);
    expect(HabitTask.fromJson(task.toJson()).weeklyGoal,2);
  });
  test('temporary pause leaves completion history intact',(){
    final paused=task.copyWith(pausedUntil:DateTime(2026,11,28));
    expect(HabitIntegrityPolicy.pending(paused,[],DateTime(2026,11,27)),isFalse);
    expect(HabitIntegrityPolicy.pending(paused,[],DateTime(2026,11,28)),isTrue);
  });
  test('quantity stays pending until the actual target is reached',(){
    final q=task.copyWith(type:HabitTaskType.custom,targetQuantity:10,quantityUnit:'páginas');
    final rows=[HabitTaskCompletion(id:'q1',taskId:q.id,completedAt:monday,quantity:4)];
    expect(HabitIntegrityPolicy.pending(q,rows,monday),isTrue);
    rows.add(HabitTaskCompletion(id:'q2',taskId:q.id,completedAt:monday,quantity:6));
    expect(HabitIntegrityPolicy.pending(q,rows,monday),isFalse);
    expect(HabitIntegrityPolicy.completedToday([q],rows,monday),1);
    expect(HabitTask.fromJson(q.toJson()).targetQuantity,10);
  });
  test('multiple pauses preserve prior rest days after resuming',(){
    var p=HabitIntegrityPolicy.pause(task,monday,DateTime(2026,11,25));
    p=HabitIntegrityPolicy.resume(p,DateTime(2026,11,24));
    p=HabitIntegrityPolicy.pause(p,DateTime(2026,11,27),DateTime(2026,11,29));
    p=HabitTask.fromJson(p.toJson());
    expect(HabitIntegrityPolicy.pending(p,[],monday),isFalse);
    expect(HabitIntegrityPolicy.pending(p,[],DateTime(2026,11,24)),isTrue);
    expect(HabitIntegrityPolicy.pending(p,[],DateTime(2026,11,28)),isFalse);
  });
  test('backup strips private and orphan notes without altering local data',(){
    final local={'task::reading':task.toJson(),'completion::a':{'taskId':'reading','note':'private'},
      'completion::b':{'taskId':'unknown','note':'secret'},'runtime::timer':{}};
    final result=HabitIntegrityPolicy.backupWithoutPrivateNotes(local);
    expect((result['completion::a'] as Map)['note'],'');
    expect((result['completion::b'] as Map)['note'],'');
    expect((local['completion::a'] as Map)['note'],'private');
    expect(result.containsKey('runtime::timer'),isFalse);
  });
}
