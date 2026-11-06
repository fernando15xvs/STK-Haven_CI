import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/exercise_history_set_row.dart';

void main() {
  for (final accent in AppAccent.values) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final oled in brightness == Brightness.dark
          ? [false, true] : [false]) {
        testWidgets(
          'DES-04 / DES-07: ${accent.name} / ${brightness.name} / OLED=$oled '
          'keeps all four set outcomes readable at 320px, 160%',
          (tester) async {
            tester.view.physicalSize = const Size(320, 850);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            final colors = AppColors.from(
              AppearanceSettings(accent: accent, oledBlack: oled),
              brightness,
            );
            for (final color in [
              colors.textPrimary,
              colors.textSecondary,
              colors.primary,
              colors.warning,
              colors.error,
            ]) {
              expect(
                AppColors.contrast(color, colors.surface),
                greaterThanOrEqualTo(4.5),
                reason: 'Info text must retain WCAG 4.5:1 contrast',
              );
            }
            await tester.pumpWidget(MaterialApp(
              theme: ThemeData(
                brightness: brightness,
                fontFamily: 'Outfit',
                extensions: [colors],
              ),
              home: MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(1.6),
                ),
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: const [
                        ExerciseHistorySetRow(
                          set: WorkoutSet(
                            weight: 60, reps: 10, completed: true),
                          weightUnit: WeightUnit.kg,
                        ),
                        ExerciseHistorySetRow(
                          set: WorkoutSet(
                            weight: 60, reps: 10, completed: false),
                          weightUnit: WeightUnit.kg,
                        ),
                        ExerciseHistorySetRow(
                          set: WorkoutSet(
                            weight: 60, reps: 0, completed: false,
                            recordedOutcome: 'skipped'),
                          weightUnit: WeightUnit.kg,
                        ),
                        ExerciseHistorySetRow(
                          set: WorkoutSet(
                            weight: 60, reps: 0, completed: false,
                            recordedOutcome: 'failed'),
                          weightUnit: WeightUnit.kg,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ));
            await tester.pumpAndSettle();
            expect(find.text('Pendiente'), findsOneWidget);
            expect(find.text('Omitida'), findsOneWidget);
            expect(find.text('Fallida'), findsOneWidget);
            expect(find.byKey(const ValueKey('history_set_value')),
                findsNWidgets(4));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
