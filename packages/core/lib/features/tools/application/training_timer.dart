import 'dart:async';
import 'package:riverpod/riverpod.dart';

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
  int _revision=0;
  late TrainingTimerNative _native;
  @override TrainingTimerState build(){
    _native=ref.read(trainingTimerNativeProvider);
    ref.onDispose((){
      _ticker?.cancel();
      _revision++;
    });
    return const TrainingTimerState();
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
    _notify(null);
  }
  void start(){
    final now=DateTime.now();
    if(state.running)return;
    state=TrainingTimerState(duration:state.duration,stopwatch:state.stopwatch,
      elapsed:state.completeAt(now)?0:state.elapsed,startedAt:now);
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
      // Leave the scheduled completion notification to the OS.
    }
  }
  void pause(){
    if(!state.running)return;
    _ticker?.cancel();
    state=state.pause(DateTime.now());
    _notify(null);
  }
  void reset()=>configure(state.duration,stopwatch:state.stopwatch);
}
