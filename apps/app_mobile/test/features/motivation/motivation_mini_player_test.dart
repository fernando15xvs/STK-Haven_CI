import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/presentation/widgets/motivation_mini_player.dart';

void main() {
  testWidgets('Mini player without selected media remains hidden by default',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MotivationMiniPlayer())),
    );
    expect(find.byKey(const ValueKey('motivation_mini_player_hidden')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('motivation_mini_player_toggle')),
        findsNothing);
  });

  testWidgets('Entrenar shows nonblocking entry when no track is playing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            Text('Descanso 01:30'),
            MotivationMiniPlayer(showLauncherWhenEmpty: true),
            Expanded(child: Center(child: Text('Registrar series'))),
          ]),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('motivation_mini_player_launcher')),
        findsOneWidget);
    expect(find.text('Registrar series'), findsOneWidget);
    expect(find.text('Descanso 01:30'), findsOneWidget);
    expect(find.text('STK Motivation'), findsOneWidget);
  });
}
