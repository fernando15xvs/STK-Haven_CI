import 'package:core/domain/models/personal_reading_document.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/domain/models/habit_study_timer.dart';
import 'package:core/features/habits/application/guided_habit_plan.dart';
import 'package:test/test.dart';

void main(){
  final now=DateTime(2026,11,27,9);
  final doc=PersonalReadingDocument(id:'book',title:'Libro',originalFileName:'book.pdf',localPath:'/old/book.pdf',importedAt:now,
    currentPage:84,totalPages:320,goalDays:30,goalStartedAt:now,bookmarks:{84},pageNotes:{84:'Nota'},highlights:{84:['texto']});
  test('legacy document JSON remains readable and new annotations survive roundtrip',(){
    final old=PersonalReadingDocument.fromJson({'id':'old','title':'Libro antiguo','originalFileName':'a.pdf','localPath':'/a.pdf',
      'importedAt':now.toIso8601String(),'currentPage':9,'totalPages':100});
    expect(old.currentPage,9);
    expect(old.sessions,isEmpty);
    final restored=PersonalReadingDocument.fromJson(doc.toJson());
    expect(restored.bookmarks,{84});
    expect(restored.highlights[84],['texto']);
    expect(restored.pageNotes[84],'Nota');
    expect(restored.pagesPerDayAt(now),8);
  });
  test('linked reading session is not counted twice',(){
    final session=ReadingSession(id:'s',startedAt:now,seconds:600,pagesAdvanced:5);
    final task=HabitTask(id:'read',title:'Leer',type:HabitTaskType.readingTimer,createdAt:now,updatedAt:now);
    final linked=HabitTaskCompletion(id:'reading:s',taskId:task.id,completedAt:now,minutesSpent:10);
    final manual=HabitTaskCompletion(id:'manual',taskId:task.id,completedAt:now,minutesSpent:20);
    expect(ReadingStatistics.secondsLastSevenDays([doc.copyWith(sessions:[session])],now,tasks:[task],completions:[linked,manual]),1800);
  });
  test('guided stages cover all configured durations',(){
    for(final m in [5,10,15]){
      final steps=GuidedHabitPlan.steps(GuidedHabitKind.night,m*60);
      expect(steps.fold<int>(0,(sum,s)=>sum+s.seconds),m*60);
      expect(GuidedHabitPlan.stageAt(GuidedHabitKind.night,0,m*60),GuidedHabitStage.prepare);
      expect(GuidedHabitPlan.stageAt(GuidedHabitKind.night,m*60,m*60),GuidedHabitStage.close);
    }
  });
  test('persistent timer keeps identity and mode through pause/resume',(){
    final timer=HabitStudyTimerState(taskId:'task',sessionId:'stable',focusMode:true,targetSeconds:1500,runningSince:now,updatedAt:now);
    final paused=timer.pause(now.add(const Duration(minutes:3)));
    final restored=HabitStudyTimerState.fromJson(paused.toJson()).resume(now.add(const Duration(minutes:4)));
    expect(restored.sessionId,'stable');
    expect(restored.focusMode,isTrue);
    expect(restored.elapsedSecondsAt(now.add(const Duration(minutes:5))),240);
  });
}
