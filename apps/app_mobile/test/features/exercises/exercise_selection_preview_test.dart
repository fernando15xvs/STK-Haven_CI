import 'package:core/core/constants/preset_exercises.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/application/providers/exercise_favorites_provider.dart';
import 'package:core/features/exercises/application/providers/exercise_provider.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_library_page.dart';

class _Exercises extends ExerciseListNotifier {
  @override
  List<Exercise> build() => [
        presetExercises.firstWhere((e) => e.id == 'ex_bench_press'),
      ];
}

class _MultipleExercises extends ExerciseListNotifier {
  @override
  List<Exercise> build() => [
    presetExercises.firstWhere((e) => e.id == 'ex_bench_press'),
    presetExercises.firstWhere((e) => e.id == 'ex_barbell_row'),
  ];
}

class _Favorites extends ExerciseFavoriteIdsNotifier {
  @override
  Set<String> build() => {};
}

class _History extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() => [];
}

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState(reduceMotion: true);
}

void main() {
  testWidgets('exercise selection requires preview confirmation at 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Exercise? selected;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        exerciseListProvider.overrideWith(_Exercises.new),
        exerciseFavoriteIdsProvider.overrideWith(_Favorites.new),
        workoutHistoryProvider.overrideWith(_History.new),
        settingsProvider.overrideWith(_Settings.new),
      ],
      child: MaterialApp(
        home: Builder(builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                selected = await Navigator.of(context).push<Exercise>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const ExerciseLibraryPage(isSelectionMode: true),
                  ),
                );
              },
              child: const Text('Seleccionar'),
            ),
          ),
        )),
      ),
    ));

    await tester.tap(find.text('Seleccionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Press de Banca'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise_selection_preview')), findsOneWidget);
    expect(find.byKey(const Key('exercise_media_fallback')), findsOneWidget);
    expect(selected, isNull);

    await tester.tap(find.byKey(const Key('exercise_preview_cancel')));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('Press de Banca'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exercise_preview_add')));
    await tester.pumpAndSettle();
    expect(selected?.id, 'ex_bench_press');
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact filters stay off the catalogue and multi-select returns a list',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    List<Exercise>? selected;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        exerciseListProvider.overrideWith(_MultipleExercises.new),
        exerciseFavoriteIdsProvider.overrideWith(_Favorites.new),
        workoutHistoryProvider.overrideWith(_History.new),
        settingsProvider.overrideWith(_Settings.new),
      ],
      child: MaterialApp(home: Builder(builder: (context) => Scaffold(
        body: Center(child: ElevatedButton(
          onPressed: () async {
            selected = await Navigator.of(context).push<List<Exercise>>(
              MaterialPageRoute(builder: (_) => const ExerciseLibraryPage(
                isSelectionMode: true, allowMultiple: true)),
            );
          }, child: const Text('Abrir biblioteca'),
        )),
      ))),
    ));
    await tester.tap(find.text('Abrir biblioteca'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library_equipment')), findsNothing);
    await tester.tap(find.byKey(const Key('open_advanced_exercise_filters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library_equipment')), findsOneWidget);
    await tester.tap(find.byKey(const Key('facet_apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library_equipment')), findsNothing);
    for (final id in ['ex_bench_press', 'ex_barbell_row']) {
      final item = find.byKey(ValueKey('library_exercise_$id'));
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exercise_preview_add')));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    }
    await tester.tap(find.byKey(const Key('library_confirm_multiple')));
    await tester.pumpAndSettle();
    expect(selected?.map((e) => e.id), ['ex_bench_press', 'ex_barbell_row']);
    expect(tester.takeException(), isNull);
  });

}
