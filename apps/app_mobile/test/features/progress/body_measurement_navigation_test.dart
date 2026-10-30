import 'package:core/domain/models/body_measurement.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/pages/body_measurement_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

class _FakeMeasurements extends BodyMeasurementNotifier {
  @override
  List<BodyMeasurement> build() => [
    BodyMeasurement(
      id:'2026-10-28', date:DateTime(2026,10,28),
      weightKg:85, chestCm:110, waistCm:82,
      shouldersCm:120,leftArmCm:41,rightArmCm:40.5,
      hipsCm:104,leftLegCm:62,rightLegCm:62,calvesCm:36,
    ),
  ];

  @override
  Future<String?> saveMeasurement(BodyMeasurement value) async {
    state = [value,...state.where((m)=>m.id!=value.id)];
    return null;
  }

  @override
  Future<String?> deleteMeasurement(String id) async {
    state = state.where((m)=>m.id!=id).toList();
    return null;
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsProvider.overrideWith(_Settings.new),
      bodyMeasurementProvider.overrideWith(_FakeMeasurements.new),
    ],
    child: const MaterialApp(home: BodyMeasurementPage()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('es'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0,390.0]) {
    testWidgets('measurement main screen has one anatomy map, header actions, no duplicate blocks ($width)',
      (tester) async {
        tester.view.physicalSize=Size(width,850);
        tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _open(tester);
        expect(find.byKey(const Key('measurement_add_button')),findsOneWidget);
        expect(find.byKey(const Key('measurement_history_button')),findsOneWidget);
        expect(find.byKey(const Key('silhouette_front')),findsOneWidget);
        expect(find.text('Evolución de tus medidas'),findsNothing);
        expect(find.text('Recordar nuevas medidas'),findsNothing);
        expect(find.text('Peso: 85.0 kg'),findsNothing);
        expect(find.byType(FloatingActionButton),findsNothing);
        expect(tester.takeException(),isNull);
      },
    );
  }

  testWidgets('new measurement modal has fixed close, cancel, save, and reminder',
    (tester) async {
      tester.view.physicalSize=const Size(390,850);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester);
      await tester.tap(find.byKey(const Key('measurement_add_button')));
      await tester.pumpAndSettle();
      expect(find.text('Nueva medida'),findsWidgets);
      expect(find.byKey(const Key('measurement_modal_close')),findsOneWidget);
      expect(find.byKey(const Key('measurement_modal_cancel')),findsOneWidget);
      expect(find.byKey(const Key('measurement_modal_save')),findsOneWidget);
      expect(find.text('Guardar'),findsOneWidget);
      expect(find.byKey(const Key('measurement_modal_scroll')),findsOneWidget);
      // Close must work without scrolling to the bottom of an 11-field form.
      await tester.tap(find.byKey(const Key('measurement_modal_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('measurement_modal_close')),findsNothing);
      await tester.tap(find.byKey(const Key('measurement_add_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('measurement_modal_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('measurement_modal_close')),findsNothing);
      expect(tester.takeException(),isNull);
    },
  );

  testWidgets('measurement sheet remains dismissible when keyboard is open',
    (tester) async {
      tester.view.physicalSize=const Size(390,850);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await _open(tester);
      await tester.tap(find.byKey(const Key('measurement_add_button')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 310);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('measurement_modal_close')),findsOneWidget);
      expect(find.byKey(const Key('measurement_modal_save')),findsOneWidget);
      await tester.tap(find.byKey(const Key('measurement_modal_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('measurement_modal_close')),findsNothing);
      expect(tester.takeException(),isNull);
    },
  );

  testWidgets('entering height alone saves and updates summary without modifying weight',
    (tester) async {
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester);
      await tester.tap(find.byKey(const Key('measurement_add_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Altura'), '178',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('measurement_modal_save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('measurement_modal_close')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('summary_height')));
      await tester.pumpAndSettle();
      expect(find.text('178.0 cm'), findsOneWidget);
      expect(find.text('85.0 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('history is separate, edit and delete stay accessible',
    (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const Key('measurement_history_button')));
      await tester.pumpAndSettle();
      expect(find.text('Historial de registros'),findsOneWidget);
      expect(find.byKey(const ValueKey('measurement_record_2026-10-28')),findsOneWidget);
      expect(find.byTooltip('Editar registro'),findsOneWidget);
      expect(find.byTooltip('Eliminar registro'),findsOneWidget);
      await tester.tap(find.byKey(const Key('measurement_history_close')));
      await tester.pumpAndSettle();
      expect(find.text('Historial de registros'),findsNothing);
      expect(tester.takeException(),isNull);
    },
  );
}
