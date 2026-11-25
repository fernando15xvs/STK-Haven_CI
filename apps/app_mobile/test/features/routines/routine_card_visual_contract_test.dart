import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Entrenar has no fixed Motivation launcher or weekday chips on cards', () {
    final source = File(
      'lib/features/routines/presentation/pages/routines_page.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('MotivationMiniPlayer(')));
    expect(source, isNot(contains('motivation_mini_player.dart')));
    expect(source, contains('final activeProgram = ref.watch(activeTrainingProgramProvider)'));
    expect(source, contains('RoutineCardEvidence.fromHistory('));
    expect(source, contains('muscleGroups.join('));
    expect(source, contains(r"tooltip: 'Iniciar ${routine.name}'"));
    // Optional days remain in the weekly editor, not on each routine card.
    final card = source.split('class _RoutineCard extends StatelessWidget')[1]
        .split('class _EmptyState extends StatelessWidget')[0];
    expect(card, isNot(contains('scheduledDays')));
    expect(card, contains('final labels = InkWell('));
    expect(card, contains('Expanded(child: labels), ...actions'));
    expect(card, contains('LayoutBuilder('));
    expect(card, contains('Icons.play_circle_outline_rounded'));
    expect(card, isNot(contains('Última vez:')));
  });
}
