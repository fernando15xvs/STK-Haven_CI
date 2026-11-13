import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/features/profile/presentation/widgets/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared cards are readable with large text and themed colors',
      (tester) async {
    for (final width in <double>[320, 390, 430]) {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      for (final scale in <double>[1, 1.6, 2]) {
        await tester.pumpWidget(MaterialApp(
          theme: AppearanceTheme.build(
            const AppearanceSettings(), Brightness.dark,
          ),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: const ProfileSectionCard(
                    title: 'Preferencias de entrenamiento',
                    children: [
                      ListTile(
                        title: Text('Unidades y progresión'),
                        subtitle: Text('Elige peso, descanso y ajustes para las series, '
                            'incluidos ejercicios unilaterales y recomendaciones.'),
                        trailing: Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
        expect(tester.takeException(), isNull,
            reason: '$width dp and $scale text');
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
