import 'package:core/features/coach_pro/application/coach_pro_nutrition_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_nutrition_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachProNutritionVersionsScreen extends ConsumerWidget {
  final CoachProNutritionQuery query;
  const CoachProNutritionVersionsScreen({super.key, required this.query});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(appBar: AppBar(title: const Text('Versiones de la orientación')),
      body: !identity.signedIn || identity.userId == null
        ? const Center(child: Text('Inicia sesión con una cuenta permanente.'))
        : _Versions(key: ValueKey((identity.userId, query)), query: query));
  }
}
class _Versions extends ConsumerStatefulWidget {
  final CoachProNutritionQuery query;
  const _Versions({super.key, required this.query});
  @override
  ConsumerState<_Versions> createState() => _VersionsState();
}
class _VersionsState extends ConsumerState<_Versions> with WidgetsBindingObserver {
  int _offset = 0;
  CoachProNutritionQuery get _query => (relationshipId: widget.query.relationshipId,
    clientUserId: widget.query.clientUserId, planId: widget.query.planId,
    version: widget.query.version, offset: _offset);
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  void _refresh() => ref.invalidate(coachProNutritionVersionsProvider(_query));
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }
  @override
  Widget build(BuildContext context) {
    final result = ref.watch(coachProNutritionVersionsProvider(_query));
    return SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: result.isLoading ? null : _refresh, icon: const Icon(Icons.refresh), label: const Text('Actualizar'))),
        result.when(skipLoadingOnRefresh: false, skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Column(children: [
            const Text('No se pudo consultar el historial. Comprueba la conexión y los permisos vigentes.'),
            TextButton(onPressed: _refresh, child: const Text('Reintentar')),
          ]),
          data: (page) {
            if (page == null) return const Text('Historial no disponible.');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Elige una versión para consultarla. No modifica la orientación.'),
              if (page.items.isEmpty) Text(_offset == 0 ? 'No hay versiones disponibles.'
                : 'Esta página está vacía. Vuelve a la anterior.'),
              for (final item in page.items)
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title),
                    Text('Versión ${item.version}${item.version == page.currentVersion ? ' · Actual' : ''}'),
                    if (item.version == widget.query.version) const Text('En consulta'),
                    Text(MaterialLocalizations.of(context).formatMediumDate(item.createdAt.toLocal())),
                    TextButton(onPressed: () => Navigator.of(context).pop(item.version),
                      child: Text('Consultar versión ${item.version}')),
                  ]))),
              Text('${page.totalCount} versiones · Página ${_offset ~/ 25 + 1}'),
              Wrap(spacing: 12, runSpacing: 8, children: [
                OutlinedButton(onPressed: _offset > 0 ? () => setState(() => _offset -= 25) : null,
                  child: const Text('Anterior')),
                OutlinedButton(onPressed: page.items.isNotEmpty && _offset + 25 < page.totalCount && _offset + 25 <= 10000
                    ? () => setState(() => _offset += 25) : null, child: const Text('Siguiente')),
              ]),
            ]);
          }),
      ]))));
  }
}
