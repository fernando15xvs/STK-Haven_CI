import 'package:core/features/coach_pro/presentation/coach_pro_client_detail_page.dart';
import 'dart:async';

import 'package:core/features/coach_pro/domain/coach_pro_dashboard_query.dart';

import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/domain/models/coach_pro_portfolio_overview.dart';
import 'package:core/domain/models/coach_relationship.dart';
import 'package:core/domain/models/subscription_entitlement.dart';
import 'package:core/features/coach_pro/application/coach_pro_dashboard_provider.dart';
import 'package:core/features/coach_pro/application/coach_pro_entitlement_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A session-keyed display snapshot, never an authorization grant.
final coachProDashboardPlanProvider =
    FutureProvider.autoDispose.family<SubscriptionEntitlement?, String>(
  (ref, userId) {
    final identity = ref.watch(appIdentityProvider);
    if (!identity.signedIn || identity.userId != userId) return null;
    return ref.watch(coachProEntitlementServiceProvider).getOwnEntitlement();
  },
);

/// Independent from the paginated client list and scoped to the signed-in user.
final coachProPortfolioOverviewProvider =
    FutureProvider.autoDispose.family<CoachProPortfolioOverview?, String>(
  (ref, userId) {
    final identity = ref.watch(appIdentityProvider);
    if (!identity.signedIn || identity.userId != userId) return null;
    return ref.watch(coachProDashboardServiceProvider).getPortfolioOverview();
  },
);

class CoachProDashboardPage extends ConsumerWidget {
  const CoachProDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Coach Pro')),
      body: SafeArea(
        child: !identity.signedIn || identity.userId == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Inicia sesión con una cuenta permanente desde Perfil '
                    'para consultar tu cartera profesional.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _Dashboard(
                key: ValueKey(identity.userId), userId: identity.userId!),
      ),
    );
  }
}

class _Dashboard extends ConsumerStatefulWidget {
  final String userId;
  const _Dashboard({super.key, required this.userId});
  @override
  ConsumerState<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<_Dashboard>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    _debounce?.cancel();
    ref.invalidate(coachProDashboardPlanProvider(widget.userId));
    ref.invalidate(coachProPortfolioOverviewProvider(widget.userId));
    final notifier = ref.read(coachProDashboardProvider.notifier);
    if (_search.text.trim() != ref.read(coachProDashboardProvider).search) {
      await notifier.search(_search.text);
    } else {
      await notifier.refresh();
    }
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    // Count code points as the server does; maxLength counts graphemes in Flutter.
    if (value.trim().runes.length > 80) return;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        unawaited(ref.read(coachProDashboardProvider.notifier).search(value));
      }
    });
  }

  Future<void> _openClient(String relationshipId) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CoachProClientDetailPage(relationshipId: relationshipId),
    ));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coachProDashboardProvider);
    final plan = ref.watch(coachProDashboardPlanProvider(widget.userId));
    final overview = ref.watch(coachProPortfolioOverviewProvider(widget.userId));
    final loading = state.status == CoachProDashboardStatus.loading;
    return LayoutBuilder(builder: (context, constraints) {
      final table = constraints.maxWidth >= 1000 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Cartera profesional',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text('Cada cliente decide qué información comparte.'),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: plan.when(
                          skipLoadingOnRefresh: false,
                          loading: () => const Text('Consultando tu plan…'),
                          error: (_, _) => const Text(
                              'No se pudo consultar el plan. Actualiza para reintentar.'),
                          data: (value) => Text(value == null
                              ? 'No tienes un plan Coach Pro disponible.'
                              : 'Plan: ${_planStatus(value.status)} · '
                                  '${value.activeClientCount}/${value.clientLimit} clientes activos'
                                  '${value.accessActive ? '' : ' · Acceso no disponible'}'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Resumen global de cartera',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            overview.when(
                              skipLoadingOnRefresh: false,
                              loading: () => const Text('Consultando resumen global…'),
                              error: (_, _) => const Text(
                                'Resumen no disponible. Actualiza para volver a comprobar tus permisos.'),
                              data: (value) => value == null
                                  ? const Text('Resumen no disponible sin cuenta permanente.')
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Clientes: ${value.totalClients} · '
                                            'Activos: ${value.activeClients} · '
                                            'Pausados: ${value.pausedClients}'),
                                        Text('Requieren revisión: ${value.clientsRequiringReview} · '
                                            'Progreso compartido: ${value.clientsWithSharedProgress}'),
                                        Text('Tareas activas visibles: ${value.visibleActiveTasks} · '
                                            'Clientes con tareas: ${value.clientsWithTaskBacklog}'),
                                        Text('Clientes con check-in reciente: ${value.clientsWithRecentCheckins}'),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Cifras de toda la cartera. Tareas, check-ins y '
                                          'progreso incluyen solo relaciones activas con '
                                          'permiso; no representan información oculta.',
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      maxLength: 80,
                      inputFormatters: [TextInputFormatter.withFunction(
                        (oldValue, newValue) => newValue.text.trim().runes.length <= 80
                            ? newValue : oldValue,
                      )],
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        labelText: 'Buscar cliente',
                        prefixIcon: Icon(Icons.search),
                        helperText: 'Solo busca en tus clientes vinculados.',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _searchChanged,
                      onSubmitted: _searchChanged,
                    ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 250,
                          child: DropdownButtonFormField<CoachProClientStatusFilter>(
                            key: ValueKey('status-${state.clientStatus.name}'),
                            initialValue: state.clientStatus,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Estado'),
                            items: const [
                              DropdownMenuItem(value: CoachProClientStatusFilter.all,
                                  child: Text('Activos y pausados', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: CoachProClientStatusFilter.active,
                                  child: Text('Activos', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: CoachProClientStatusFilter.paused,
                                  child: Text('Pausados', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (value) {
                              if (value != null) unawaited(ref.read(
                                coachProDashboardProvider.notifier,
                              ).setFilters(clientStatus: value));
                            },
                          ),
                        ),
                        SizedBox(
                          width: 250,
                          child: DropdownButtonFormField<CoachProClientSort>(
                            key: ValueKey('sort-${state.sort.name}'),
                            initialValue: state.sort,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Ordenar por'),
                            items: const [
                              DropdownMenuItem(value: CoachProClientSort.review,
                                  child: Text('Requiere revisión', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: CoachProClientSort.name,
                                  child: Text('Nombre', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: CoachProClientSort.recentWorkout,
                                  child: Text('Último entreno', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: CoachProClientSort.adherence,
                                  child: Text('Adherencia (menor primero)', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (value) {
                              if (value != null) unawaited(ref.read(
                                coachProDashboardProvider.notifier,
                              ).setFilters(sort: value));
                            },
                          ),
                        ),
                        FilterChip(
                          label: const Text('Solo requiere revisión'),
                          selected: state.onlyNeedsReview,
                          onSelected: (value) => unawaited(ref.read(
                            coachProDashboardProvider.notifier,
                          ).setFilters(onlyNeedsReview: value)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Revisión y último entreno usan progreso compartido. Adherencia requiere también permiso para programas; sin datos autorizados aparece al final.'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(state.totalCount == null
                            ? 'Página ${state.offset ~/ 25 + 1}'
                            : '${state.totalCount} resultados'),
                        TextButton.icon(
                          onPressed: loading ? null : _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualizar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ))
                    else if (state.status == CoachProDashboardStatus.error)
                      _Message(
                        text: '${state.message}\nSi estás sin conexión, '
                            'reconéctate para comprobar los permisos vigentes.',
                        action: _refresh,
                      )
                    else if (state.clients.isEmpty)
                      _Message(text: state.offset > 0
                          ? 'Esta página ya no tiene clientes. Vuelve a la anterior.'
                          : state.clientStatus != CoachProClientStatusFilter.all || state.onlyNeedsReview
                              ? 'No hay clientes que coincidan con los filtros.'
                              : state.search.isEmpty
                              ? 'Tu cartera todavía no tiene clientes activos o pausados.'
                              : 'No hay clientes que coincidan con la búsqueda.')
                    else if (table)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Cliente')),
                            DataColumn(label: Text('Estado')),
                            DataColumn(label: Text('Entrenos 7d')),
                            DataColumn(label: Text('Último entreno')),
                            DataColumn(label: Text('Check-in')),
                            DataColumn(label: Text('Tareas activas')),
                          ],
                          rows: [for (final client in state.clients)
                            DataRow(cells: [
                              DataCell(SizedBox(width: 200, child: TextButton(
                                onPressed: () => _openClient(client.relationshipId),
                                child: Text(_name(client), maxLines: 2,
                                  overflow: TextOverflow.ellipsis)))),
                              DataCell(Text(_status(client))),
                              for (final metric in _metrics(context, client))
                                DataCell(Text(metric.$2)),
                            ]),
                          ],
                        ),
                      )
                    else
                      for (final client in state.clients)
                        Card(child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_name(client), style: Theme.of(context)
                                  .textTheme.titleMedium),
                              TextButton(
                                onPressed: () => _openClient(client.relationshipId),
                                child: const Text('Abrir ficha')),
                              const SizedBox(height: 4),
                              Text(_status(client)),
                              const SizedBox(height: 12),
                              for (final metric in _metrics(context, client))
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Text('${metric.$1}: ${metric.$2}'),
                                ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: state.hasPrevious
                              ? ref.read(coachProDashboardProvider.notifier).previousPage
                              : null,
                          child: const Text('Anterior'),
                        ),
                        Text('Página ${state.offset ~/ 25 + 1}'),
                        OutlinedButton(
                          onPressed: state.hasNext
                              ? ref.read(coachProDashboardProvider.notifier).nextPage
                              : null,
                          child: const Text('Siguiente'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? action;
  const _Message({required this.text, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(children: [
      Text(text, textAlign: TextAlign.center),
      if (action != null) TextButton(onPressed: action,
          child: const Text('Reintentar')),
    ]),
  );
}

String _name(CoachProClientSummary client) =>
    client.displayName.trim().isEmpty ? 'Cliente' : client.displayName;

bool _allows(CoachProClientSummary client, CoachPermission permission) =>
    client.relationshipStatus == CoachRelationshipStatus.active &&
    client.permissions.contains(permission);

String _status(CoachProClientSummary client) =>
    client.relationshipStatus == CoachRelationshipStatus.paused
        ? 'Pausado'
        : _allows(client, CoachPermission.viewProgress) && client.needsReview
            ? 'Requiere revisión'
            : 'Activo';

List<(String, String)> _metrics(BuildContext context, CoachProClientSummary c) {
  String date(DateTime? value) => value == null ? 'Sin datos'
      : MaterialLocalizations.of(context).formatCompactDate(value.toLocal());
  String protected(CoachPermission permission, String value) =>
      _allows(c, permission) ? value : 'No compartido';
  return [
    ('Entrenos 7d', protected(CoachPermission.viewProgress,
        c.workouts7d?.toString() ?? 'Sin datos')),
    ('Último entreno', protected(CoachPermission.viewProgress, date(c.lastWorkoutAt))),
    ('Check-in', protected(CoachPermission.viewCheckins, date(c.latestCheckinAt))),
    ('Tareas activas', protected(CoachPermission.assignTasks,
        c.activeTaskCount?.toString() ?? 'Sin datos')),
  ];
}

String _planStatus(SubscriptionEntitlementStatus value) => switch (value) {
  SubscriptionEntitlementStatus.trial => 'Prueba',
  SubscriptionEntitlementStatus.active => 'Activo',
  SubscriptionEntitlementStatus.grace => 'Período de gracia',
  SubscriptionEntitlementStatus.pastDue => 'Pago pendiente',
  SubscriptionEntitlementStatus.canceled => 'Cancelado',
  SubscriptionEntitlementStatus.expired => 'Vencido',
};
