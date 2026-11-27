import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/layout/mobile_content_frame.dart';

const _dock = ValueKey('primary_dock');
const _scroll = ValueKey('secondary_scroll');
const _last = ValueKey('last_action');

Widget _app(double inset, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(top: 24, bottom: inset),
          viewPadding: EdgeInsets.only(top: 24, bottom: inset),
          viewInsets: EdgeInsets.zero,
        ),
        child: MobileContentFrame(child: child!),
      ),
      home: PrimaryTabSafeArea(
        child: Scaffold(
          bottomNavigationBar: const SizedBox(key: _dock, height: 56),
          body: Builder(builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const _SecondaryPage()),
            ),
            child: const Text('Abrir ajustes'),
          )),
        ),
      ),
    );

class _SecondaryPage extends StatelessWidget {
  const _SecondaryPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ajustes')),
    body: ListView(
      key: _scroll,
      padding: SecondaryScreenInsets.scrollPadding(
        context, const EdgeInsets.fromLTRB(16, 8, 16, 12),
      ),
      children: [
        for (var i = 0; i < 20; i++)
          SizedBox(height: 64, child: Text('Opción ${i + 1}')),
        FilledButton(
          key: _last,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

void main() {
  for (final scenario in <(String, double)>[
    ('sin barra', 0), ('gestos Android', 24),
    ('indicador iOS', 34), ('tres botones Android', 48),
  ]) {
    testWidgets('Secondary viewport reaches edge and preserves last action: ${scenario.$1}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final inset = scenario.$2;
      await tester.pumpWidget(_app(inset));
      await tester.pumpAndSettle();
      final dockBefore = tester.getRect(find.byKey(_dock));
      expect(dockBefore.bottom, closeTo(844 - inset, 1));

      await tester.tap(find.text('Abrir ajustes'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_scroll)).bottom, closeTo(844, 1));

      await tester.dragUntilVisible(
        find.byKey(_last), find.byKey(_scroll), const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(
        find.descendant(of: find.byKey(_scroll), matching: find.byType(Scrollable)),
      ).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_last)).bottom,
        lessThanOrEqualTo(844 - inset));
      await tester.tap(find.byKey(_last));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_dock)), dockBefore);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Keyboard padding is not counted twice', (tester) async {
    late EdgeInsets result;
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.only(bottom: 34),
        viewInsets: EdgeInsets.only(bottom: 300),
      ),
      child: Builder(builder: (context) {
        result = SecondaryScreenInsets.scrollPadding(context, const EdgeInsets.all(12));
        return const SizedBox();
      }),
    )));
    expect(result, const EdgeInsets.all(12));
  });

  test('System bars keep gestures transparent and native three-button contrast', () {
    for (final brightness in Brightness.values) {
      final style = MobileSystemBars.style(brightness);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarDividerColor, Colors.transparent);
      expect(style.systemNavigationBarContrastEnforced, isTrue);
      expect(style.systemNavigationBarIconBrightness,
        brightness == Brightness.dark ? Brightness.light : Brightness.dark);
    }
  });
}
