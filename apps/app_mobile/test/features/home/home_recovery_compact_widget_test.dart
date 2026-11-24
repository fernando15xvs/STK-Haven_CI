import 'package:gym_tracker/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:core/features/recovery/application/recovery_performance_correlation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/home/presentation/widgets/recovery_check_in_card.dart';

class _RecoveryStub extends RecoveryNotifier {
  _RecoveryStub(this.value);

  final RecoveryCheckIn? value;

  @override
  RecoveryCheckIn? build() => value;
}

void main() {
  final noCorrelation = RecoveryPerformanceInsight(
    points: const [],
    matchedWorkoutDays: 0,
    coefficient: null,
    association: RecoveryPerformanceAssociation.insufficient,
  );

  Widget app({
    required RecoveryCheckInTiming timing,
    required double scale,
    RecoveryCheckIn? checkIn,
    AppAccent accent = AppAccent.blue,
    Brightness brightness = Brightness.dark,
    bool oledBlack = false,
  }) {
    return ProviderScope(
      overrides: [
        recoveryProvider.overrideWith(() => _RecoveryStub(checkIn)),
        recoveryHistoryProvider.overrideWith((ref) => const []),
        recoveryPerformanceProvider.overrideWith((ref) => noCorrelation),
      ],
      child: MaterialApp(
        theme: AppearanceTheme.build(
          AppearanceSettings(accent: accent, oledBlack: oledBlack),
          brightness,
        ),
        home: Scaffold(
          body: SafeArea(
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RecoveryCheckInCard(
                  compact: true,
                  trainingContext: timing,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('empty recovery compact at ${width.toInt()}dp x $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 840);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app(
          timing: RecoveryCheckInTiming.completed,
          scale: scale,
        ));
        await tester.pumpAndSettle();
        expect(find.text('¿Cómo está tu cuerpo hoy?'), findsOneWidget);
        expect(find.text('Registra cómo te sientes después de entrenar.'),
            findsOneWidget);
        expect(find.textContaining('antes de entrenar'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }


  testWidgets('Q03 compact Home recovery has no overflow in 216 configurations',
      (tester) async {
    final realDate = DateTime.now();
    final recorded = RecoveryCheckIn(
      date: DateTime(realDate.year, realDate.month, realDate.day),
      energy: 4, sleep: 3, stress: 2, soreness: 3,
      updatedAt: realDate,
    );
    expect(AppAccent.values.length, 8);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      for (final scale in [1.0, 1.6, 2.0]) {
        for (final scheme in const <(Brightness, bool)>[
          (Brightness.light, false),
          (Brightness.dark, false),
          (Brightness.dark, true),
        ]) {
          for (final accent in AppAccent.values) {
            await tester.pumpWidget(app(
              timing: RecoveryCheckInTiming.completed,
              scale: scale,
              checkIn: recorded,
              brightness: scheme.$1,
              oledBlack: scheme.$2,
              accent: accent,
            ));
            await tester.pump();
            expect(find.text('Recuperación de hoy'), findsOneWidget);
            expect(find.text(
              recorded.status.label + ' · ' +
              recorded.score.toString() + '/100'), findsOneWidget);
            expect(tester.takeException(), isNull,
                reason: 'Compact Home width=' + width.toString() +
                    ' scale=' + scale.toString() +
                    ' theme=' + scheme.$1.toString() +
                    ' oled=' + scheme.$2.toString() +
                    ' accent=' + accent.toString());
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('active and planned recovery hints reflect training state',
      (tester) async {
    await tester.pumpWidget(app(
      timing: RecoveryCheckInTiming.active,
      scale: 1,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Revisa cómo te sientes durante tu sesión.'),
        findsOneWidget);

    await tester.pumpWidget(app(
      timing: RecoveryCheckInTiming.planned,
      scale: 1,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Check-in rápido · 20 segundos'), findsOneWidget);
  });

  testWidgets('completed check-in shows actual score and remains editable',
      (tester) async {
    final now = DateTime.now();
    final recorded = RecoveryCheckIn(
      date: DateTime(now.year, now.month, now.day),
      energy: 4, sleep: 4, stress: 2, soreness: 2,
      updatedAt: now,
    );
    await tester.pumpWidget(app(
      timing: RecoveryCheckInTiming.completed,
      scale: 1,
      checkIn: recorded,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Recuperación de hoy'), findsOneWidget);
    expect(find.text('${recorded.status.label} · ${recorded.score}/100'),
        findsOneWidget);
    expect(find.text('Check-in rápido · 20 segundos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact empty state still opens existing four-question sheet',
      (tester) async {
    await tester.pumpWidget(app(
      timing: RecoveryCheckInTiming.planned,
      scale: 1,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿Cómo está tu cuerpo hoy?'));
    await tester.pumpAndSettle();
    expect(find.text('Check-in de recuperación'), findsOneWidget);
    for (final label in ['Energía', 'Sueño', 'Estrés', 'Molestia muscular']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Guardar check-in'), findsOneWidget);
  });
}
