import 'package:core/core/theme/appearance_theme.dart';
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
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    for (final width in <double>[320, 390, 430]) {
      for (final scale in <double>[1, 1.6, 2]) {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            routineListProvider.overrideWith(_Routines.new),
          ],
          child: MaterialApp(
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
        expect(find.text('Crear mi plan'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNWidgets(4));
        expect(tester.takeException(), isNull,
            reason: '$width dp at $scale text');
      }
    }
  });
}
