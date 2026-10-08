import 'package:core/features/coach_pro/application/coach_pro_review_queue_provider.dart';
import 'package:core/features/coach_pro/domain/coach_pro_review_reason.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_client_detail_page.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachProReviewInboxPage extends ConsumerWidget {
  const CoachProReviewInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bandeja de revisión')),
      body: !identity.signedIn || identity.userId == null
          ? const Center(child: Text('Inicia sesión con una cuenta permanente.'))
          : _Inbox(key: ValueKey(identity.userId), userId: identity.userId!),
    );
  }
}

class _Inbox extends ConsumerStatefulWidget {
  final String userId;
  const _Inbox({super.key, required this.userId});

  @override
  ConsumerState<_Inbox> createState() => _InboxState();
}

class _InboxState extends ConsumerState<_Inbox> with WidgetsBindingObserver {
  int _offset = 0;

  CoachProReviewQueueQuery get _query =>
      (userId: widget.userId, offset: _offset);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }

  void _refresh() => ref.invalidate(coachProReviewQueueProvider(_query));

  Future<void> _openClient(String relationshipId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachProClientDetailPage(
          relationshipId: relationshipId,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(coachProReviewQueueProvider(_query));
    return SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text('Clientes que requieren revisión',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Esta bandeja usa progreso compartido y la regla '
                'de siete días calculada en el servidor. Si faltan datos, '
                'no significa que el cliente esté inactivo.'),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
              onPressed: result.isLoading ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            )),
            result.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Column(children: [
                const Text('No se pudo consultar la bandeja. Comprueba '
                    'tu conexión y permisos vigentes.'),
                TextButton(onPressed: _refresh,
                    child: const Text('Reintentar')),
              ]),
              data: (page) {
                if (page == null) {
                  return const Text('Bandeja no disponible.');
                }
                if (page.clients.isEmpty && _offset == 0) {
                  return const Text('No hay clientes que requieran revisión '
                      'según los datos de progreso compartidos.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final client in page.clients)
                      Card(child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(client.displayName.trim().isEmpty
                                ? 'Cliente' : client.displayName,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(coachProReviewReason(client)!.description),
                            if (client.progressAvailable &&
                                client.lastWorkoutAt != null)
                              Text('Último entrenamiento compartido: ' +
                                  MaterialLocalizations.of(context)
                                      .formatMediumDate(client.lastWorkoutAt!.toLocal())),
                            TextButton(
                              onPressed: () => _openClient(client.relationshipId),
                              child: const Text('Abrir ficha'),
                            ),
                          ],
                        ),
                      )),
                    const SizedBox(height: 12),
                    Text(page.totalCount == null ? 'Sin resultados en esta página.'
                        : 'Clientes por revisar: ' + page.totalCount.toString()),
                    Wrap(spacing: 8, children: [
                      OutlinedButton(
                        onPressed: _offset == 0 ? null
                            : () => setState(() => _offset -= 25),
                        child: const Text('Anterior')),
                      OutlinedButton(
                        onPressed: page.hasMoreAt(_offset)
                            ? () => setState(() => _offset += 25) : null,
                        child: const Text('Siguiente')),
                    ]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    )));
  }
}
