import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/application/motivation_library_search.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';

void main(){
  final a=MotivationTrack(id:'a',title:'Música de concentración',
    fileName:'a.mp3',mode:MotivationMode.discipline,
    importedAt:DateTime(2026,11,14));
  final b=MotivationTrack(id:'b',title:'Fuerza y técnica',
    fileName:'b.mp4',mode:MotivationMode.hype,
    importedAt:DateTime(2026,11,14));
  final c=MotivationTrack(id:'c',title:'Sin perder el foco',
    fileName:'c.wav',mode:MotivationMode.gymSad,
    importedAt:DateTime(2026,11,15));

  test('accent and case insensitive title search, stable order',(){
    expect(MotivationLibrarySearch.filter([a,b,c],
      query:'MUSICA').map((t)=>t.id),['a']);
    expect(MotivationLibrarySearch.filter([b,c,a],
      query:'teCNica').map((t)=>t.id),['b']);
    expect(MotivationLibrarySearch.filter([b,c,a]).map((t)=>t.id),
      ['b','c','a']);
  });
  test('audio/video filter applies without modifying playlist order',(){
    final tracks=[c,b,a];
    expect(MotivationLibrarySearch.filter(tracks,
      media:MotivationMediaFilter.video).map((t)=>t.id),['b']);
    expect(MotivationLibrarySearch.filter(tracks,
      media:MotivationMediaFilter.audio).map((t)=>t.id),['c','a']);
    expect(tracks.map((t)=>t.id),['c','b','a']);
  });
  test('query and media type compose; no results never invents tracks',(){
    expect(MotivationLibrarySearch.filter([a,b,c],query:'hype',
      media:MotivationMediaFilter.video).map((t)=>t.id),['b']);
    expect(MotivationLibrarySearch.filter([a,b,c],query:'hype',
      media:MotivationMediaFilter.audio),isEmpty);
  });
}
