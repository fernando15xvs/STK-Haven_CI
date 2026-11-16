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

  test('malicious artwork paths are rejected', () {
    expect(()=>MotivationTrack.fromJson({
      'id':'x','title':'Voz','fileName':'x.mp3',
      'artworkFileName':'../secret.jpg',
      'mode':'hype','importedAt':'2026-11-14T10:00:00.000',
    }),throwsFormatException);
  });
}
