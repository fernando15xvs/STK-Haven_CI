import 'dart:io';

import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/application/motivation_playback.dart';
import 'package:gym_tracker/features/motivation/presentation/motivation_page.dart';

void main() {
  testWidgets('Motivation empty player remains readable in every accent, '
      'theme, width and text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final playback=MotivationPlayback.instance;
    final previousError=playback.error;
    playback.error=null;
    addTearDown(() => playback.error=previousError);

    for (final width in <double>[320,390,430]) {
      tester.view.physicalSize=Size(width,740);
      tester.view.devicePixelRatio=1;
      for (final scale in <double>[1,1.6,2]) {
        for (final variant in <(Brightness,bool)>[
          (Brightness.light,false),
          (Brightness.dark,false),
          (Brightness.dark,true),
        ]) {
          for (final accent in AppAccent.values) {
            await tester.pumpWidget(MaterialApp(
              theme:AppearanceTheme.build(
                AppearanceSettings(accent:accent,oledBlack:variant.$2),
                variant.$1),
              home:MediaQuery(
                data:MediaQueryData(textScaler:TextScaler.linear(scale)),
                child:const MotivationNowPlayingPage(),
              ),
            ));
            await tester.pump();
            expect(find.text('No hay archivos reproduciéndose.'),
              findsOneWidget);
            expect(tester.takeException(),isNull,
              reason:'width=$width scale=$scale '
                'brightness=${variant.$1} oled=${variant.$2} '
                'accent=$accent');
          }
        }
      }
    }
  });

  testWidgets('failed native playback remains visible without private paths',
      (tester) async {
    final playback=MotivationPlayback.instance;
    final old=playback.error;
    playback.error='No se pudo reproducir el archivo. '
      'Comprueba si su formato es compatible.';
    addTearDown(() => playback.error=old);
    await tester.pumpWidget(const MaterialApp(
      home:MotivationNowPlayingPage(),
    ));
    expect(find.byKey(const ValueKey('motivation_safe_playback_error')),
      findsOneWidget);
    expect(find.text('No hay archivos reproduciéndose.'),findsOneWidget);
    expect(find.text(playback.error!),findsOneWidget);
  });

  test('import and artwork errors never echo native private file paths',(){
    final page=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(page,contains('motivation_safe_playback_error'));
    expect(page,isNot(contains("e.toString()")));
    expect(page,isNot(contains('Error de importación:')));
    expect(page,isNot(contains('No se pudo guardar la portada:')));
    expect(page,contains('El archivo importado se conserva.'));
    expect(page,contains("motivation_library_safe_load_error"));
    expect(page,contains("motivation_library_retry"));
    expect(page,contains("unawaited(_loadLibrary())"));
    expect(page,contains("labelStyle:AppTypography.labelMedium.copyWith("));
    // The retry button must remain reachable with large accessibility text.
    expect(page,contains('constraints:const BoxConstraints(minHeight:180)'));
    expect(page,contains('mainAxisSize:MainAxisSize.min'));
  });
}
