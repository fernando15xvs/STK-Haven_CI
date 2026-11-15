import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/application/motivation_playlist_presets.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';

void main(){
  test('four meaningful optional playlists are not created by reading ideas',(){
    expect(MotivationPlaylistPresets.titles,[
      'Antes de entrenar',
      'Durante el entrenamiento',
      'Concentración',
      'Recuperación',
    ]);
    final list=<MotivationPlaylist>[];
    expect(MotivationPlaylistPresets.notYetCreated(list),
      MotivationPlaylistPresets.titles);
    expect(list,isEmpty);
  });
  test('existing playlist titles are never suggested again',(){
    final have=[
      const MotivationPlaylist(id:'existing',title:'concentración',
        trackIds:['audio-a']),
    ];
    final remaining=MotivationPlaylistPresets.notYetCreated(have);
    expect(remaining,hasLength(3));
    expect(remaining,contains('Recuperación'));
    expect(remaining, isNot(contains('Concentración')));
    expect(have.single.trackIds,['audio-a']);
  });
  test('UI asks for selections before saving, never autoplays',(){
    final source=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(source,contains("ValueKey('motivation_playlist_ideas')"));
    expect(source,contains('CheckboxListTile('));
    expect(source,contains('selected.isEmpty?null'));
    expect(source,contains('createSuggestedPlaylists(chosen)'));
  });
}
