import 'dart:async';
import 'package:riverpod/riverpod.dart';
import 'training_tool_preferences.dart';

abstract interface class TrainingTimerNative {
  Future<void> schedule(DateTime deadline);
  Future<void> cancel();
}
class NoTrainingTimerNative implements TrainingTimerNative {
  const NoTrainingTimerNative();
  @override Future<void> schedule(DateTime deadline) async {}
  @override Future<void> cancel() async {}
}
final trainingTimerNativeProvider = Provider<TrainingTimerNative>((ref)=>const NoTrainingTimerNative());

class TrainingTimerState {
  final int duration;
  final int elapsed;
  final DateTime? startedAt;
  final bool stopwatch;
  const TrainingTimerState({this.duration=90,this.elapsed=0,this.startedAt,this.stopwatch=false});
  Map<String,dynamic> toJson()=>{'duration':duration,'elapsed':elapsed,
    'startedAt':startedAt?.toUtc().toIso8601String(),'stopwatch':stopwatch};
  static TrainingTimerState restore(Map<String,dynamic>? json,DateTime now){
    if(json==null)return const TrainingTimerState();
    final duration=json['duration'], elapsed=json['elapsed'], stopwatch=json['stopwatch'];
    final rawStart=json['startedAt'];
    final start=rawStart is String?DateTime.tryParse(rawStart):null;
    if(duration is! int || duration<1 || duration>86400 ||
       elapsed is! int || elapsed<0 || stopwatch is! bool ||
       (!stopwatch && elapsed>duration) ||
       (rawStart!=null && start==null))return const TrainingTimerState();
    // A wall clock moved backwards cannot create negative elapsed time.
    final restored=TrainingTimerState(duration:duration,elapsed:elapsed,stopwatch:stopwatch,
      startedAt:start!=null&&start.isAfter(now)?now:start);
    return restored.completeAt(now)?restored.pause(now):restored;
  }
  int elapsedAt(DateTime now) {
    final delta=startedAt==null?0:now.difference(startedAt!).inSeconds;
    final value=elapsed+(delta<0?0:delta);
    return stopwatch?value:value.clamp(0,duration).toInt();
  }
  int displayAt(DateTime now)=>stopwatch?elapsedAt(now):duration-elapsedAt(now);
  DateTime? get deadline => stopwatch||startedAt==null?null:
    startedAt!.add(Duration(seconds:duration-elapsed));
  bool get running=>startedAt!=null;
  bool completeAt(DateTime now)=>!stopwatch && displayAt(now)==0;
  TrainingTimerState pause(DateTime now)=>TrainingTimerState(duration:duration,
    elapsed:elapsedAt(now),stopwatch:stopwatch);
}

final trainingTimerProvider=NotifierProvider<TrainingTimerNotifier,TrainingTimerState>(TrainingTimerNotifier.new);
class TrainingTimerNotifier extends Notifier<TrainingTimerState> {
  Timer? _ticker;
  Future<void> _queue=Future.value();
  Future<void> _saveQueue=Future.value();
  late TrainingToolPreferences _preferences;
  int _revision=0;
  late TrainingTimerNative _native;
  @override TrainingTimerState build(){
    _native=ref.read(trainingTimerNativeProvider);
    _preferences=ref.read(trainingToolPreferencesProvider);
    ref.onDispose((){
      _ticker?.cancel();
      _revision++;
    });
    final restored=TrainingTimerState.restore(
      _preferences.read(TrainingToolPreferences.timerKey),DateTime.now());
    if(restored.running){
      _ticker=Timer.periodic(const Duration(milliseconds:250),(_)=>refresh());
    }
    // The OS owns the original one-shot alarm: do not replay it on restore.
    return restored;
  }
  void _persist(){
    final snapshot=state.toJson();
    final preferences=_preferences;
    _saveQueue=_saveQueue.then((_)async{
      await preferences.write(TrainingToolPreferences.timerKey,snapshot);
    });
  }
  void _notify(DateTime? deadline){
    final revision=++_revision;
    final backend=_native;
    _queue=_queue.then((_)async{
      if(revision!=_revision)return;
      await backend.cancel();
      if(revision==_revision && deadline!=null && deadline.isAfter(DateTime.now())){
        await backend.schedule(deadline);
      }
    }).then<void>((_) {},onError:(Object _,StackTrace __){});
  }
  void configure(int seconds,{bool stopwatch=false}){
    _ticker?.cancel();
    state=TrainingTimerState(duration:seconds.clamp(1,86400).toInt(),stopwatch:stopwatch);
    _persist();
    _notify(null);
  }
  void start(){
    final now=DateTime.now();
    if(state.running)return;
    state=TrainingTimerState(duration:state.duration,stopwatch:state.stopwatch,
      elapsed:state.completeAt(now)?0:state.elapsed,startedAt:now);
    _persist();
    _notify(state.deadline);
    _ticker?.cancel();
    _ticker=Timer.periodic(const Duration(milliseconds:250),(_)=>refresh());
  }
  void refresh(){
    final current=state;
    if(!current.running)return;
    if(current.completeAt(DateTime.now())){
      _ticker?.cancel();
      state=current.pause(DateTime.now());
      _persist();
      // Leave the scheduled completion notification to the OS.
    }
  }
  void pause(){
    if(!state.running)return;
    _ticker?.cancel();
    state=state.pause(DateTime.now());
    _persist();
    _notify(null);
  }
  void reset()=>configure(state.duration,stopwatch:state.stopwatch);
}
