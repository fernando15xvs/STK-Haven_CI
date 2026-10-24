import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import '../../../tool/visual_pilot_preview.dart';

const _ids = ['ex_bench_press', 'ex_barbell_row', 'ex_squat'];

void main() {
  final compositions = <String, LottieComposition>{};
  final metrics = <String, Object>{};
  final output = Directory('build/visual_pilots_flutter');

  setUpAll(() async {
    output.createSync(recursive: true);
    for (final id in _ids) {
      final bytes = File('tool/visual_pilots/$id.json').readAsBytesSync();
      final watch = Stopwatch()..start();
      compositions[id] = await LottieComposition.fromBytes(bytes);
      watch.stop();
      metrics[id] = {
        'bytes': bytes.length,
        'decodeMicroseconds': watch.elapsedMicroseconds,
        'environment': 'Flutter test runner; not device performance',
      };
    }
  });

  tearDownAll(() {
    File('${output.path}/decode_metrics.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metrics));
  });

  Widget host(String id, AppAccent accent, Brightness brightness,
      {double? progress, bool reduce = false}) {
    return MaterialApp(
      themeAnimationDuration: Duration.zero,
      theme: AppearanceTheme.build(AppearanceSettings(accent: accent), brightness),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(
          body: Center(
            child: VisualPilotPreview(
              composition: compositions[id]!,
              exerciseName: id,
              progress: progress,
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> capture(WidgetTester tester, String filename) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('pilot_canvas')));
    return (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      expect(image.width, 512);
      expect(image.height, 512);
      final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer.asUint8List();
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer.asUint8List();
      File('${output.path}/$filename.png').writeAsBytesSync(png);
      image.dispose();
      // More than a flat panel must have been painted by the actual Lottie renderer.
      var nonBackground = 0;
      var accentPixels = 0;
      final accent = AppColors.of(tester.element(find.byType(VisualPilotPreview)))
          .primary.toARGB32();
      for (var i = 0; i < raw.length; i += 4) {
        if (raw[i] != raw[0] || raw[i + 1] != raw[1] || raw[i + 2] != raw[2]) {
          nonBackground++;
        }
        if (raw[i] == ((accent >> 16) & 255) &&
            raw[i + 1] == ((accent >> 8) & 255) &&
            raw[i + 2] == (accent & 255)) {
          accentPixels++;
        }
      }
      expect(nonBackground, greaterThan(5000));
      expect(accentPixels, greaterThan(100),
          reason: 'The resolved STK accent must paint the clothing');
      return raw;
    }))!;
  }

  test('three review candidates decode within vector complexity budgets', () {
    for (final id in _ids) {
      final file = File('tool/visual_pilots/$id.json');
      final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(file.lengthSync(), lessThan(230000));
      expect((doc['layers'] as List).length, lessThan(55));
      expect(doc['assets'], isEmpty);
      expect(compositions[id]!.duration, const Duration(seconds: 4));
    }
    final manifest = jsonDecode(File('tool/visual_pilots/manifest.json').readAsStringSync());
    expect(manifest['approved'], isFalse);
    expect(manifest['enabled'], isFalse);
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('visual_pilots/')));
  });

  for (final id in _ids) {
    testWidgets('$id renders moving vectors in 2 modes and 8 accents', (tester) async {
      for (final brightness in Brightness.values) {
        Uint8List? previousAccent;
        for (final accent in AppAccent.values) {
          final prefix = '$id-${brightness.name}-${accent.name}';
          await tester.pumpWidget(host(id, accent, brightness, progress: 0));
          await tester.pump();
          final start = await capture(tester, '$prefix-start');
          if (previousAccent != null) {
            expect(listEquals(start, previousAccent), isFalse,
                reason: 'Theme delegates must change painted pixels');
          }
          previousAccent = start;
          await tester.pumpWidget(host(id, accent, brightness, progress: .5));
          await tester.pump();
          final middle = await capture(tester, '$prefix-middle');
          expect(listEquals(start, middle), isFalse,
              reason: 'The decoder must animate paths, not just parse JSON');
          await tester.pumpWidget(host(id, accent, brightness, progress: .999));
          await tester.pump();
          final end = await capture(tester, '$prefix-end');
          expect(listEquals(start, end), isTrue,
              reason: 'The held loop endpoints must render identically');
          expect(tester.takeException(), isNull);
        }
      }
    });
  }

  testWidgets('review playback pauses and reduced motion displays a still', (tester) async {
    await tester.pumpWidget(host(_ids.first, AppAccent.blue, Brightness.dark));
    await tester.pump(const Duration(milliseconds: 300));
    final animation = tester.widget<Lottie>(find.byType(Lottie)).controller!;
    expect(animation.value, greaterThan(0));
    await tester.tap(find.byKey(const Key('pilot_playback')));
    await tester.pump();
    final paused = animation.value;
    await tester.pump(const Duration(seconds: 1));
    expect(animation.value, paused);
    await tester.pumpWidget(host(_ids.first, AppAccent.blue, Brightness.dark, reduce: true));
    await tester.pump(const Duration(seconds: 1));
    expect(animation.value, .5);
    expect(find.byKey(const Key('pilot_playback')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
