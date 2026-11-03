import 'dart:convert';

import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Outfit is registered and physically bundled, not just named in UI', () async {
    final fontManifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
    final outfitEntry = fontManifest.cast<Map<String, dynamic>>().firstWhere(
      (entry) => entry['family'] == 'Outfit',
    );
    final fonts = outfitEntry['fonts'] as List<dynamic>;
    expect(
      fonts.any((item) =>
          (item as Map<String, dynamic>)['asset'] ==
          'assets/fonts/Outfit-Variable.ttf'),
      isTrue,
    );
    final bytes = await rootBundle.load('assets/fonts/Outfit-Variable.ttf');
    expect(bytes.lengthInBytes, greaterThan(100000));
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('app theme uses bundled Outfit in ${brightness.name}',
        (tester) async {
      final theme = AppearanceTheme.build(
        const AppearanceSettings(),
        brightness,
      );
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: const Scaffold(body: Text('STK Haven 15.912 kg')),
      ));
      final context = tester.element(find.text('STK Haven 15.912 kg'));
      expect(Theme.of(context).textTheme.bodyMedium?.fontFamily, 'Outfit');
      expect(tester.takeException(), isNull);
    });
  }
}
