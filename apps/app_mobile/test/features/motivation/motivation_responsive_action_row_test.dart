import 'dart:io';

import 'package:gym_tracker/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/motivation/presentation/widgets/motivation_responsive_action_row.dart';

void main() {
  testWidgets('Motivation actions stay reachable across themes and text scales',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in <double>[320,390,430]) {
      tester.view.physicalSize=Size(width,900);
      tester.view.devicePixelRatio=1;
      for (final scale in <double>[1,1.6,2]) {
        for (final variant in <(Brightness,bool)>[
          (Brightness.light,false),
          (Brightness.dark,false),
          (Brightness.dark,true),
        ]) {
          for (final accent in AppAccent.values) {
            await tester.pumpWidget(MaterialApp(
              theme:AppearanceTheme.build(
                AppearanceSettings(accent:accent,oledBlack:variant.$2),
                variant.$1),
              home:MediaQuery(
                data:MediaQueryData(textScaler:TextScaler.linear(scale)),
                child:Scaffold(body:SingleChildScrollView(
                  child:Padding(
                    padding:const EdgeInsets.all(16),
                    child:Column(children:[
                      MotivationResponsiveActionRow(
                        leading:DropdownButtonFormField<String>(
                          isExpanded:true,
                          initialValue:'discipline',
                          decoration:const InputDecoration(labelText:'Modo'),
                          items:const [
                            DropdownMenuItem(value:'discipline',
                              child:Text('Disciplina')),
                            DropdownMenuItem(value:'rest',
                              child:Text('Descanso')),
                          ],
                          onChanged:(_){},
                        ),
                        action:FilledButton.icon(
                          key:const ValueKey('motivation_import_inline'),
                          onPressed:(){},
                          icon:const Icon(Icons.add),
                          label:const Text('Importar')),
                        compactAction:FilledButton(
                          key:const ValueKey('motivation_import_compact'),
                          onPressed:(){},
                          child:const Text('Importar')),
                      ),
                      MotivationResponsiveActionRow(
                        leading:Text('Colecciones',
                          style:AppTypography.headlineMedium),
                        action:TextButton.icon(
                          onPressed:(){},
                          icon:const Icon(Icons.auto_awesome_outlined),
                          label:const Text('Ideas de listas')),
                        compactAction:TextButton(
                          onPressed:(){},
                          child:const Text('Ideas de listas')),
                      ),
                      MotivationResponsiveActionRow(
                        leading:Text('Archivos (182)',
                          style:AppTypography.headlineMedium),
                        action:TextButton.icon(
                          onPressed:(){},
                          icon:const Icon(Icons.add),
                          label:const Text('Crear lista')),
                        compactAction:TextButton(
                          onPressed:(){},
                          child:const Text('Crear lista')),
                      ),
                    ]),
                  ),
                )),
              ),
            ));
            await tester.pump();
            final compact=width-32<360 || scale>=1.5;
            expect(find.byKey(ValueKey(compact
              ?'motivation_action_row_stacked'
              :'motivation_action_row_inline')),findsNWidgets(3));
            expect(find.text('Importar'),findsOneWidget);
            expect(find.text('Ideas de listas'),findsOneWidget);
            expect(find.text('Crear lista'),findsOneWidget);
            expect(find.byKey(const ValueKey('motivation_import_compact')),
              compact?findsOneWidget:findsNothing);
            expect(find.byKey(const ValueKey('motivation_import_inline')),
              compact?findsNothing:findsOneWidget);
            final layoutError=tester.takeException();
            expect(layoutError,isNull,
              reason:'width=$width scale=$scale '
                'brightness=${variant.$1} oled=${variant.$2} accent=$accent'
                '\n${layoutError?.toString()}');
          }
        }
      }
    }
  });

  test('M1 library uses one accessible action row, not three duplicate actions', () {
    final page = File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(page, contains("ValueKey('motivation_responsive_import')"));
    expect(page, contains("ValueKey('motivation_create_playlist')"));
    expect(page, contains("ValueKey('motivation_create_playlist_compact')"));
    expect(page, contains("ValueKey('motivation_playlist_actions')"));
    expect(page, contains("ValueKey('motivation_secondary_filters')"));
    expect(page, contains("ValueKey('motivation_playlist_wrap_actions')"));
    expect(page, contains('MotivationResponsiveActionRow('));
    expect(page.split('MotivationResponsiveActionRow(').length-1, 1);
    expect(page.split('compactAction:').length-1, 1);
    expect(page, contains("label: const Text('Importar')"));
    expect(page, contains("label: const Text('Crear lista')"));
    expect(page, contains('Modo de importación'));
    expect(page, isNot(contains('motivation_responsive_collections')));
    expect(page, isNot(contains('motivation_responsive_files')));
  });

}
