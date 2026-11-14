import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/muscle_heatmap_grid.dart';

class _Exercises extends ExerciseListNotifier {
  @override
  List<Exercise> build() => [
    Exercise(
      id: 'press',
      name: 'Press banca',
      muscleGroup: 'Pecho',
      secondaryMuscles: ['Tríceps'],
    ),
    Exercise(id: 'squat', name: 'Sentadilla', muscleGroup: 'Piernas'),
  ];
}

class _Routines extends RoutineListNotifier {
  @override
  List<Routine> build() => [];
}

class _History extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() {
    final finished = DateTime.now().subtract(const Duration(days: 2));
    return [
      WorkoutSession(
        id: 'w1',
        routineNameSnapshot: 'Upper',
        startedAt: finished.subtract(const Duration(minutes: 35)),
        finishedAt: finished,
        durationSeconds: 2100,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'press',
            exerciseNameSnapshot: 'Press banca',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(
                weight: 25, reps: 10, completed: true,
                setType: WorkoutSetType.warmup,
              ),
              WorkoutSet(
                weight: 60, reps: 8, completed: true,
                setType: WorkoutSetType.working,
              ),
            ],
          ),
          WorkoutExercise(
            exerciseId: 'retired-exercise',
            exerciseNameSnapshot: 'Ejercicio histórico',
            muscleGroupSnapshot: 'Glúteos e isquios',
            sets: [
              WorkoutSet(
                weight: 20, reps: 10, completed: true,
                setType: WorkoutSetType.working,
              ),
            ],
          ),
        ],
      ),
    ];
  }
}

void main() {
  testWidgets('muscle balance at 320px shows zeros and toggles indirect work',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseListProvider.overrideWith(_Exercises.new),
          routineListProvider.overrideWith(_Routines.new),
          workoutHistoryProvider.overrideWith(_History.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MuscleHeatmapGrid()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Balance muscular'), findsOneWidget);
    // One shared period is exposed through each analytical tab's compact menu.
    expect(find.byType(SegmentedButton<TimeFilter>), findsNothing);
    expect(find.byKey(const ValueKey('muscle_shared_period')), findsOneWidget);
    expect(find.text('1M'), findsOneWidget);
    expect(find.byKey(const ValueKey('muscle_summary')), findsOneWidget);
    final summaryDigits = tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('muscle_summary')),
        matching: find.byType(Text),
      ),
    ).where((value) => int.tryParse(value.data ?? '') != null).toList();
    expect(summaryDigits, hasLength(3));
    for (final text in summaryDigits) {
      expect(text.style?.fontFamily, 'Outfit');
      expect(text.style?.fontFeatures,
          contains(const FontFeature.tabularFigures()));
    }
    expect(find.textContaining('Hay etiquetas antiguas por clasificar'),
        findsOneWidget);
    expect(find.textContaining('Indirecto estimado:'), findsNothing);
    // Only a vertical list remains: no duplicate horizontal filter.
    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('muscle_indirect_toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('muscle_indirect_toggle')));
    await tester.pumpAndSettle();
    // The ambiguous historical row sorts before Pecho; verify it before
    // moving down the lazy list so the test does not scroll past it.
    await tester.scrollUntilVisible(
      find.text('Glúteos e isquios · por clasificar'), -120,
    );
    expect(find.text('Glúteos e isquios · por clasificar'), findsOneWidget);
    await tester.ensureVisible(find.text('Glúteos e isquios · por clasificar'));
    await tester.pumpAndSettle();
    // ListView lazily creates cards below the fold at 320 logical pixels.
    await tester.scrollUntilVisible(find.text('Pecho'), 120);
    await tester.ensureVisible(find.text('Pecho'));
    await tester.pumpAndSettle();
    expect(find.text('Pecho'), findsOneWidget);
    await tester.tap(find.text('Pecho'));
    await tester.pumpAndSettle();
    expect(find.text('Ejercicios que aportaron trabajo directo'), findsWidgets);
    expect(find.text('Press banca'), findsWidgets);
    // Zero-activity catalogue groups are collapsed until explicitly opened.
    expect(find.text('Tríceps'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('muscle_inactive_toggle')), 120);
    await tester.tap(find.byKey(const ValueKey('muscle_inactive_toggle')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tríceps'), 120);
    expect(find.textContaining('Indirecto estimado: 0.5'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Piernas'), 120);
    expect(find.text('Piernas'), findsOneWidget);
    // The shared provider updates the same compact selector and metrics.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MuscleHeatmapGrid)));
    container.read(timeFilterProvider.notifier).setFilter(TimeFilter.week);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('muscle_shared_period')), -200);
    expect(find.text('7D'), findsOneWidget);
    expect(find.byType(SegmentedButton<TimeFilter>), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        testWidgets(
          'muscle week comparison ${width.toInt()}px / ${scale.toStringAsFixed(1)} '
          '/ ${brightness.name} wraps and reads complete dates',
          (tester) async {
            tester.view.physicalSize = Size(width, 850);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final semantics = tester.ensureSemantics();
            try {
              final colors = AppColors.from(
                AppearanceSettings(
                  accent: AppAccent.violet,
                  oledBlack: brightness == Brightness.dark,
                ),
                brightness,
              );
              await tester.pumpWidget(ProviderScope(
                overrides: [
                  exerciseListProvider.overrideWith(_Exercises.new),
                  routineListProvider.overrideWith(_Routines.new),
                  workoutHistoryProvider.overrideWith(_History.new),
                ],
                child: MaterialApp(
                  theme: ThemeData(
                    brightness: brightness,
                    fontFamily: 'Outfit',
                    extensions: [colors],
                  ),
                  home: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: const Scaffold(body: MuscleHeatmapGrid()),
                  ),
                ),
              ));
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                find.byKey(const ValueKey('muscle_week_comparison')),
                140,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              expect(
                find.bySemanticsLabel(RegExp(
                  r'Semana anterior desde el \d{2}/\d{2}/\d{4}\. '
                  r'Semana reciente desde el \d{2}/\d{2}/\d{4}\.',
                )),
                findsOneWidget,
              );
              final dateLabel = tester.widget<Text>(
                find.descendant(
                  of: find.byKey(const ValueKey('muscle_week_comparison')),
                  matching: find.textContaining(' → '),
                ),
              );
              expect(dateLabel.style?.fontFamily, 'Outfit');
              expect(dateLabel.style?.color, colors.textSecondary);
              expect(dateLabel.softWrap, isTrue);
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }

  // The three metrics must not compress into unreadable one-third-width
  // columns at accessibility scales; counts and spoken units stay complete.
  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        testWidgets(
          'muscle KPIs reflow ${width.toInt()}px / ${scale.toStringAsFixed(1)} '
          '/ ${brightness.name} without lost counts',
          (tester) async {
            tester.view.physicalSize = Size(width, 850);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final semantics = tester.ensureSemantics();
            try {
              final colors = AppColors.from(
                AppearanceSettings(
                  accent: AppAccent.rose,
                  oledBlack: brightness == Brightness.dark,
                ),
                brightness,
              );
              await tester.pumpWidget(ProviderScope(
                overrides: [
                  exerciseListProvider.overrideWith(_Exercises.new),
                  routineListProvider.overrideWith(_Routines.new),
                  workoutHistoryProvider.overrideWith(_History.new),
                ],
                child: MaterialApp(
                  theme: ThemeData(
                    brightness: brightness,
                    fontFamily: 'Outfit',
                    extensions: [colors],
                  ),
                  home: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: const Scaffold(body: MuscleHeatmapGrid()),
                  ),
                ),
              ));
              await tester.pumpAndSettle();
              final summary = find.byKey(const ValueKey('muscle_summary'));
              await tester.ensureVisible(summary);
              await tester.pumpAndSettle();
              final totals = [
                find.byKey(const ValueKey('muscle_summary_direct')),
                find.byKey(const ValueKey('muscle_summary_active')),
                find.byKey(const ValueKey('muscle_summary_inactive')),
              ];
              for (final tile in totals) {
                expect(tile, findsOneWidget);
                final size = tester.getSize(tile);
                expect(size.width, greaterThan(0));
                expect(size.width, lessThan(width));
              }
              if (width == 320 && scale == 1.6) {
                // Small viewport + large text needs full-width rows.
                expect(tester.getSize(totals.first).width, greaterThan(200));
                expect(tester.getTopLeft(totals[1]).dy,
                    greaterThan(tester.getTopLeft(totals[0]).dy));
              }
              if (width == 430 && scale == 1.0) {
                // Three columns must fit inside the card padding.
                final firstTop = tester.getTopLeft(totals.first).dy;
                expect(tester.getTopLeft(totals[1]).dy, firstTop);
                expect(tester.getTopLeft(totals[2]).dy, firstTop);
              }
              expect(find.bySemanticsLabel(
                  RegExp(r'^Series directas: \d+$')), findsOneWidget);
              expect(find.bySemanticsLabel(
                  RegExp(r'^Trabajados: \d+$')), findsOneWidget);
              expect(find.bySemanticsLabel(
                  RegExp(r'^Sin actividad: \d+$')), findsOneWidget);
              expect(
                AppColors.contrast(colors.textSecondary, colors.surface),
                greaterThanOrEqualTo(4.5),
              );
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }

}
