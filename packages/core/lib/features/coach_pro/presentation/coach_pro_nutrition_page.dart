import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_nutrition_versions_page.dart';
import 'package:core/features/coach_pro/application/coach_pro_nutrition_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_nutrition_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachProNutritionDetailPage extends ConsumerWidget {
  final CoachProNutritionQuery query;
  const CoachProNutritionDetailPage({super.key, required this.query});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(appBar: AppBar(title: const Text('Orientación alimentaria')),
      body: !identity.signedIn || identity.userId == null
        ? const Center(child: Text('Inicia sesión con una cuenta permanente.'))
        : _Detail(key: ValueKey((identity.userId, query)), query: query));
  }
}
class _Detail extends ConsumerStatefulWidget {
  final CoachProNutritionQuery query;
  const _Detail({super.key, required this.query});
  @override
  ConsumerState<_Detail> createState() => _DetailState();
}
class _DetailState extends ConsumerState<_Detail> with WidgetsBindingObserver {
  int _offset = 0;
  late int _version;
  CoachProNutritionQuery get _query => (relationshipId: widget.query.relationshipId,
    clientUserId: widget.query.clientUserId, planId: widget.query.planId,
    version: _version, offset: _offset);
  @override
  void initState() { super.initState(); _version = widget.query.version; WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  void _refresh() => ref.invalidate(coachProNutritionProvider(_query));
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }
  @override
  Widget build(BuildContext context) {
    final result = ref.watch(coachProNutritionProvider(_query));
    return SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: result.isLoading ? null : _refresh, icon: const Icon(Icons.refresh), label: const Text('Actualizar'))),
        result.when(skipLoadingOnRefresh: false, skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Column(children: [
            const Text('No se pudo consultar la orientación. Comprueba la conexión y los permisos vigentes.'),
            TextButton(onPressed: _refresh, child: const Text('Reintentar')),
          ]),
          data: (page) {
            if (page == null) return const Text('Orientación no disponible.');
            final plan = page.plan;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(plan.title, style: Theme.of(context).textTheme.headlineSmall),
              Text('${plan.status == NutritionGuidanceStatus.active ? 'Activa' : 'Archivada'} · Versión ${plan.version} de ${plan.currentVersion}'),
              TextButton(onPressed: () async {
                final selected = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) =>
                  CoachProNutritionVersionsScreen(query: _query)));
                if (!mounted) return;
                if (selected != null) setState(() { _version = selected; _offset = 0; });
                _refresh();
              }, child: const Text('Ver versiones')),
              const Text(NutritionGuidancePlan.defaultScopeNotice),
              if (plan.scopeNotice != NutritionGuidancePlan.defaultScopeNotice) Text(plan.scopeNotice),
              if (plan.overview.isNotEmpty) Text(plan.overview),
              if (plan.hydrationNotes.isNotEmpty) Text('Hidratación: ${plan.hydrationNotes}'),
              if (plan.generalNotes.isNotEmpty) Text(plan.generalNotes),
              if (plan.meals.isEmpty) Text(_offset == 0 ? 'No hay comidas registradas en esta versión.'
                : 'Esta página está vacía. Vuelve a la anterior.'),
              for (final meal in plan.meals)
                Card(child: Padding(padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(meal.name, style: Theme.of(context).textTheme.titleMedium),
                    if (meal.timingLabel.isNotEmpty) Text(meal.timingLabel),
                    if (meal.notes.isNotEmpty) Text(meal.notes),
                    for (final item in meal.items) ...[
                      Text(item.foodExample),
                      if (item.servingNote.isNotEmpty) Text(item.servingNote),
                    ],
                  ]))),
              Text('${page.totalCount} comidas · Página ${_offset ~/ 5 + 1}'),
              Wrap(spacing: 12, runSpacing: 8, children: [
                OutlinedButton(onPressed: _offset > 0 ? () => setState(() => _offset -= 5) : null,
                  child: const Text('Anterior')),
                OutlinedButton(onPressed: plan.meals.isNotEmpty && _offset + 5 < page.totalCount
                    ? () => setState(() => _offset += 5) : null, child: const Text('Siguiente')),
              ]),
            ]);
          }),
      ]))));
  }
}
