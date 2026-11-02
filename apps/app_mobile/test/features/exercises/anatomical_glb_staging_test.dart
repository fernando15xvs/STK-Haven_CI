import 'dart:io';
import 'dart:typed_data';

import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_staging.dart';

void main() {
  for (final id in AnatomicalGlbStaging.stableIds) {
    test('GLB staging has 19 joints and animation but stays unpublished: $id', () {
      final data = File('build/anatomical_3d_glb/$id.glb').readAsBytesSync();
      final model = AnatomicalGlbStaging.parse(data);
      expect(model.id, id);
      expect(model.jointCount, 19);
      expect(model.animationCount, 1);
      expect(model.meshCount, greaterThanOrEqualTo(2));
      expect(model.byteLength, lessThan(AnatomicalGlbStaging.maxByteLength));
      expect(model.materialRoles, containsAll(['primary', 'secondary']));
    });
  }

  test('No corrupt or oversized model can enter staging', () {
    expect(() => AnatomicalGlbStaging.parse(
      File('build/anatomical_3d_glb/ex_squat.glb').readAsBytesSync().sublist(0, 20)),
      throwsFormatException);
    expect(() => AnatomicalGlbStaging.parse(
      Uint8List(AnatomicalGlbStaging.maxByteLength + 1)),
      throwsFormatException);
  });

  for (final brightness in Brightness.values) {
    for (final accent in AppAccent.values) {
      testWidgets('Theme override contract $brightness $accent', (tester) async {
        late Map<String, Color> materials;
        await tester.pumpWidget(MaterialApp(
          theme: AppearanceTheme.build(
            AppearanceSettings(accent: accent), brightness),
          home: Builder(builder: (context) {
            materials = AnatomicalGlbStaging.themeMaterials(context);
            return const SizedBox.shrink();
          }),
        ));
        expect(materials['STK_PRIMARY'], isNotNull);
        expect(materials['STK_SECONDARY'], isNotNull);
        expect(materials['STK_PRIMARY'], isNot(materials['STK_BODY']));
      });
    }
  }
}
