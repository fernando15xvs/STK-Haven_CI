import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_set_record_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/exercise_history_set_row.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('history status requires recorded evidence at '
          '${width.toInt()}px ${brightness.name} text 1.6', (tester) async {
        tester.view.physicalSize = Size(width, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final palette = AppColors.from(
          AppearanceSettings(
            oledBlack: brightness == Brightness.dark,
            accent: AppAccent.emerald,
          ),
          brightness,
        );
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            brightness: brightness,
            extensions: [palette],
            fontFamily: 'Outfit',
          ),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    ExerciseHistorySetRow(
                      set: WorkoutSet(weight: 60, reps: 8, completed: false),
                      weightUnit: WeightUnit.kg,
                    ),
                    ExerciseHistorySetRow(
                      set: WorkoutSet(weight: 60, reps: 8, completed: false),
                      weightUnit: WeightUnit.kg,
                      recordedOutcome: WorkoutSetOutcomeEvidence.skipped,
                    ),
                    ExerciseHistorySetRow(
                      set: WorkoutSet(weight: 60, reps: 8, completed: false),
                      weightUnit: WeightUnit.kg,
                      recordedOutcome: WorkoutSetOutcomeEvidence.failed,
                    ),
                    ExerciseHistorySetRow(
                      set: WorkoutSet(weight: 60, reps: 8, completed: true),
                      weightUnit: WeightUnit.kg,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        for (final item in [
          ('pending', 'Pendiente', palette.textSecondary),
          ('skipped', 'Omitida', palette.warning),
          ('failed', 'Fallida', palette.error),
        ]) {
          final findBadge = find.byKey(ValueKey('history_set_status_${item.$1}'));
          expect(findBadge, findsOneWidget);
          final text = tester.widget<Text>(findBadge);
          expect(text.data, item.$2);
          expect(text.style?.color, item.$3);
          expect(text.style?.fontFamily, 'Outfit');
          expect(
            AppColors.contrast(text.style!.color!, palette.surface),
            greaterThanOrEqualTo(4.5),
          );
          final bounds = tester.getRect(findBadge);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(width));
        }
        expect(find.byKey(
          const ValueKey('history_set_status_completed')), findsNothing);
        expect(find.byKey(
          const ValueKey('history_set_value')), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
