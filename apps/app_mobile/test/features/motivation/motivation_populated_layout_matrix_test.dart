import 'package:gym_tracker/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/application/motivation_playback.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';
import 'package:gym_tracker/features/motivation/presentation/motivation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

MotivationLibrary _fixtureLibrary() {
  final tracks = [
    for (var i = 0; i < 16; i++)
      MotivationTrack(
        id: 'synthetic-$i',
        title: i == 0
            ? 'Entrenamiento de fuerza y recuperación con título muy largo'
            : 'Pista de práctica ${i + 1} · fase de entrenamiento',
        fileName: 'synthetic-$i.${i.isEven ? 'mp3' : 'mp4'}',
        mode: MotivationMode.values[i % MotivationMode.values.length],
        importedAt: DateTime.utc(2026, 11, 16),
        favorite: i % 4 == 0,
      ),
  ];
  return MotivationLibrary.testSnapshot(
    tracks: tracks,
    playlists: [
      MotivationPlaylist(
        id: 'synthetic-playlist',
        title: 'Playlist muy larga de entrenamiento de fuerza y recuperación',
        trackIds: [for (final track in tracks) track.id],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'B2.8 populated Motivation library has no layout errors across '
    '3 widths, 3 text sizes, 3 themes and 8 accents',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = _fixtureLibrary();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(library.dispose);

      final audio = MotivationPlayback.instance;
      final oldError = audio.error;
      audio.error = null;
      addTearDown(() => audio.error = oldError);

      for (final width in <double>[320, 390, 430]) {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1;
        for (final scale in <double>[1, 1.6, 2]) {
          for (final variant in const <(Brightness, bool)>[
            (Brightness.light, false),
            (Brightness.dark, false),
            (Brightness.dark, true),
          ]) {
            for (final accent in AppAccent.values) {
              await tester.pumpWidget(MaterialApp(
                theme: AppearanceTheme.build(
                  AppearanceSettings(
                    accent: accent,
                    oledBlack: variant.$2,
                  ),
                  variant.$1,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: MotivationPage(libraryOverride: library),
                ),
              ));
              await tester.pump();
              expect(
                find.byKey(const ValueKey('motivation_library')),
                findsOneWidget,
              );
              expect(
                library.tracks.length,
                16,
                reason: 'populated snapshot was mutated while building',
              );
              expect(
                tester.takeException(),
                isNull,
                reason: 'populated library width=$width scale=$scale '
                    'brightness=${variant.$1} oled=${variant.$2} '
                    'accent=$accent',
              );
            }
          }
        }
      }
      // Rendering a library must never start a silent or audible source.
      expect(audio.currentTrack, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('B2.8 320dp 200% preset sheet is scrollable and cancellable',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final library = _fixtureLibrary();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(library.dispose);
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(MaterialApp(
      theme: AppearanceTheme.build(
        const AppearanceSettings(),
        Brightness.dark,
      ),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MotivationPage(libraryOverride: library),
      ),
    ));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('motivation_action_row_stacked')),
      findsWidgets,
    );
    // Playlist ideas are now a secondary action, not a large competing
    // control. The menu preserves the original voluntary suggestion flow.
    final actions = find.byKey(
      const ValueKey('motivation_playlist_actions'),
    );
    await tester.scrollUntilVisible(
      actions, 180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(actions);
    await tester.pumpAndSettle();
    final presetButton = find.byKey(
      const ValueKey('motivation_playlist_ideas'),
    );
    expect(presetButton, findsOneWidget);
    await tester.tap(presetButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('motivation_playlist_presets_scroll')),
      findsOneWidget,
    );
    expect(find.text('Ideas para tus playlists'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Dismiss a non-destructive suggestion: library metadata is unchanged.
    // A modal bottom sheet has no visible BackButton. Send the system
    // back navigation event instead of WidgetTester.pageBack(), which
    // specifically looks for a Material/Cupertino toolbar back button.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(library.playlists, hasLength(1));
    expect(library.tracks, hasLength(16));
    expect(MotivationPlayback.instance.currentTrack, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
