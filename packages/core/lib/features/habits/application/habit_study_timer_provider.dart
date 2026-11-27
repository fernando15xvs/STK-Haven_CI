import 'package:core/domain/models/habit_study_timer.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:core/features/habits/application/focus_timer_notification_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

final habitStudyTimerProvider = NotifierProvider<HabitStudyTimerNotifier, HabitStudyTimerState?>(HabitStudyTimerNotifier.new);

class HabitStudyTimerNotifier extends Notifier<HabitStudyTimerState?> {
  Future<void> _tail=Future.value();
  Future<void> _enqueue(Future<void> Function() action){
    final next=_tail.then((_)=>action());
    _tail=next.then<void>((_) {},onError:(Object _,StackTrace __){});
    return next;
  }
  @override
  HabitStudyTimerState? build()=>ref.watch(habitTaskRepositoryProvider).getActiveStudyTimer();

  Future<void> _notify(HabitStudyTimerState timer)async{
    await FocusTimerNotificationService.cancel();
    final now=DateTime.now();
    final remaining=timer.remainingSecondsAt(now);
    if(timer.notifyOnEnd&&timer.isRunning&&remaining>0){
      await FocusTimerNotificationService.schedule(now.add(Duration(seconds:remaining)));
    }
  }
  Future<void> start({required String taskId,required int targetMinutes,bool focusMode=false,bool notifyOnEnd=false})=>_enqueue(()async{
    if(state!=null){if(state!.taskId==taskId)return;throw StateError('Ya hay una sesión activa');}
    final now=DateTime.now();
    final next=HabitStudyTimerState(taskId:taskId,sessionId:const Uuid().v4(),focusMode:focusMode,
      notifyOnEnd:notifyOnEnd,targetSeconds:targetMinutes.clamp(0,1440).toInt()*60,runningSince:now,updatedAt:now);
    await ref.read(habitTaskRepositoryProvider).saveActiveStudyTimer(next);
    state=next;await _notify(next);
  });
  Future<void> pause()=>_enqueue(()async{
    final current=state;if(current==null||!current.isRunning)return;
    final next=current.pause(DateTime.now());
    await ref.read(habitTaskRepositoryProvider).saveActiveStudyTimer(next);
    state=next;await FocusTimerNotificationService.cancel();
  });
  Future<void> resume()=>_enqueue(()async{
    final current=state;if(current==null||current.isRunning)return;
    if(current.focusMode&&current.isCompleteAt(DateTime.now()))return;
    final next=current.resume(DateTime.now());
    await ref.read(habitTaskRepositoryProvider).saveActiveStudyTimer(next);
    state=next;await _notify(next);
  });
  Future<void> clear()=>_enqueue(()async{
    await ref.read(habitTaskRepositoryProvider).clearActiveStudyTimer();
    state=null;await FocusTimerNotificationService.cancel();
  });
}
