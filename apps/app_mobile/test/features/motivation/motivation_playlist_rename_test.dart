import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MotivationLibrary fixture() => MotivationLibrary.testSnapshot(
    tracks: [
      MotivationTrack(
        id: 'track-a', title: 'Mi audio', fileName: 'track-a.mp3',
        mode: MotivationMode.discipline,
        importedAt: DateTime.utc(2026, 11, 18),
      ),
    ],
    playlists: const [
      MotivationPlaylist(
        id: 'list-a',
        title: 'Rutina original',
        trackIds: ['track-a', 'track-removed'],
      ),
      MotivationPlaylist(
        id: 'list-b',
        title: 'Segunda lista',
        trackIds: [],
      ),
    ],
  );

  test('M13 rename list persists new title and preserves IDs and order',
      () async {
    final library = fixture();
    addTearDown(library.dispose);
    final beforeMedia = library.tracks.single.toJson();
    expect(await library.renamePlaylist('list-a', '  Mi fuerza  '), isTrue);
    expect(library.playlists.first.id, 'list-a');
    expect(library.playlists.first.title, 'Mi fuerza');
    expect(library.playlists.first.trackIds, ['track-a', 'track-removed']);
    expect(library.playlists.last.title, 'Segunda lista');
    expect(library.tracks.single.toJson(), beforeMedia);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('stk_motivation_library_v1');
    expect(saved, contains('"title":"Mi fuerza"'));
  });

  test('no empty, duplicate or unknown playlist names can overwrite data',
      () async {
    final library = fixture();
    addTearDown(library.dispose);
    for (final proposed in ['', '  ', 'SEGUNDA LISTA', 'x'.padRight(71, 'x')]) {
      expect(await library.renamePlaylist('list-a', proposed), isFalse);
    }
    expect(await library.renamePlaylist('not-found', 'Otro nombre'), isFalse);
    expect(library.playlists.first.title, 'Rutina original');
    expect(library.playlists.first.trackIds, ['track-a', 'track-removed']);
    expect(await library.renamePlaylist('list-a', 'Rutina original'), isTrue);
  });
}
