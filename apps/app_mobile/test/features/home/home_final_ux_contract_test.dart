import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dashboard = File(
    'lib/features/home/presentation/pages/dashboard_page.dart',
  );
  final recovery = File(
    'lib/features/home/presentation/widgets/recovery_check_in_card.dart',
  );

  test('H01-H04 Inicio owns no next-workout hero; preserves completed history', () {
    final source = dashboard.readAsStringSync();
    expect(source, isNot(contains('Icons.bolt')));
    expect(source, contains('if (activeWorkout.isActive)'));
    expect(source, contains('_CompactActiveWorkoutAccess('));
    final shortcut = File(
      'lib/features/home/presentation/widgets/home_training_shortcut.dart',
    ).readAsStringSync();
    expect(source, contains('HomeTrainingShortcut('));
    expect(shortcut, contains("ValueKey('home_continue_workout')"));
    expect(source, contains("ValueKey('home_open_train')"));
    expect(source, contains('widget.onOpenTrain'));
    expect(source, isNot(contains('_TodayRoutineCard(')));
    expect(source, isNot(contains('_ActiveWorkoutHero(')));
    expect(source, isNot(contains('SIGUIENTE SESIÓN')));
    // The existing note editor and today's completion access are preserved
    // below the Activity block instead of another large hero.
    expect(source, contains('_CompletedTodayCard('));
    expect(source, contains("value: 'summary', child: Text('Ver resumen')"));
    expect(source, contains('RecentWorkoutDetails.show(context, session, weightUnit)'));
    expect(source, contains("value: 'notes', child: Text('Editar nota')"));
    expect(source, contains('id: session.id'));
    expect(source, contains('exercises: session.exercises'));
    expect(source, contains('durationSeconds: session.durationSeconds'));
  });

  test('H02-H03 reflection respects faith controls and uses one real navigation', () {
    final s = dashboard.readAsStringSync();
    final a = s.indexOf('class _DailyMessageCard extends ConsumerWidget');
    final b = s.indexOf('class _CompactActiveWorkoutAccess extends StatelessWidget', a);
    expect(a, greaterThan(0));
    expect(b, greaterThan(a));
    final section = s.substring(a, b);
    expect(s, contains('if (faithEnabled && settings.showDailyVerse)'));
    expect(section, contains('maxLines: 2,'));
    expect(section, contains('TextOverflow.ellipsis'));
    expect(section, contains('stateAsync.when('));
    expect(section, contains('loadingCard(providerError: true)'));
    expect(section, contains('ref.invalidate(dailyVerseProvider)'));
    expect(section, contains('const DailyVersePage()'));
    expect(section.split('const DailyVersePage()').length - 1, 1);
    expect(section, isNot(contains("'MENSAJE DE HOY'")));
    expect(section, isNot(contains("const Text('Leer completo')")));
  });

  test('H05-H06 quick check-in has accurate context after completed workout', () {
    final home = dashboard.readAsStringSync();
    final card = recovery.readAsStringSync();
    expect(home, contains('RecoveryCheckInTiming.active'));
    expect(home, contains('RecoveryCheckInTiming.completed'));
    expect(home, contains('RecoveryCheckInTiming.planned'));
    expect(card, contains('Registra cómo te sientes después de entrenar.'));
    expect(card, contains('Revisa cómo te sientes durante tu sesión.'));
    expect(card, contains('Check-in rápido · 20 segundos'));
    expect(card, contains('if (compact) {'));
    expect(card, contains("Text('Recuperación de hoy'"));
    expect(card, contains('checkIn.status.label'));
    expect(card, contains('checkIn.score'));
    // Existing sheet and trends remain reachable and continue writing
    // through the original provider, not a new duplicate data store.
    expect(card, contains('showRecoveryHistorySheet('));
    expect(card, contains('recoveryProvider.notifier'));
    expect(card, contains('await showModalBottomSheet<void>('));
    expect(card, contains("'TENDENCIA RECIENTE'"));
    expect(card, contains("'Energía'"));
    expect(card, contains("'Sueño'"));
    expect(card, contains("'Estrés'"));
    expect(card, contains("'Molestia muscular'"));
  });

  test('H07-H08 wellness remains in Home, no duplicate source or layout', () {
    final s = dashboard.readAsStringSync();
    expect(s.split('HomeWellnessLayout(').length-1, 1);
    expect(s, contains('HydrationWidget('));
    expect(s, contains('DailyStepsWidget('));
    expect(s, contains("ValueKey('home_open_nutrition_plan')"));
    expect(s, contains("'ACTIVIDAD'"));
    expect(s, contains("const SizedBox(height: AppSpacing.lg),\n            Row("));
  });
}
