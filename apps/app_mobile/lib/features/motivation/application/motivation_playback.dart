import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/motivation_library.dart';

/// One shared native player survives navigation away from the library page.
/// MP4 is used as a media source for its audio track while in background.
class MotivationPlayback extends ChangeNotifier {
  MotivationPlayback._() {
    _subscriptions.add(audio.currentIndexStream.listen((_)=>notifyListeners()));
    _subscriptions.add(audio.playerStateStream.listen((_)=>notifyListeners()));
    _subscriptions.add(audio.durationStream.listen((_)=>notifyListeners()));
    _subscriptions.add(audio.errorStream.listen((e){
      error=e.message;
      notifyListeners();
    }));
  }
  static final instance=MotivationPlayback._();
  final AudioPlayer audio=AudioPlayer();
  final _subscriptions=<StreamSubscription<dynamic>>[];
  List<MotivationTrack> _original=[];
  List<MotivationTrack> _queue=[];
  MotivationRepeat repeat=MotivationRepeat.next;
  bool shuffle=false;
  String? error;

  MotivationTrack? get currentTrack {
    final i=audio.currentIndex;
    return i==null || i<0 || i>=_queue.length ? null : _queue[i];
  }
  bool get playing=>audio.playing;
  Duration get position=>audio.position;
  Duration? get duration=>audio.duration;
  List<MotivationTrack> get queue=>List.unmodifiable(_queue);

  Future<void> playQueue(List<MotivationTrack> tracks, {
    required int startIndex, Duration initialPosition=Duration.zero,
  }) async {
    if(tracks.isEmpty || startIndex<0 || startIndex>=tracks.length)return;
    error=null;
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
    await audio.stop();
    _queue=[];
    _original=[];
    notifyListeners();
  }
}
