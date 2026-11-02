import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/motivation_library.dart';
import 'motivation_sleep_timer.dart';

/// One shared native player survives navigation away from the library page.
/// MP4 is used as a media source for its audio track while in background.
class MotivationPlayback extends ChangeNotifier with WidgetsBindingObserver {
  MotivationPlayback._() {
    sleepTimer=MotivationSleepTimer(onExpired:()=>unawaited(stop()));
    WidgetsBinding.instance.addObserver(this);
    _subscriptions.add(audio.currentIndexStream.listen((_)=>notifyListeners()));
    _subscriptions.add(audio.playerStateStream.listen((_)=>notifyListeners()));
    _subscriptions.add(audio.durationStream.listen((_)=>notifyListeners()));
    _subscriptions.add(audio.errorStream.listen((e){
      error=e.message;
      notifyListeners();
    }));
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed) sleepTimer.checkDeadline();
  }

  static final instance=MotivationPlayback._();
  final AudioPlayer audio=AudioPlayer();
  late final MotivationSleepTimer sleepTimer;
  static const _volumeKey='stk_motivation_volume_v1';
  static const _speedKey='stk_motivation_speed_v1';
  double volume=1.0;
  double speed=1.0;
  Future<void>? _loadingPreferences;
  final _subscriptions=<StreamSubscription<dynamic>>[];
  List<MotivationTrack> _original=[];
  List<MotivationTrack> _queue=[];
  MotivationRepeat repeat=MotivationRepeat.next;
  bool shuffle=false;
  String? error;

  MotivationTrack? get currentTrack {
    final i=audio.currentIndex;
    if(i==null || i<0 || i>=_queue.length)return null;
    // Media metadata may have been edited (favorite/mode/title) while playing.
    final track=_queue[i];
    for(final fresh in MotivationLibrary.instance.tracks){
      if(fresh.id==track.id)return fresh;
    }
    return track;
  }
  bool get playing=>audio.playing;
  Duration get position=>audio.position;
  Duration? get duration=>audio.duration;
  List<MotivationTrack> get queue=>List.unmodifiable(_queue);

  Future<void> loadAudioPreferences(){
    return _loadingPreferences ??= _loadAudioPreferences();
  }
  Future<void> _loadAudioPreferences() async {
    final prefs=await SharedPreferences.getInstance();
    volume=(prefs.getDouble(_volumeKey)??1.0).clamp(0.0,1.0).toDouble();
    speed=(prefs.getDouble(_speedKey)??1.0).clamp(0.75,1.5).toDouble();
    await audio.setVolume(volume);
    await audio.setSpeed(speed);
    notifyListeners();
  }
  Future<void> setVolume(double value) async {
    volume=value.clamp(0.0,1.0).toDouble();
    await audio.setVolume(volume);
    final prefs=await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey,volume);
    notifyListeners();
  }
  Future<void> setSpeed(double value) async {
    speed=value.clamp(0.75,1.5).toDouble();
    await audio.setSpeed(speed);
    final prefs=await SharedPreferences.getInstance();
    await prefs.setDouble(_speedKey,speed);
    notifyListeners();
  }
  void setSleepTimer(Duration duration){
    if(currentTrack==null || duration<=Duration.zero)return;
    sleepTimer.start(duration);
  }
  void cancelSleepTimer()=>sleepTimer.cancel();


  Future<void> playQueue(List<MotivationTrack> tracks, {
    required int startIndex, Duration initialPosition=Duration.zero,
  }) async {
    if(tracks.isEmpty || startIndex<0 || startIndex>=tracks.length)return;
    error=null;
    await loadAudioPreferences();
    _original=List.of(tracks);
    final selected=tracks[startIndex];
    _queue=repeat==MotivationRepeat.stop?[selected]:List.of(tracks);
    final index=repeat==MotivationRepeat.stop?0:startIndex;
    try{
      final library=MotivationLibrary.instance;
      // Loading from a file URI keeps the native decoder and metadata intact.
      final sources=<AudioSource>[];
      for(final track in _queue){
        final file=File(library.filePath(track));
        if(!await file.exists()){
          throw const FileSystemException('El archivo ya no está disponible');
        }
        sources.add(AudioSource.uri(file.uri,tag:MediaItem(
          id:track.id,title:track.title,album:'STK Motivation',
          artist:track.mode.label)));
      }
      await audio.setAudioSources(sources,initialIndex:index,
        initialPosition:initialPosition);
      await audio.setLoopMode(switch(repeat){
        MotivationRepeat.one=>LoopMode.one,
        MotivationRepeat.all=>LoopMode.all,
        _=>LoopMode.off,
      });
      await audio.setShuffleModeEnabled(shuffle && _queue.length>1);
      // Intentionally not awaited: play() completes only after playback ends.
      unawaited(audio.play());
    }catch(e){
      error='No se pudo reproducir este archivo. Comprueba el códec: $e';
      notifyListeners();
    }
    notifyListeners();
  }

  Future<void> setRepeat(MotivationRepeat value) async {
    if(repeat==value)return;
    final current=currentTrack;
    final position=audio.position;
    final wasPlaying=audio.playing;
    repeat=value;
    if(current==null)return;
    if(value==MotivationRepeat.stop ||
       _queue.length!=_original.length) {
      final i=_original.indexWhere((t)=>t.id==current.id);
      if(i>=0){
        await playQueue(_original,startIndex:i,initialPosition:position);
        if(!wasPlaying)await audio.pause();
      }
    }else{
      await audio.setLoopMode(switch(value){
        MotivationRepeat.one=>LoopMode.one,
        MotivationRepeat.all=>LoopMode.all,
        _=>LoopMode.off,
      });
    }
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    shuffle=!shuffle;
    await audio.setShuffleModeEnabled(shuffle && _queue.length>1);
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if(audio.playing){
      await audio.pause();
    }else if(currentTrack!=null){
      unawaited(audio.play());
    }
    notifyListeners();
  }
  Future<void> seek(Duration to) => audio.seek(to);
  Future<void> next() async {
    if(audio.hasNext){
      await audio.seekToNext();
      if(!audio.playing)unawaited(audio.play());
    }
  }
  Future<void> previous() async {
    if(audio.position>const Duration(seconds:3)){
      await audio.seek(Duration.zero);
    }else if(audio.hasPrevious){
      await audio.seekToPrevious();
    }else{
      await audio.seek(Duration.zero);
    }
  }
  Future<void> stop() async {
    sleepTimer.cancel();
    await audio.stop();
    _queue=[];
    _original=[];
    notifyListeners();
  }
}
