import 'package:gym_tracker/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/routines/presentation/widgets/quick_training_plan_sheet.dart';

class _Routines extends RoutineListNotifier {
  @override
  List<Routine> build() => [
    for (var index = 0; index < 4; index++)
      Routine(
        id: 'r$index',
        name: 'Rutina $index',
        scheduledDays: const [],
        exercises: const [],
        createdAt: DateTime(2026, 11, 13),
      ),
  ];
}

void main() {
  testWidgets('simple plan creator fits 320/390/430dp and 1.0/1.6/2.0 scales',
      (tester) async {
    for (final width in <double>[320, 390, 430]) {
      for (final scale in <double>[1, 1.6, 2]) {
        // Each viewport needs its own scroll offset and a fresh screen.
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            routineListProvider.overrideWith(_Routines.new),
          ],
          child: MaterialApp(
            key: ValueKey('quick_plan_$width-$scale'),
            theme: AppearanceTheme.build(
              const AppearanceSettings(), Brightness.dark,
            ),
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 720),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: QuickTrainingPlanSheet(scrollController: scroll),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Crear mi plan'), findsOneWidget);
        // ListView lazily mounts only visible elements. Inspect the actual
        // children of its SliverChildListDelegate so offscreen saved routines
        // count without assuming all four are simultaneously mounted.
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.childrenDelegate, isA<SliverChildListDelegate>());
        final children =
            (listView.childrenDelegate as SliverChildListDelegate).children;
        final tiles = children.whereType<CheckboxListTile>().toList();
        expect(tiles, hasLength(4));
        for (var index = 0; index < tiles.length; index++) {
          expect((tiles[index].title! as Text).data, 'Rutina $index');
          expect(tiles[index].value, isTrue);
        }
        // The real controller reaches the end, keeping creation accessible
        // at both normal and large text scales.
        expect(scroll.hasClients, isTrue);
        if (scroll.position.maxScrollExtent > 0) {
          final end = scroll.position.maxScrollExtent;
          scroll.jumpTo(end);
          await tester.pump();
          expect(scroll.position.pixels, closeTo(end, 0.1));
        }
        // The submit action is present in the list even when Flutter
        // recycles its offscreen element after a jump.
        expect(
          children.any(
            (child) => child.key == const Key('quick_plan_create'),
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull,
            reason: '$width dp at $scale text');
      }
    }
  });
}
