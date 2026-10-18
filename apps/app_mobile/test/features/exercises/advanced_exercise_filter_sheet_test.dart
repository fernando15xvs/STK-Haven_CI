import 'package:core/core/constants/curated_exercise_catalog.dart';
import 'package:core/features/exercises/application/exercise_library_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/advanced_exercise_filter_sheet.dart';

void main() {
  testWidgets('advanced filters remain usable at 320px and clear safely',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selected = const AdvancedExerciseFilterSelection();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final next = await showModalBottomSheet<
                  AdvancedExerciseFilterSelection>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => FractionallySizedBox(
                  heightFactor: 0.84,
                  child: AdvancedExerciseFilterSheet(
                    initialSelection: selected,
                  ),
                ),
              );
              if (next != null) selected = next;
            },
            child: const Text('Abrir filtros'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Filtros avanzados'), findsOneWidget);

    await tester.tap(find.byKey(const Key('facet_movement')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empuje horizontal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('facet_difficulty')));
    await tester.tap(find.byKey(const Key('facet_difficulty')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Principiante').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('facet_apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('facet_apply')));
    await tester.pumpAndSettle();

    expect(selected.movementCategory,
        ExerciseMovementCategory.horizontalPush);
    expect(selected.difficulty, 'Principiante');
    expect(selected.activeCount, 2);

    await tester.tap(find.text('Abrir filtros'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('facet_clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('facet_clear')));
    await tester.pumpAndSettle();
    expect(selected.movementCategory, isNull);
    expect(selected.difficulty, ExerciseLibraryFilter.allOption);
    expect(selected.activeCount, 0);
    expect(tester.takeException(), isNull);
  });
}
