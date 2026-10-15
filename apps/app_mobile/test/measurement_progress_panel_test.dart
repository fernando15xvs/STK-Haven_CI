import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gym_tracker/features/progress/presentation/pages/measurement_progress_panel.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

void main() {
  testWidgets(
    'small phone displays comparison and configurable calendar cadence',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(_Settings.new)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MeasurementProgressPanel(
                  measurements: [
                    BodyMeasurement(
                      id: 'a',
                      date: DateTime(2026, 1),
                      leftArmCm: 30,
                    ),
                    BodyMeasurement(
                      id: 'b',
                      date: DateTime(2026, 3),
                      leftArmCm: 33,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('30.0 → 33.0 cm'), findsOneWidget);
      expect(find.textContaining('+3.0 cm'), findsOneWidget);
      expect(
        find.textContaining('no confirma ganancia muscular'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(DropdownButton<int>));
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cada 3 meses').last);
      await tester.pumpAndSettle();
      expect(find.text('Cada 3 meses'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
