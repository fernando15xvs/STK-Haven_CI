import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/routines/presentation/widgets/routine_weekday_selector.dart';

void main() {
  testWidgets('weekday selector fits 320/390/430 dp at 100/160/200% text', (tester) async {
    for (final width in <double>[320, 390, 430]) {
      for (final scale in <double>[1, 1.6, 2]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width - 32,
                  child: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: RoutineWeekdaySelector(
                      selectedDays: const {1, 3, 5},
                      onDayTapped: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(RoutineWeekdaySelector), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$width dp / $scale text');
      }
    }
  });

  testWidgets('weekday selected state and tap remain accessible', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 288,
        child: RoutineWeekdaySelector(
          selectedDays: const {1, 3},
          onDayTapped: tapped.add,
        ),
      )),
    ));
    final monday = tester.widget<Semantics>(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Lunes').first,
    );
    expect(monday.properties.selected, isTrue);
    await tester.tap(find.text('L'));
    expect(tapped, [1]);
  });
}
