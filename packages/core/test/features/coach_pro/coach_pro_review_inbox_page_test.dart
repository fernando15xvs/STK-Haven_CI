import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/features/coach_pro/application/coach_pro_review_queue_provider.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_review_inbox_page.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Identity extends AppIdentityNotifier {
  @override
  AppIdentityState build() => const AppIdentityState(
    sessionKind: AppSessionKind.permanent,
    userId: 'coach',
  );
  void logout() => state = const AppIdentityState();
}

CoachProClientSummary _client({bool missing = false}) =>
    CoachProClientSummary.fromJson({
      'relationship_id': 'relationship',
      'client_user_id': 'client',
      'display_name': 'Ana Cliente',
      'relationship_status': 'active',
      'permissions': {'view_progress': true},
      'progress_available': !missing,
      'last_workout_at': missing ? null : '2026-09-01T10:00:00Z',
      'needs_review': true,
      'total_count': 1,
    });

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  bool missing = false,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(overrides: [
    appIdentityProvider.overrideWith(_Identity.new),
    coachProReviewQueueProvider((userId: 'coach', offset: 0))
        .overrideWith((ref) async => CoachProReviewQueuePage(
          clients: [_client(missing: missing)],
          totalCount: 1,
        )),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: CoachProReviewInboxPage()),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('responsive review inbox at width $width', (tester) async {
      await _mount(tester, width: width);
      expect(find.text('Ana Cliente'), findsOneWidget);
      expect(find.textContaining('requiere revisión.'), findsWidgets);
      expect(find.text('Abrir ficha'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing snapshot has an honest explanation', (tester) async {
    await _mount(tester, missing: true);
    expect(find.text('No hay una instantánea de progreso disponible.'),
        findsOneWidget);
    expect(find.textContaining('Último entrenamiento compartido:'),
        findsNothing);
  });

  testWidgets('logout instantly redacts previous review data', (tester) async {
    final container = await _mount(tester);
    container.read(appIdentityProvider.notifier);
    (container.read(appIdentityProvider.notifier) as _Identity).logout();
    await tester.pumpAndSettle();
    expect(find.text('Ana Cliente'), findsNothing);
    expect(find.text('Inicia sesión con una cuenta permanente.'),
        findsOneWidget);
  });
}
