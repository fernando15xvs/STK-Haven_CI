import 'package:core/features/coach_pro/application/coach_pro_client_detail_provider.dart';
import 'package:core/features/coach_pro/domain/coach_pro_dashboard_query.dart';
import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/domain/models/coach_pro_portfolio_overview.dart';
import 'package:core/domain/models/subscription_entitlement.dart';
import 'package:core/features/coach_pro/application/coach_pro_dashboard_provider.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_dashboard_page.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Identity extends AppIdentityNotifier {
  @override
  AppIdentityState build() => const AppIdentityState(
    sessionKind: AppSessionKind.permanent, userId: 'coach',
  );
  void signOutForTest() => state = const AppIdentityState();
}

class _Roster extends CoachProDashboardNotifier {
  final CoachProDashboardState initial;
  int searches = 0;
  int nextPages = 0;
  int refreshes = 0;
  String? query;
  CoachProClientStatusFilter? statusFilter;
  CoachProClientSort? selectedSort;
  bool? reviewFilter;
  _Roster(this.initial);
  @override
  CoachProDashboardState build() => initial;
  @override
  Future<void> search(String value) async { searches++; query = value; }
  @override
  Future<void> nextPage() async { nextPages++; }
  @override
  Future<void> setFilters({CoachProClientStatusFilter? clientStatus,
      bool? onlyNeedsReview, CoachProClientSort? sort}) async {
    statusFilter = clientStatus ?? statusFilter;
    selectedSort = sort ?? selectedSort;
    reviewFilter = onlyNeedsReview ?? reviewFilter;
  }
  @override
  Future<void> refresh() async { refreshes++; }
}

CoachProClientSummary _client({bool permitted = false}) =>
    CoachProClientSummary.fromJson({
      'relationship_id': 'relationship',
      'client_user_id': 'client',
      'display_name': 'Ana Cliente',
      'relationship_status': 'active',
      'permissions': {'view_progress': permitted},
      'workouts_7d': 99,
      'active_task_count': 99,
      'total_count': 50,
    });

Future<ProviderContainer> _mount(WidgetTester tester, _Roster roster, {
  double width = 390, double scale = 1,
  SubscriptionEntitlement? plan,
  CoachProPortfolioOverview? overview,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    appIdentityProvider.overrideWith(_Identity.new),
    coachProClientDetailProvider.overrideWith((ref, query) async => null),
    coachProDashboardProvider.overrideWith(() => roster),
    coachProDashboardPlanProvider('coach').overrideWith((ref) async => plan),
    coachProPortfolioOverviewProvider('coach').overrideWith(
      (ref) async => overview,
    ),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const CoachProDashboardPage(),
    ),
  ));
  await tester.pump();
  return container;
}

void main() {
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('responsive roster at $width hides unpermitted aggregates', (tester) async {
      final roster = _Roster(CoachProDashboardState(
        status: CoachProDashboardStatus.ready,
        clients: [_client()], totalCount: 50,
      ));
      await _mount(tester, roster, width: width);
      expect(find.text('Ana Cliente'), findsOneWidget);
      expect(find.byType(DataTable), width >= 1000 ? findsOneWidget : findsNothing);
      expect(find.textContaining('No compartido'), findsNWidgets(4));
      expect(find.textContaining('99'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large text remains usable on a narrow screen', (tester) async {
    await _mount(tester, _Roster(CoachProDashboardState(
      status: CoachProDashboardStatus.ready, clients: [_client()], totalCount: 1,
    )), width: 320, scale: 1.8);
    await tester.ensureVisible(find.text('Siguiente'));
    await tester.pump();
    expect(find.byType(DataTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('debounced search and pagination call the paginated controller', (tester) async {
    final roster = _Roster(CoachProDashboardState(
      status: CoachProDashboardStatus.ready, clients: [_client()], totalCount: 50,
    ));
    await _mount(tester, roster);
    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pump(const Duration(milliseconds: 349));
    expect(roster.searches, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(roster.searches, 1);
    expect(roster.query, 'Ana');
    await tester.ensureVisible(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Siguiente').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    expect(roster.nextPages, 1);
  });

  testWidgets('filter controls send server query changes', (tester) async {
    final roster = _Roster(const CoachProDashboardState(
      status: CoachProDashboardStatus.ready, totalCount: 0,
    ));
    await _mount(tester, roster);
    await tester.tap(find.text('Activos y pausados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pausados').last);
    await tester.pumpAndSettle();
    expect(roster.statusFilter, CoachProClientStatusFilter.paused);
    await tester.tap(find.text('Requiere revisión').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nombre').last);
    await tester.pumpAndSettle();
    expect(roster.selectedSort, CoachProClientSort.name);
    await tester.tap(find.text('Nombre').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adherencia (menor primero)').last);
    await tester.pumpAndSettle();
    expect(roster.selectedSort, CoachProClientSort.adherence);
    await tester.tap(find.text('Solo requiere revisión'));
    expect(roster.reviewFilter, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens targeted Pro detail from a roster card', (tester) async {
    final roster = _Roster(CoachProDashboardState(
      status: CoachProDashboardStatus.ready, clients: [_client()], totalCount: 1,
    ));
    await _mount(tester, roster);
    await tester.ensureVisible(find.text('Abrir ficha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir ficha'));
    await tester.pumpAndSettle();
    expect(find.text('Ficha Coach Pro'), findsOneWidget);
    expect(find.text('La relación no está disponible.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(roster.refreshes, 1);
  });

  testWidgets('loading never renders client rows or enables pagination', (tester) async {
    await _mount(tester, _Roster(const CoachProDashboardState(
      status: CoachProDashboardStatus.loading,
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Ana Cliente'), findsNothing);
    final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Siguiente'));
    expect(button.onPressed, isNull);
  });

  testWidgets('offline/error explains retry and empty search has a distinct message', (tester) async {
    final roster = _Roster(const CoachProDashboardState(
      status: CoachProDashboardStatus.error,
      message: 'No se pudo cargar la cartera.',
    ));
    await _mount(tester, roster);
    expect(find.textContaining('sin conexión'), findsOneWidget);
    await tester.ensureVisible(find.text('Reintentar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reintentar'));
    expect(roster.refreshes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await _mount(tester, _Roster(const CoachProDashboardState(
      status: CoachProDashboardStatus.ready, search: 'Nadie', totalCount: 0,
    )));
    expect(find.text('No hay clientes que coincidan con la búsqueda.'), findsOneWidget);
  });

  testWidgets('plan state is visible separately and does not fabricate permissions', (tester) async {
    await _mount(tester, _Roster(CoachProDashboardState(
      status: CoachProDashboardStatus.ready, clients: [_client()], totalCount: 1,
    )), plan: SubscriptionEntitlement(
      product: SubscriptionProduct.coachPro,
      status: SubscriptionEntitlementStatus.grace,
      tier: 'test', clientLimit: 10, activeClientCount: 1,
      accessActive: true, fetchedAt: DateTime.utc(2026, 10, 2),
    ));
    expect(find.textContaining('Período de gracia'), findsOneWidget);
    expect(find.textContaining('1/10 clientes activos'), findsOneWidget);
    expect(find.textContaining('No compartido'), findsNWidgets(4));
  });

  testWidgets('global overview does not infer totals from roster page', (tester) async {
    await _mount(tester, _Roster(CoachProDashboardState(
      status: CoachProDashboardStatus.ready,
      clients: [_client()], totalCount: 1,
    )), overview: const CoachProPortfolioOverview(
      totalClients: 40, activeClients: 37, pausedClients: 3,
      clientsWithSharedProgress: 11, clientsRequiringReview: 6,
      visibleActiveTasks: 17, clientsWithTaskBacklog: 9,
      clientsWithRecentCheckins: 8,
    ));
    await tester.pump();
    expect(find.text('Resumen global de cartera'), findsOneWidget);
    expect(find.textContaining('Clientes: 40 · Activos: 37'), findsOneWidget);
    expect(find.textContaining('Tareas activas visibles: 17'), findsOneWidget);
    expect(find.textContaining('check-in reciente: 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-out removes roster, plan and pending search', (tester) async {
    final roster = _Roster(CoachProDashboardState(
      status: CoachProDashboardStatus.ready, clients: [_client()], totalCount: 1,
    ));
    final container = await _mount(tester, roster);
    await tester.enterText(find.byType(TextField), 'Ana');
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ana Cliente'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('cuenta permanente'), findsOneWidget);
    expect(roster.searches, 0);
  });

  testWidgets('partial permissions expose only permitted metrics', (tester) async {
    await _mount(tester, _Roster(CoachProDashboardState(
      status: CoachProDashboardStatus.ready,
      clients: [_client(permitted: true)], totalCount: 1,
    )));
    expect(find.text('Entrenos 7d: 99'), findsOneWidget);
    expect(find.text('Tareas activas: No compartido'), findsOneWidget);
    expect(find.text('Check-in: No compartido'), findsOneWidget);
  });

  testWidgets('expired plan is explicit without pretending an empty roster', (tester) async {
    await _mount(tester, _Roster(const CoachProDashboardState(
      status: CoachProDashboardStatus.error,
      message: 'No se pudo cargar la cartera.',
    )), plan: SubscriptionEntitlement(
      product: SubscriptionProduct.coachPro,
      status: SubscriptionEntitlementStatus.expired,
      tier: 'test', clientLimit: 10, activeClientCount: 1,
      accessActive: false, fetchedAt: DateTime.utc(2026, 10, 2),
    ));
    expect(find.textContaining('Plan: Vencido'), findsOneWidget);
    expect(find.textContaining('Acceso no disponible'), findsOneWidget);
    expect(find.text('Tu cartera todavía no tiene clientes activos o pausados.'),
        findsNothing);
  });
}
