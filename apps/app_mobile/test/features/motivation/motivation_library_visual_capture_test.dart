import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/application/motivation_playback.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';
import 'package:gym_tracker/features/motivation/presentation/motivation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit-Variable.ttf'));
    await font.load();
  });

  testWidgets('B3 Motivation: render 24 synthetic library PNGs in real Outfit',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    final tracks = [
      for (var i = 0; i < 7; i++)
        MotivationTrack(
          id: 'qa-track-$i',
          title: i == 0
              ? 'Disciplina diaria · fuerza, hábitos y enfoque con título largo'
              : 'Pista de ejemplo ${i + 1} para entrenar',
          fileName: 'qa-track-$i.${i.isEven ? 'mp3' : 'mp4'}',
          mode: MotivationMode.values[i % MotivationMode.values.length],
          importedAt: DateTime.utc(2026, 11, 16),
          favorite: i.isEven,
        ),
    ];
    final library = MotivationLibrary.testSnapshot(
      tracks: tracks,
      playlists: [
        MotivationPlaylist(
          id: 'qa-playlist',
          title: 'Playlist sintética de fuerza y recuperación',
          trackIds: [for (final track in tracks) track.id],
        ),
      ],
    );
    addTearDown(library.dispose);
    final playback = MotivationPlayback.instance;
    final previousError = playback.error;
    playback.error = null;
    addTearDown(() => playback.error = previousError);

    final directory = Directory('build/motivation_visual_qa')
      ..createSync(recursive: true);
    var captured = 0;
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
          home: RepaintBoundary(
            key: const ValueKey('motivation_visual_qa_capture'),
            child: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.6),
              ),
              child: MotivationPage(libraryOverride: library),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('motivation_library')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull,
            reason: 'Motivation artwork theme=${variant.$1} '
                'oled=${variant.$2} accent=$accent');
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('motivation_visual_qa_capture')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            expect(data, isNotNull);
            final scheme = variant.$2
                ? 'oled'
                : variant.$1 == Brightness.dark ? 'dark' : 'light';
            final file = File(
              '${directory.path}/motivation_${scheme}_${accent.name}.png',
            );
            file.writeAsBytesSync(data!.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            ));
            expect(file.lengthSync(), greaterThan(1000));
            captured++;
          } finally {
            image.dispose();
          }
        });
      }
    }
    expect(captured, 24);
    expect(library.tracks, hasLength(7));
    expect(playback.currentTrack, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
