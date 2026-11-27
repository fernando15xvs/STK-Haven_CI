import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme/components/action_navigation_group.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('grouped action wraps at 320dp and 200% text in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(body: SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ActionNavigationGroup(children: [
            ActionNavigationTile(
              key: const ValueKey('enabled_action'),
              icon: Icons.calendar_month_outlined,
              title: 'Tengo menos días disponibles',
              subtitle: 'Ajustar solamente esta semana',
              onTap: () => taps++,
            ),
            const ActionNavigationTile(
              key: ValueKey('disabled_action'),
              icon: Icons.pause_circle_outline,
              title: 'Pausar programa',
              onTap: null,
            ),
          ]),
        ))),
      ));
      final enabled = find.byKey(const ValueKey('enabled_action'));
      final disabled = find.byKey(const ValueKey('disabled_action'));
      expect(tester.getSize(enabled).height, greaterThanOrEqualTo(48));
      expect(find.descendant(of: enabled, matching: find.byIcon(Icons.chevron_right)),
          findsOneWidget);
      await tester.tap(enabled);
      await tester.pumpAndSettle();
      expect(taps, 1);
      await tester.tap(disabled);
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
