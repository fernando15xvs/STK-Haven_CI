import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/motivation_library.dart';
import 'motivation_sleep_timer.dart';
import 'motivation_resume_snapshot.dart';

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
    if(state==AppLifecycleState.inactive ||
       state==AppLifecycleState.paused){
      unawaited(saveResume());
    }
  }

  static final instance=MotivationPlayback._();
  final AudioPlayer audio=AudioPlayer();
  late final MotivationSleepTimer sleepTimer;
  static const _volumeKey='stk_motivation_volume_v1';
  static const _speedKey='stk_motivation_speed_v1';
  static const _repeatKey='stk_motivation_repeat_v1';
  static const _shuffleKey='stk_motivation_shuffle_v1';
  static const _resumeKey='stk_motivation_resume_v1';
  double volume=1.0;
  double speed=1.0;
  Future<void>? _loadingPreferences;
  final _subscriptions=<StreamSubscription<dynamic>>[];
  List<MotivationTrack> _original=[];
  List<MotivationTrack> _queue=[];
  MotivationRepeat repeat=MotivationRepeat.next;
  bool shuffle=false;
  MotivationResumeSnapshot? resumeSnapshot;
  String? error;

  String? get resumeTitle {
    final id=resumeSnapshot?.trackId;
    if(id==null)return null;
    for(final item in MotivationLibrary.instance.tracks){
      if(item.id==id)return item.title;
    }
    return null;
  }

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
  /// just_audio can keep playing=true after the final sample has completed.
  bool get completed => audio.processingState == ProcessingState.completed;
  bool get playing => audio.playing && !completed;
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
    repeat=MotivationRepeat.values.firstWhere(
      (value)=>value.name==prefs.getString(_repeatKey),
      orElse:()=>MotivationRepeat.next);
    shuffle=prefs.getBool(_shuffleKey)??false;
    final raw=prefs.getString(_resumeKey);
    if(raw!=null){
      try{
        resumeSnapshot=MotivationResumeSnapshot.fromJson(
          Map<String,dynamic>.from(jsonDecode(raw) as Map));
      }catch(_){resumeSnapshot=null;}
    }
    await audio.setVolume(volume);
    await audio.setSpeed(speed);
    notifyListeners();
  }
  /// Persist stable metadata only on a real playback event or app pause.
  /// This never grants permission to start media automatically.
  Future<void> saveResume() async {
    final track=currentTrack;
    if(track==null)return;
    final queueIds=<String>[
      for(final item in _original)item.id,
    ];
    if(!queueIds.contains(track.id))queueIds.add(track.id);
    final position=audio.position.inMilliseconds.clamp(0,24*60*60*1000).toInt();
    final snapshot=MotivationResumeSnapshot(
      trackId:track.id,
      queueIds:List.unmodifiable(queueIds),
      positionMs:position,
    );
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(_resumeKey,jsonEncode(snapshot.toJson()));
    resumeSnapshot=snapshot;
    notifyListeners();
  }

  /// User initiated only. Removed tracks are skipped; the original library
  /// is never overwritten and no playback starts without a valid selected ID.
  Future<bool> resumeLast() async {
    await loadAudioPreferences();
    final snapshot=resumeSnapshot;
    if(snapshot==null)return false;
    await MotivationLibrary.instance.load();
    final available={
      for(final item in MotivationLibrary.instance.tracks)item.id:item,
    };
    final selected=available[snapshot.trackId];
    if(selected==null)return false;
    final tracks=[
      for(final id in snapshot.queueIds)
        if(available.containsKey(id))available[id]!,
    ];
    final index=tracks.indexWhere((t)=>t.id==selected.id);
    if(index<0)return false;
    await playQueue(tracks,startIndex:index,
      initialPosition:Duration(milliseconds:snapshot.positionMs));
    return error==null && currentTrack?.id==selected.id;
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
    bool autoPlay=true,
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
      // A paused user must never hear a burst of audio while changing modes.
      // play() completes only when playback ends, so do not await it.
      if(autoPlay)unawaited(audio.play());
      await saveResume();
    }catch(_){
      // An unsupported video codec or a missing file must never leave the
      // old sound playing under a new track title. Do not show file paths.
      try{
        await audio.stop();
      }catch(_){/* Preserve the original decoding failure. */}
      _queue=[];
      _original=[];
      error='No se pudo reproducir el archivo. '
        'Comprueba si su formato es compatible.';
      notifyListeners();
    }
    notifyListeners();
  }

  Future<void> setRepeat(MotivationRepeat value) async {
    if(repeat==value)return;
    final current=currentTrack;
    final position=audio.position;
    final wasPlaying=playing;
    repeat=value;
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(_repeatKey,repeat.name);
    if(current==null){notifyListeners();return;}
    if(value==MotivationRepeat.stop ||
       _queue.length!=_original.length) {
      final i=_original.indexWhere((t)=>t.id==current.id);
      if(i>=0){
        await playQueue(_original,startIndex:i,
          initialPosition:completed ? Duration.zero : position,
          autoPlay:wasPlaying);
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
    final prefs=await SharedPreferences.getInstance();
    await prefs.setBool(_shuffleKey,shuffle);
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if(playing){
      await audio.pause();
      await saveResume();
    }else if(currentTrack!=null){
      // completed is orthogonal to playing: simply calling play() at the
      // end leaves the native decoder at EOF. Explicitly rewind first.
      if(completed) await audio.seek(Duration.zero);
      unawaited(audio.play());
    }
    notifyListeners();
  }
  Future<void> seek(Duration to) => audio.seek(to);
  Future<void> playAtIndex(int index) async {
    if(index<0 || index>=_queue.length)return;
    await audio.seek(Duration.zero,index:index);
    await saveResume();
    if(!playing)unawaited(audio.play());
    notifyListeners();
  }

  Future<void> next() async {
    if(audio.hasNext){
      await audio.seekToNext();
      await saveResume();
      if(!audio.playing)unawaited(audio.play());
    }
  }
  Future<void> previous() async {
    if(audio.position>const Duration(seconds:3)){
      await audio.seek(Duration.zero);
    }else if(audio.hasPrevious){
      await audio.seekToPrevious();
      await saveResume();
    }else{
      await audio.seek(Duration.zero);
    }
  }
  Future<void> stop() async {
    sleepTimer.cancel();
    await saveResume();
    await audio.stop();
    _queue=[];
    _original=[];
    notifyListeners();
  }
}
