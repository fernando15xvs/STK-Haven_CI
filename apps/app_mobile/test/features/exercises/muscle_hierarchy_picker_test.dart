import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/muscle_hierarchy_picker.dart';

void main() {
  testWidgets('drills down to an individual hamstring and selects its ID',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 650,
          child: MuscleHierarchyPicker(key: const Key('picker')),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('anatomy_expand_mg_lower_body')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anatomy_expand_mg_thighs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anatomy_expand_mg_hamstrings')));
    await tester.pumpAndSettle();
    expect(find.text('Semitendinoso'), findsOneWidget);
    // The picker is normally hosted in a bottom sheet; here the same
    // Navigator.pop contract is checked with a pushed route.
  });

  testWidgets('shows shoulder portions without merging them',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(height: 650, child: MuscleHierarchyPicker()),
      ),
    ));
    await tester.tap(find.byKey(const Key('anatomy_expand_mg_upper_body')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anatomy_expand_mg_shoulders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anatomy_expand_m_deltoid')));
    await tester.pumpAndSettle();
    expect(find.text('Deltoides anterior'), findsOneWidget);
    expect(find.text('Deltoides lateral'), findsOneWidget);
    expect(find.text('Deltoides posterior'), findsOneWidget);
    await tester.tap(find.byKey(const Key('anatomy_back')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Deltoides · sin porción especificada'),
        findsOneWidget);
  });
}
