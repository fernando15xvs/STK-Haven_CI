import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/home/presentation/widgets/quick_access_menu.dart';

const labels = ['Coach', 'Hábitos', 'La Biblia', 'Haven Faith', 'Nutrición',
  'Motivation', 'Herramientas'];

void main() {
  test('white labels meet WCAG AA even over a pure white underlying pixel', () {
    for (final brightness in Brightness.values) {
      final scrim = QuickAccessMenu.scrimFor(brightness);
      final brightest = Color.alphaBlend(scrim, Colors.white);
      expect(AppColors.contrast(Colors.white, brightest), greaterThanOrEqualTo(4.5));
      for (final accent in AppAccent.values) {
        for (final oled in [false, true]) {
          final palette = AppColors.from(AppearanceSettings(accent: accent, oledBlack: oled), brightness);
          for (final surface in [palette.background, palette.surface, palette.surfaceHigh, palette.primary]) {
            expect(AppColors.contrast(Colors.white, Color.alphaBlend(scrim, surface)),
                greaterThanOrEqualTo(4.5));
          }
          expect(AppColors.contrast(palette.primary, palette.surfaceHigh), greaterThanOrEqualTo(4.5));
        }
      }
    }
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('quick access labels fit at $width dp / $scale text', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = '';
        await tester.pumpWidget(MaterialApp(home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(size: Size(width,800), textScaler: TextScaler.linear(scale)),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal:12), child:
              Align(alignment:Alignment.bottomCenter, child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth:380,maxHeight:560),
                child: QuickAccessMenu(children: [
                  for(final label in labels)
                    QuickAccessOption(icon:Icons.task_alt_outlined,label:label,onTap:()=>opened=label),
                ]),
              )),
            ),
          ),
        )));
        await tester.pumpAndSettle();
        for (final label in labels) {
          final finder = find.byKey(ValueKey('quick_access_label_$label'));
          expect(finder, findsOneWidget);
          final text = tester.widget<Text>(finder);
          expect(text.style!.color, Colors.white);
          expect(text.style!.fontSize, 13);
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          final icon = find.byKey(ValueKey('quick_access_icon_$label'));
          expect(tester.getSize(icon).height, greaterThanOrEqualTo(48));
        }
        // Compare the actual row geometry, not text-box centers: a
        // two-line label has a lower center even when perfectly aligned.
        final columns = scale > 1.85 ? 1 : scale > 1.3 ? 2 : 3;
        double? previousBottom;
        for (var start = 0; start < labels.length; start += columns) {
          final row = labels.skip(start).take(columns);
          final firstIcon = tester.getRect(find.byKey(
            ValueKey('quick_access_icon_${row.first}')));
          final firstText = tester.getRect(find.byKey(
            ValueKey('quick_access_label_${row.first}')));
          if (previousBottom != null) {
            expect(firstIcon.top, greaterThanOrEqualTo(previousBottom + 11));
          }
          var bottom = firstText.bottom;
          double? previousRight;
          for (final label in row) {
            final icon = tester.getRect(find.byKey(
              ValueKey('quick_access_icon_$label')));
            final text = tester.getRect(find.byKey(
              ValueKey('quick_access_label_$label')));
            expect(icon.center.dy, closeTo(firstIcon.center.dy, 1));
            expect(text.top, closeTo(firstText.top, 1));
            expect(text.top - icon.bottom, closeTo(6, 1));
            expect(text.center.dx, closeTo(icon.center.dx, 1));
            if (previousRight != null) {
              expect(icon.left, greaterThan(previousRight));
            }
            previousRight = icon.right;
            if (text.bottom > bottom) bottom = text.bottom;
          }
          previousBottom = bottom;
        }
        await tester.ensureVisible(find.text('Herramientas'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Herramientas'));
        await tester.pumpAndSettle();
        expect(opened, 'Herramientas');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('accent circles and readable labels survive all appearance combinations', (tester) async {
    for (final brightness in Brightness.values) {
      for(final accent in AppAccent.values) {
        for(final oled in brightness == Brightness.dark ? [false,true] : [false]) {
          final colors = AppColors.from(AppearanceSettings(accent:accent,oledBlack:oled),brightness);
          await tester.pumpWidget(MaterialApp(theme:ThemeData(brightness:brightness,extensions:[colors]),
            home:Scaffold(body:Center(child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:380),
              child:QuickAccessMenu(children:[
                QuickAccessOption(icon:Icons.menu_book,label:'La Biblia',onTap:(){}),
              ]),
            )))));
          await tester.pumpAndSettle();
          final label = tester.widget<Text>(find.text('La Biblia'));
          expect(label.style!.color,Colors.white);
          final circle = tester.widget<Container>(find.byKey(const ValueKey('quick_access_icon_La Biblia')));
          expect((circle.decoration! as BoxDecoration).color,colors.surfaceHigh);
          expect(tester.widget<Icon>(find.byIcon(Icons.menu_book)).color,colors.primary);
          expect(tester.takeException(),isNull);
        }
      }
    }
  });
}
