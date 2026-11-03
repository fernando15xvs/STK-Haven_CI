import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/home/presentation/widgets/weekly_activity_card.dart';

void main() {
  WorkoutSession session(String id, DateTime date) => WorkoutSession(
        id: id,
        routineId: 'routine-1',
        routineNameSnapshot: 'Rutina',
        startedAt: date,
        finishedAt: date.add(const Duration(minutes: 40)),
        durationSeconds: 2400,
        exercises: const [],
      );

  for (final brightness in [Brightness.dark, Brightness.light]) {
    testWidgets('Home has activity and a link, not duplicate statistics: ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = 0;
      final colors = AppColors.from(
        const AppearanceSettings(),
        brightness,
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness, extensions: [colors]),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.6),
              ),
              child: WeeklyActivityCard(
                history: [
                  session('this-week', DateTime(2026, 11, 2, 10)),
                  session('previous-week', DateTime(2026, 10, 26, 10)),
                ],
                referenceDate: DateTime(2026, 11, 3, 12),
                onOpenProgress: () => opened++,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('ESTA SEMANA'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      for (final duplicate in ['ENTRENOS', 'SERIES', 'TIEMPO', 'VOLUMEN']) {
        expect(find.text(duplicate), findsNothing);
      }
      final button = find.byKey(const ValueKey('home_open_progress'));
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.tap(button);
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty week retains direct access to Progreso',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WeeklyActivityCard(
          history: const [],
          referenceDate: DateTime(2026, 11, 3, 12),
          onOpenProgress: () => opened = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.tap(find.text('Ver análisis en Progreso'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
