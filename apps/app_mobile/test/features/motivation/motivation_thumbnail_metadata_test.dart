import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';

void main() {
  test('MP4 thumbnail field roundtrips without overwriting manual cover',(){
    final first=MotivationTrack(
      id:'sample',title:'Voz y video',fileName:'sample.mp4',
      mode:MotivationMode.discipline,
      importedAt:DateTime(2026,11,15),
      thumbnailFileName:'thumb_private.jpg',
      artworkFileName:'art_custom.webp',
    );
    final restored=MotivationTrack.fromJson(first.toJson());
    expect(restored.thumbnailFileName,'thumb_private.jpg');
    expect(restored.artworkFileName,'art_custom.webp');
    expect(restored.copyWith(clearArtwork:true).thumbnailFileName,
      'thumb_private.jpg');
  });

  test('old imported media remains valid when there is no thumbnail',(){
    final old=MotivationTrack.fromJson({
      'id':'old','title':'Video', 'fileName':'old.mp4',
      'mode':'hype','importedAt':'2026-11-14T10:00:00.000',
    });
    expect(old.thumbnailFileName,isNull);
    expect(old.isVideo,isTrue);
  });

  test('invalid thumbnail paths never escape private storage',(){
    for(final name in ['../outside.jpg','../../private.png']){
      expect(()=>MotivationTrack.fromJson({
        'id':'old','title':'Video','fileName':'old.mp4',
        'mode':'hype','importedAt':'2026-11-14T10:00:00.000',
        'thumbnailFileName':name,
      }),throwsFormatException);
    }
  });

  test('native thumbnail code avoids decoding video during UI build',(){
    final source=File(
      'lib/features/motivation/data/motivation_library.dart',
    ).readAsStringSync();
    final page=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(source,contains('VideoThumbnail.thumbnailData('));
    expect(source,contains('maxWidth:400,quality:65'));
    expect(source,contains('if(ext==\'mp4\')importedVideos.add(id);'));
    expect(source,contains('await ensureVideoThumbnail(id);'));
    expect(source,contains('thumbnailFileName'));
    expect(page,contains('Generar miniatura del video'));
    expect(page,contains('library.ensureVideoThumbnail(track.id)'));
    expect(page,contains('_MotivationArtwork(track: track, size: 52)'));
  });
}
