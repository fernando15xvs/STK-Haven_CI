import 'package:core/domain/models/habit_task.dart';
import 'habit_schedule_service.dart';

abstract final class HabitIntegrityPolicy {
  static DateTime day(DateTime value) {
    final local=value.toLocal();
    return DateTime(local.year,local.month,local.day);
  }
  static DateTime week(DateTime value) {
    final d=day(value);
    return DateTime(d.year,d.month,d.day-d.weekday+1);
  }
  static int completedDays(HabitTask task, Iterable<HabitTaskCompletion> rows, DateTime now) {
    final start=week(now);
    final actual=rows.where((c)=>!c.completedAt.isAfter(now)).toList();
    return actual.where((c)=>c.taskId==task.id && c.status==HabitTaskCompletionStatus.completed &&
      !c.completedAt.isAfter(now) && !day(c.completedAt).isBefore(start))
      .map((c)=>day(c.completedAt)).toSet().where((date)=>HabitScheduleService.isCompletedOn(task,actual,date)).length;
  }
  static HabitTask pause(HabitTask task,DateTime now,DateTime until){
    final start=day(now),end=day(until);
    if(!end.isAfter(start))throw ArgumentError('Fecha de reanudación inválida');
    final from=task.pausedFrom,oldEnd=task.pausedUntil;
    final prior=[...task.pauseHistory];
    if(from!=null&&oldEnd!=null&&oldEnd.isAfter(from)){
      if(!oldEnd.isAfter(start)){prior.add(HabitPauseInterval(from,oldEnd));}
      else{return task.copyWith(pausedFrom:from,pausedUntil:end);}
    }
    return task.copyWith(pausedFrom:start,pausedUntil:end,pauseHistory:prior);
  }
  static HabitTask resume(HabitTask task,DateTime now)=>task.copyWith(pausedUntil:day(now));

  static bool isPersonalDashboardTask(HabitTask t)=>t.source==HabitTaskSource.coach||
    (!t.sourceReference.startsWith('template:focus:')&&t.sourceReference!='template:breathing'&&t.sourceReference!='template:personal_pause'&&
      !(t.title=='Pausa de recuperación'&&t.category=='Recuperación'));

  static bool pending(HabitTask task, Iterable<HabitTaskCompletion> rows, DateTime now) =>
    HabitScheduleService.isDueOn(task,now) &&
    !HabitScheduleService.isResolvedOn(task,rows,now) &&
    (task.weeklyGoal==null || completedDays(task,rows,now)<task.weeklyGoal!);

  static int completedToday(Iterable<HabitTask> tasks, Iterable<HabitTaskCompletion> rows,DateTime now) {
    final actual=rows.where((c)=>!c.completedAt.isAfter(now)).toList();
    return tasks.where((t)=>HabitScheduleService.isCompletedOn(t,actual,now)).map((t)=>t.id).toSet().length;
  }

  /// Never export private free text through the general backup. Legacy notes
  /// remain in the local source; previously exported copies are not rewritten.
  static Map<dynamic,dynamic> backupWithoutPrivateNotes(Map<dynamic,dynamic> source) {
    final shareable=<String>{};
    for(final entry in source.entries) {
      final value=entry.value;
      if(entry.key.toString().startsWith('task::')&&value is Map&&
        value['visibility']=='shareable'&&value['source']=='coach') {
        shareable.add('${value['id']}');
      }
    }
    final out=<dynamic,dynamic>{};
    for(final entry in source.entries) {
      final key=entry.key.toString();
      if(key.startsWith('runtime::'))continue;
      final value=entry.value;
      if(value is Map && key.startsWith('completion::')&&!shareable.contains('${value['taskId']}')) {
        out[entry.key]=Map<dynamic,dynamic>.from(value)..['note']='';
      }else if(value is Map&&key.startsWith('task::')&&!shareable.contains('${value['id']}')) {
        out[entry.key]=Map<dynamic,dynamic>.from(value)..['notes']='';
      }else{
        out[entry.key]=value;
      }
    }
    return out;
  }
}
