import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_staging.dart';

void main() {
  testWidgets('All 8 accents work in light and dark for 11 muscle regions',
      (tester) async {
    expect(AnatomicalGlbStaging.masterRegionNames.length, 11);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final selectedColors = <int>{};
      for (final accent in AppAccent.values) {
        final palette = AppColors.from(
            AppearanceSettings(accent: accent), brightness);
        late Map<String, Color> materials;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            brightness: brightness,
            extensions: [palette],
          ),
          home: Builder(builder: (context) {
            materials = AnatomicalGlbStaging.themeMasterRegions(
              context,
              highlightedRegions: const {
                'pectoralis_major', 'latissimus_dorsi', 'not_a_real_region',
              },
            );
            return const SizedBox.shrink();
          }),
        ));
        final keys=materials.keys.where((k)=>k.startsWith('STK_REGION_'));
        expect(keys.length, 11);
        expect(materials.containsKey('STK_REGION_not_a_real_region'), false);
        expect(materials['STK_BODY'], isNotNull);
        expect(materials['STK_PRIMARY'], palette.primary);
        final selected=materials['STK_REGION_pectoralis_major']!;
        expect(selected, materials['STK_REGION_latissimus_dorsi']);
        expect(selected,
            isNot(materials['STK_REGION_anterior_deltoid']));
        expect(materials['STK_REGION_anterior_deltoid'],
            materials['STK_REGION_hamstrings']);
        selectedColors.add(selected.toARGB32());
      }
      expect(selectedColors.length, 8);
    }
  });
}
