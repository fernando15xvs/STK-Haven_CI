import 'package:core/core/constants/preset_programs.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/program_preview_modal.dart';
import 'package:gym_tracker/features/workout/presentation/widgets/barbell_calculator_modal.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('barbell calculator has an accessible close button on $width',
      (tester) async {
        tester.view.physicalSize=Size(width,650);
        tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(
          overrides:[settingsProvider.overrideWith(_Settings.new)],
          child: MaterialApp(home:Scaffold(
            body:Builder(builder:(context)=>TextButton(
              onPressed:()=>BarbellCalculatorModal.show(
                context,initialTargetWeight:80),
              child:const Text('Abrir calculadora'),
            )),
          )),
        ));
        await tester.tap(find.text('Abrir calculadora'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('barbell_calculator_close')),findsOneWidget);
        await tester.tap(find.byKey(const Key('barbell_calculator_close')));
        await tester.pumpAndSettle();
        expect(find.byType(BarbellCalculatorModal),findsNothing);
        expect(tester.takeException(),isNull);
      },
    );
  }

  testWidgets('program preview has an accessible close action',
    (tester) async {
      await tester.pumpWidget(ProviderScope(
        child:MaterialApp(home:Scaffold(
          body:Builder(builder:(context)=>TextButton(
            onPressed:()=>showModalBottomSheet<void>(
              context:context,
              isScrollControlled:true,
              builder:(_)=>ProgramPreviewModal(
                program:presetPrograms.first,
                mode:ProgramPreviewMode.preview,
              ),
            ),
            child:const Text('Abrir programa'),
          )),
        )),
      ));
      await tester.tap(find.text('Abrir programa'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('program_preview_close')),findsOneWidget);
      await tester.tap(find.byKey(const Key('program_preview_close')));
      await tester.pumpAndSettle();
      expect(find.byType(ProgramPreviewModal),findsNothing);
      expect(tester.takeException(),isNull);
    },
  );
}
