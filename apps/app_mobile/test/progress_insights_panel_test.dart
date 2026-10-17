import 'package:core/features/progress/application/progress_insight_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_insights_panel.dart';

void main() {
  const first = ProgressInsight(
    id: 'consistency:30D:2026-10-05:3:2',
    type: ProgressInsightType.consistency,
    title: 'Cambio de frecuencia entre semanas',
    explanation: 'Registraste tres días y luego dos.',
    evidence: '3 → 2 días con al menos una serie efectiva.',
    periodLabel: 'Semanas completas · 28/09–11/10',
  );
  const other = ProgressInsight(
    id: 'exercise:30D:bench:a:b',
    type: ProgressInsightType.exercise,
    title: 'Mejora estimada en Press banca',
    explanation: 'El 1RM estimado fue mayor.',
    evidence: '+6.0 % en tres sesiones.',
    periodLabel: 'Período seleccionado · 30D',
  );
  const changedPeriod = ProgressInsight(
    id: 'consistency:90D:2026-10-05:3:2',
    type: ProgressInsightType.consistency,
    title: 'Frecuencia registrada estable',
    explanation: 'La evidencia para otro filtro.',
    evidence: '3 → 3 días.',
    periodLabel: 'Semanas completas · 28/09–11/10',
  );

  Widget app(List<ProgressInsight> insights) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ProgressInsightsPanel(insights: insights),
        ),
      ),
    ),
  );

  testWidgets('320px: discard persists on restart, then restore',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app([first, other]));
    await tester.pumpAndSettle();
    expect(find.text(first.title), findsOneWidget);
    expect(find.text(other.title), findsOneWidget);
    await tester.ensureVisible(find.byKey(ValueKey('dismiss_${first.id}')));
    await tester.tap(find.byKey(ValueKey('dismiss_${first.id}')));
    await tester.pumpAndSettle();
    expect(find.text(first.title), findsNothing);
    expect(find.text(other.title), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app([first, other]));
    await tester.pumpAndSettle();
    expect(find.text(first.title), findsNothing);
    expect(find.text(other.title), findsOneWidget);

    await tester.ensureVisible(
        find.byKey(const ValueKey('restore_progress_insights')));
    await tester.tap(
        find.byKey(const ValueKey('restore_progress_insights')));
    await tester.pumpAndSettle();
    expect(find.text(first.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new evidence/filter appears even when old item dismissed',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'progress_insights.dismissed.v1': [first.id],
    });
    await tester.pumpWidget(app([first]));
    await tester.pumpAndSettle();
    expect(find.text(first.title), findsNothing);
    await tester.pumpWidget(app([changedPeriod]));
    await tester.pumpAndSettle();
    expect(find.text(changedPeriod.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('insufficient history gives a neutral non-diagnostic state',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app(const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('evidencia suficiente'), findsOneWidget);
    expect(find.textContaining('diagnósticos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
