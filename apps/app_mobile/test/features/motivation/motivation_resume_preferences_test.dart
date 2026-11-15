import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/application/motivation_resume_snapshot.dart';

void main() {
  test('local resume restores explicit playlist order and position',(){
    const snapshot=MotivationResumeSnapshot(
      trackId:'song-b',queueIds:['song-a','song-b','song-c'],
      positionMs:125000);
    final restored=MotivationResumeSnapshot.fromJson(snapshot.toJson());
    expect(restored.trackId,'song-b');
    expect(restored.queueIds,['song-a','song-b','song-c']);
    expect(restored.positionMs,125000);
  });

  test('malformed resume never creates a playing track or invalid index',(){
    for(final data in [
      <String,dynamic>{'v':1,'trackId':'missing',
        'queueIds':['other'],'positionMs':0},
      <String,dynamic>{'v':1,'trackId':'song',
        'queueIds':[],'positionMs':0},
      <String,dynamic>{'v':1,'trackId':'song',
        'queueIds':['song'],'positionMs':-20},
      <String,dynamic>{'v':2,'trackId':'song',
        'queueIds':['song'],'positionMs':20},
    ]){
      expect(()=>MotivationResumeSnapshot.fromJson(data),throwsFormatException);
    }
  });

  test('duplicate IDs do not inflate a restored local queue',(){
    final restored=MotivationResumeSnapshot.fromJson({
      'v':1,'trackId':'a',
      'queueIds':['a','a','b','b'],'positionMs':55,
    });
    expect(restored.queueIds,['a','b']);
  });

  test('restoring a saved session is explicitly user initiated',(){
    final playback=File(
      'lib/features/motivation/application/motivation_playback.dart',
    ).readAsStringSync();
    final page=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(playback,contains('Future<bool> resumeLast() async'));
    expect(playback,contains('Future<void> saveResume() async'));
    expect(playback,contains("prefs.setString(_repeatKey,repeat.name)"));
    expect(playback,contains('prefs.setBool(_shuffleKey,shuffle)'));
    expect(playback,contains('AppLifecycleState.inactive'));
    expect(page,contains("ValueKey('motivation_resume_last')"));
    expect(page,contains('onTap:()async{'));
    expect(page,contains('player.resumeLast()'));
    expect(page,contains('Solo se reproduce cuando tú lo eliges.'));
  });
}
