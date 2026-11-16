import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';

void main() {
  test('legacy tracks without artwork keep title and mode unchanged', () {
    final legacy=MotivationTrack.fromJson({
      'id':'legacy','title':'Mi audio','fileName':'legacy.mp3',
      'mode':'discipline','importedAt':'2026-11-14T10:00:00.000',
    });
    expect(legacy.artworkFileName,isNull);
    expect(legacy.title,'Mi audio');
    expect(legacy.mode,MotivationMode.discipline);
  });

  test('cover file persists as a relative private filename and can be cleared', () {
    final track=MotivationTrack(id:'safe',title:'Personal',
      fileName:'safe.mp4',mode:MotivationMode.hype,
      artworkFileName:'art_safe.webp',importedAt:DateTime(2026,11,14));
    final restored=MotivationTrack.fromJson(track.toJson());
    expect(restored.isVideo,isTrue);
    expect(restored.artworkFileName,'art_safe.webp');
    expect(restored.copyWith(title:'Nuevo').artworkFileName,'art_safe.webp');
    expect(restored.copyWith(clearArtwork:true).artworkFileName,isNull);
  });

  test('failed metadata writes do not delete media or previous cover', () {
    final source=File('lib/features/motivation/data/motivation_library.dart')
        .readAsStringSync();
    expect(source,contains('_tracks[idx]=previous;'));
    expect(source,contains('_tracks..clear()..addAll(originalTracks);'));
    expect(source,contains('_playlists..clear()..addAll(originalPlaylists);'));
    expect(source,contains('Never delete the media while its removal failed'));
  });

  test('title, favorite and mode revert if their metadata write fails',(){
    final source=File(
      'lib/features/motivation/data/motivation_library.dart',
    ).readAsStringSync();
    for(final method in <String>['renameTrack','toggleFavorite','changeMode']){
      final start=source.indexOf('Future<void> $method(');
      expect(start,greaterThan(0));
      final next=source.indexOf('  Future<void>',start+12);
      final body=source.substring(start,next);
      expect(body,contains('final previous=_tracks[i];'));
      expect(body,contains('await _changed();'));
      expect(body,contains('}catch(_){'));
      expect(body,contains('_tracks[i]=previous;'));
      expect(body,contains('rethrow;'));
    }
  });

  test('uncertain thumbnail and cover metadata never deletes referenced images',(){
    final source=File('lib/features/motivation/data/motivation_library.dart')
      .readAsStringSync();
    final thumb=source.substring(
      source.indexOf('Future<bool> ensureVideoThumbnail('),
      source.indexOf('Future<bool> chooseArtwork('));
    final cover=source.substring(
      source.indexOf('Future<bool> chooseArtwork('),
      source.indexOf('Future<void> clearArtwork('));
    for(final body in [thumb,cover]){
      expect(body,contains('var mayStillBeReferenced=false;'));
      expect(body,contains('mayStillBeReferenced=true;'));
      expect(body,contains('if(!mayStillBeReferenced){'));
      expect(body,contains('await _changed();'));
      expect(body,contains('if(await destination.exists())await destination.delete();'));
    }
    expect(cover,contains('final previous=_tracks[currentIdx];'));
    expect(thumb,contains('final previous=_tracks[latest];'));
  });

  test('malicious artwork paths are rejected', () {
    expect(()=>MotivationTrack.fromJson({
      'id':'x','title':'Voz','fileName':'x.mp3',
      'artworkFileName':'../secret.jpg',
      'mode':'hype','importedAt':'2026-11-14T10:00:00.000',
    }),throwsFormatException);
  });
}
