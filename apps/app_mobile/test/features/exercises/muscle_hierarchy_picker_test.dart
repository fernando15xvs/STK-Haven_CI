import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/muscle_hierarchy_picker.dart';

void main() {
  testWidgets('drills down to an individual hamstring and selects its ID',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              selected = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const SizedBox(
                  height: 620,
                  child: MuscleHierarchyPicker(),
                ),
              );
            },
            child: const Text('Abrir anatomía'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir anatomía'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anatomy_expand_mg_lower_body')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anatomy_expand_mg_thighs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anatomy_expand_mg_hamstrings')));
    await tester.pumpAndSettle();
    expect(find.text('Semitendinoso'), findsOneWidget);
    await tester.tap(find.byKey(const Key('anatomy_select_m_semitendinosus')));
    await tester.pumpAndSettle();
    expect(selected, 'm_semitendinosus');
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
