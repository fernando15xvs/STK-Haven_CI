import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/application/motivation_playback.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';
import 'package:gym_tracker/features/motivation/presentation/motivation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

MotivationTrack example(String id, String title, String file,
    {MotivationMode mode = MotivationMode.discipline, bool favorite = false}) {
  return MotivationTrack(
    id: id,
    title: title,
    fileName: file,
    mode: mode,
    favorite: favorite,
    importedAt: DateTime.utc(2026, 11, 18),
  );
}

Widget app(MotivationLibrary library) => MaterialApp(
  theme: AppearanceTheme.build(
    const AppearanceSettings(), Brightness.dark),
  home: MotivationPage(libraryOverride: library),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('M1 empty library offers one import/create action and no resume',
      (tester) async {
    final library = MotivationLibrary.testSnapshot(tracks: []);
    addTearDown(library.dispose);
    await tester.pumpWidget(app(library));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('motivation_library')), findsOneWidget);
    expect(find.byKey(const ValueKey('motivation_import')), findsOneWidget);
    expect(find.byKey(const ValueKey('motivation_create_playlist')),
        findsOneWidget);
    expect(find.text('Aún no has creado listas.'), findsOneWidget);
    expect(find.text('Todavía no hay archivos. Importa el primero.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('motivation_resume_last')), findsNothing);
    expect(find.byKey(const ValueKey('motivation_secondary_filters')),
        findsOneWidget);
    expect(MotivationPlayback.instance.currentTrack, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M1 import mode is voluntary and never starts playback',
      (tester) async {
    final library = MotivationLibrary.testSnapshot(tracks: []);
    addTearDown(library.dispose);
    await tester.pumpWidget(app(library));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('motivation_import')));
    await tester.pumpAndSettle();

    expect(find.text('Modo de importación'), findsOneWidget);
    for (final mode in MotivationMode.values) {
      expect(find.byKey(ValueKey('motivation_import_mode_'+mode.name)),
          findsOneWidget);
    }
    // Dismiss without choosing: system picker is never opened and metadata
    // remains untouched. No media is played automatically.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(library.tracks, isEmpty);
    expect(MotivationPlayback.instance.currentTrack, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M1 favorite/media/playlist filters compose without mutations',
      (tester) async {
    final first = example('first','Mi audio favorito','first.mp3',
        favorite: true);
    final second = example('second','Video fuerza','second.mp4',
        mode: MotivationMode.hype);
    final third = example('third','Audio calma','third.m4a',
        mode: MotivationMode.gymSad);
    final library = MotivationLibrary.testSnapshot(
      tracks: [first, second, third],
      playlists: [
        const MotivationPlaylist(
          id: 'training',
          title: 'Mi lista de fuerza',
          trackIds: ['second','first'],
        ),
      ],
    );
    addTearDown(library.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(library));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('track_first')), findsOneWidget);
    expect(find.byKey(const ValueKey('track_second')), findsOneWidget);
    expect(find.byKey(const ValueKey('motivation_compact_library_title')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('motivation_secondary_filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritos').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('track_first')), findsOneWidget);
    expect(find.byKey(const ValueKey('track_second')), findsNothing);
    expect(find.byKey(const ValueKey('motivation_clear_filter')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('motivation_clear_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('track_second')), findsOneWidget);
    expect(find.byKey(const ValueKey('track_first')), findsNothing);

    await tester.tap(find.text('Mi lista de fuerza'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('motivation_playlist_wrap_actions')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('track_second')), findsOneWidget);
    expect(find.byKey(const ValueKey('track_third')), findsNothing);
    expect(library.tracks, hasLength(3));
    expect(library.playlists.single.trackIds, ['second','first']);
    expect(MotivationPlayback.instance.currentTrack, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M1 readable at narrow width with 200 percent text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final library = MotivationLibrary.testSnapshot(tracks: [
      example('long',
        'Título muy largo de música de entrenamiento que no debe cortarse',
        'long.mp3'),
    ]);
    addTearDown(library.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppearanceTheme.build(
        const AppearanceSettings(), Brightness.dark),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MotivationPage(libraryOverride: library),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('motivation_action_row_stacked')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('motivation_import')), findsOneWidget);
    expect(find.byKey(const ValueKey('motivation_compact_library_title')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
