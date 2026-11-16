import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('deleting a queued song stops its decoder before removing media',(){
    final page=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    final start=page.indexOf("}else if(action=='delete'){");
    expect(start,greaterThanOrEqualTo(0));
    final end=page.indexOf('Future<void> _reorderCurrentPlaylist()',start);
    expect(end,greaterThan(start));
    final deletion=page.substring(start,end);
    expect(deletion,contains('player.queue.any((item)=>item.id==track.id)'));
    expect(deletion,contains('Este archivo está en la cola'));
    expect(deletion,contains('if(yes==true){'));
    expect(deletion,contains('if(queued)await player.stop();'));
    expect(deletion,contains('await library.removeTrack(track.id);'));
    expect(deletion.indexOf('await player.stop();'),
      lessThan(deletion.indexOf('await library.removeTrack(track.id);')));
  });

  test('a failed metadata write keeps user media, committed deletes survive stale covers',(){
    final library=File(
      'lib/features/motivation/data/motivation_library.dart',
    ).readAsStringSync();
    final start=library.indexOf('Future<void> removeTrack(String id)');
    final end=library.indexOf('Future<int> createSuggestedPlaylists(',start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final removal=library.substring(start,end);
    expect(removal,contains('final originalTracks=List<MotivationTrack>.of(_tracks);'));
    expect(removal,contains('final originalPlaylists=List<MotivationPlaylist>.of(_playlists);'));
    expect(removal,contains('await _changed();'));
    expect(removal,contains('_tracks..clear()..addAll(originalTracks);'));
    expect(removal,contains('_playlists..clear()..addAll(originalPlaylists);'));
    expect(removal.indexOf('await _changed();'),
      lessThan(removal.indexOf('final file=File(filePath(t));')));
    expect(removal,contains('if(await file.exists())await file.delete();'));
    expect(removal,contains('if(await artwork.exists())await artwork.delete();'));
    expect(removal,contains('catch(_){'));
  });

  test('clearing a cover does not undo persisted metadata on OS deletion error',(){
    final library=File(
      'lib/features/motivation/data/motivation_library.dart',
    ).readAsStringSync();
    final start=library.indexOf('Future<void> clearArtwork(String id)');
    final end=library.indexOf('List<MotivationTrack> forSelection(',start);
    final clear=library.substring(start,end);
    expect(clear,contains('await _changed();'));
    expect(clear,contains('_tracks[idx]=previous;'));
    expect(clear,contains('if(await file.exists())await file.delete();'));
    expect(clear,contains('catch(_){'));
  });
}
