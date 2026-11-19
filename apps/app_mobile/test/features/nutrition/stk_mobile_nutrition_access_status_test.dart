import 'package:core/features/nutrition/application/nutrition_access_state.dart';
import 'package:core/features/nutrition/data/nutrition_adult_access_service.dart';
import 'package:core/features/nutrition/presentation/widgets/stk_mobile_nutrition_access_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget fixture({
    NutritionAccessState access = NutritionAccessState.adultUnverified,
    NutritionAdultCheck check = NutritionAdultCheck.unverified,
    VoidCallback? onRetry,
    double scale = 1,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: StkMobileNutritionAccessPanel(
              access: access,
              check: check,
              onRetry: onRetry,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('denied adult sees no fake verification/retry button',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(fixture(onRetry: () => retries++));
    expect(find.text('Plan calórico pendiente de acceso'), findsOneWidget);
    expect(find.text('Volver a comprobar acceso'), findsNothing);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.textContaining('Food Vision sigue disponible sin cifras'), findsOneWidget);
    await tester.tap(find.byKey(
      const ValueKey('stk_nutrition_access_info'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Los cálculos requieren un permiso activo del servidor'),
        findsOneWidget);
    expect(retries, 0);
  });

  testWidgets('network failure has honest status and a working retry',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(fixture(
      check: NutritionAdultCheck.unavailable,
      onRetry: () => retries++,
    ));
    expect(find.text('No se pudo comprobar el acceso'), findsOneWidget);
    await tester.tap(find.byKey(
      const ValueKey('stk_nutrition_access_retry'),
    ));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('loading cannot display a numeric goal or retry',
      (tester) async {
    await tester.pumpWidget(fixture(
      check: NutritionAdultCheck.checking,
      onRetry: () {},
    ));
    expect(find.text('Comprobando tu plan'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.textContaining('kcal'), findsNothing);
  });

  testWidgets('sign out is distinct from a server denial', (tester) async {
    await tester.pumpWidget(fixture(
      access: NutritionAccessState.ageUnknown,
      check: NutritionAdultCheck.signedOut,
    ));
    expect(find.text('Plan disponible con tu cuenta'), findsOneWidget);
    expect(find.text('Inicia sesión para consultar tu plan.'), findsOneWidget);
  });

  testWidgets('declared minor stays educational even when check errors',
      (tester) async {
    await tester.pumpWidget(fixture(
      access: NutritionAccessState.minor,
      check: NutritionAdultCheck.unavailable,
      onRetry: () {},
    ));
    expect(find.text('Nutrición para tu etapa'), findsOneWidget);
    expect(find.textContaining('sin metas calóricas'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('320 dp, 200 percent text, OLED dark: compact and reachable',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(fixture(
      check: NutritionAdultCheck.unavailable,
      onRetry: () {},
      scale: 2,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final info = find.byKey(const ValueKey('stk_nutrition_access_info'));
    expect(info, findsOneWidget);
    await tester.ensureVisible(info);
    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(find.textContaining('No obtuvimos una respuesta válida'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
