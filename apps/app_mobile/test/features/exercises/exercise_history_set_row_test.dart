import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/exercise_history_set_row.dart';

void main() {
  for (final brightness in [Brightness.dark, Brightness.light]) {
    testWidgets('unfinished is Pendiente, never Fallida, in ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final colors = AppColors.from(
        const AppearanceSettings(),
        brightness,
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          extensions: [colors],
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: ExerciseHistorySetRow(
              set: WorkoutSet(weight: 32.5, reps: 8, completed: false),
              weightUnit: WeightUnit.kg,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Fallida'), findsNothing);
      final item = tester.widget<Text>(
        find.byKey(const ValueKey('history_set_value')),
      );
      expect(item.style?.decoration, TextDecoration.none);
      final ctx = tester.element(find.text('Pendiente'));
      final pendingText = tester.widget<Text>(find.text('Pendiente'));
      expect(
        AppColors.contrast(
          pendingText.style!.color!,
          AppColors.of(ctx).surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('completed series is shown without pending or failed badge',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ExerciseHistorySetRow(
          set: WorkoutSet(weight: 40, reps: 8, completed: true),
          weightUnit: WeightUnit.kg,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pendiente'), findsNothing);
    expect(find.text('Fallida'), findsNothing);
    expect(find.byKey(const ValueKey('history_set_value')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long lb weight is not clipped on narrow text-scaled screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: ExerciseHistorySetRow(
            set: WorkoutSet(weight: 122.5, reps: 12, completed: false),
            weightUnit: WeightUnit.lb,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pendiente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final status in ['skipped', 'failed']) {
    testWidgets('recorded $status in history survives visible badge',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ExerciseHistorySetRow(
            set: WorkoutSet(
              weight: 50, reps: 0, completed: false,
              recordedOutcome: status),
            weightUnit: WeightUnit.kg,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final label = status == 'skipped' ? 'Omitida' : 'Fallida';
      expect(find.text(label), findsOneWidget);
      expect(find.text('Pendiente'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

}
