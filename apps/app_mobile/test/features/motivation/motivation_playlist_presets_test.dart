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
  MotivationTrack local(String id,MotivationMode mode,{bool favorite=false})=>
    MotivationTrack(id:id,title:id,fileName:'$id.mp3',
      mode:mode,importedAt:DateTime(2026,11,15),favorite:favorite);

  test('context suggestions use only matching private tracks, prioritizing favorites',(){
    final tracks=[
      local('sad',MotivationMode.gymSad),
      local('hype',MotivationMode.hype),
      local('focus',MotivationMode.discipline),
      local('fav-hype',MotivationMode.hype,favorite:true),
    ];
    final warm=MotivationPlaylistPresets.suggestTracks(
      tracks,MotivationPlaylistContext.warmUp);
    expect(warm.map((t)=>t.id),['fav-hype','hype']);
    final during=MotivationPlaylistPresets.suggestTracks(
      tracks,MotivationPlaylistContext.session);
    expect(during.map((t)=>t.id),['fav-hype','hype','focus']);
    final focus=MotivationPlaylistPresets.suggestTracks(
      tracks,MotivationPlaylistContext.focus);
    expect(focus.map((t)=>t.id),['focus']);
    final recovery=MotivationPlaylistPresets.suggestTracks(
      tracks,MotivationPlaylistContext.recovery);
    expect(recovery.map((t)=>t.id),['sad']);
    expect(MotivationPlaylistPresets.suggestTracks(
      tracks,MotivationPlaylistContext.recovery,limit:0),isEmpty);
    expect(tracks.map((t)=>t.id),['sad','hype','focus','fav-hype']);
  });

  test('preview preserves track identity and never creates or autoplays',(){
    final source=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    final start=source.indexOf('Future<void> _suggestContextPlaylist()');
    final stop=source.indexOf('Future<void> _edit(',start);
    final preview=source.substring(start,stop);
    expect(preview,contains('MotivationPlaylistPresets.suggestTracks('));
    expect(preview,contains('CheckboxListTile('));
    expect(preview,contains('selected.isEmpty?null'));
    expect(preview,contains('library.createContextPlaylist(title,picked)'));
    expect(preview,isNot(contains('player.playQueue(')));
    expect(preview,isNot(contains('player.playAtIndex(')));
    final library=File(
      'lib/features/motivation/data/motivation_library.dart',
    ).readAsStringSync();
    final begin=library.indexOf('Future<bool> createContextPlaylist(');
    final end=library.indexOf('/// Flutter ReorderableListView',begin);
    final save=library.substring(begin,end);
    expect(save,contains('final unique=<String>{};'));
    expect(save,contains('final previous=List<MotivationPlaylist>.of(_playlists);'));
    expect(save,contains('await _savePlaylistsWithRollback(previous);'));
    expect(save,isNot(contains('player.playQueue(')));
  });

  test('every playlist mutation restores the prior list on a failed write',(){
    final library=File('lib/features/motivation/data/motivation_library.dart')
      .readAsStringSync();
    final index=library.indexOf('Future<void> _savePlaylistsWithRollback(');
    final helper=library.substring(index,library.indexOf('Future<void> _changed()',index));
    expect(helper,contains('await _changed();'));
    expect(helper,contains('_playlists..clear()..addAll(previous);'));
    expect(helper,contains('rethrow;'));
    for(final method in [
      'createSuggestedPlaylists','createPlaylist','createContextPlaylist',
      'renamePlaylist','reorderPlaylist','deletePlaylist','togglePlaylistTrack'
    ]){
      final start=library.indexOf(' $method(');
      expect(start,greaterThan(0));
      final end=library.indexOf('\n  }',start);
      expect(library.substring(start,end),
        contains('await _savePlaylistsWithRollback(previous);'));
    }
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
