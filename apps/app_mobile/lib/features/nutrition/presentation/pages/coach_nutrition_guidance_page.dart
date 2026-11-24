import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/nutrition/application/nutrition_guidance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachNutritionGuidancePage extends ConsumerStatefulWidget {
  final String clientUserId;
  final String clientDisplayName;
  final bool canEdit;
  const CoachNutritionGuidancePage({super.key, required this.clientUserId, required this.clientDisplayName, required this.canEdit});
  @override
  ConsumerState<CoachNutritionGuidancePage> createState() => _CoachNutritionGuidancePageState();
}

class _CoachNutritionGuidancePageState extends ConsumerState<CoachNutritionGuidancePage> {
  bool _loaded = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nutritionGuidanceProvider);
    final userId = ref.watch(appIdentityProvider).userId;
    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(nutritionGuidanceProvider.notifier).refresh();
      });
    }
    final plans = state.summaries.where((p) => p.clientUserId == widget.clientUserId).toList(growable: false);
    ref.listen(nutritionGuidanceProvider, (previous, next) {
      if (next.message == null || next.message == previous?.message) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.message!)));
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Orientación alimentaria')),
      floatingActionButton: widget.canEdit ? FloatingActionButton.extended(
        onPressed: state.busy ? null : () => _edit(null),
        icon: const Icon(Icons.add_rounded), label: const Text('Nueva guía'),
      ) : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(nutritionGuidanceProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            Text(widget.clientDisplayName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(NutritionGuidancePlan.defaultScopeNotice),
            const SizedBox(height: 20),
            if (state.operation == NutritionGuidanceOperation.loading && plans.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (plans.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Todavía no hay orientaciones alimentarias.')))
            else
              for (final summary in plans)
                Card(child: ListTile(
                  leading: const Icon(Icons.restaurant_menu_rounded),
                  title: Text(summary.title),
                  subtitle: Text('Versión ${summary.currentVersion} · ${summary.status == NutritionGuidanceStatus.active ? 'Activa' : 'Archivada'}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _open(summary.id, userId),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _open(String id, String? userId) async {
    final plan = await ref.read(nutritionGuidanceProvider.notifier).open(id);
    if (!mounted || plan == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _NutritionGuidanceDetail(
      plan: plan,
      editable: widget.canEdit && plan.coachUserId == userId,
      onEdit: () => _edit(plan),
      onVersion: (version) async {
        final historical = await ref.read(nutritionGuidanceProvider.notifier).open(plan.id, version: version);
        if (!mounted || historical == null) return;
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _NutritionGuidanceDetail(plan: historical, editable: false)));
      },
    )));
  }

  Future<void> _edit(NutritionGuidancePlan? plan) async {
    final draft = await Navigator.of(context).push<_GuidanceDraft>(MaterialPageRoute(builder: (_) => _NutritionGuidanceEditor(initial: plan)));
    if (!mounted || draft == null) return;
    final id = await ref.read(nutritionGuidanceProvider.notifier).save(
      clientUserId: widget.clientUserId, planId: plan?.id, title: draft.title,
      overview: draft.overview, hydrationNotes: draft.hydration, generalNotes: draft.notes, meals: draft.meals,
    );
    if (!mounted || id == null) return;
    if (plan != null) Navigator.of(context).pop();
  }
}

class _NutritionGuidanceDetail extends StatelessWidget {
  final NutritionGuidancePlan plan;
  final bool editable;
  final VoidCallback? onEdit;
  final Future<void> Function(int version)? onVersion;
  const _NutritionGuidanceDetail({required this.plan, required this.editable, this.onEdit, this.onVersion});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(plan.title), actions: [
      if (editable && onEdit != null) IconButton(tooltip: 'Crear nueva versión', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
    ]),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      children: [
        Text(plan.scopeNotice, style: Theme.of(context).textTheme.bodySmall),
        if (plan.overview.isNotEmpty) ...[const SizedBox(height: 16), Text(plan.overview)],
        if (plan.hydrationNotes.isNotEmpty) ...[const SizedBox(height: 16), _InfoCard(title: 'Hidratación', text: plan.hydrationNotes)],
        for (final meal in plan.meals) ...[
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meal.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (meal.timingLabel.isNotEmpty) Text(meal.timingLabel),
              if (meal.notes.isNotEmpty) ...[const SizedBox(height: 6), Text(meal.notes)],
              for (final item in meal.items) ListTile(
                contentPadding: EdgeInsets.zero, dense: true,
                leading: const Icon(Icons.circle, size: 8), title: Text(item.foodExample),
                subtitle: item.servingNote.isEmpty ? null : Text(item.servingNote),
              ),
            ],
          ))),
        ],
        if (plan.generalNotes.isNotEmpty) ...[const SizedBox(height: 12), _InfoCard(title: 'Notas generales', text: plan.generalNotes)],
        if (plan.currentVersion > 1 && onVersion != null) ...[
          const SizedBox(height: 20),
          Text('Historial de versiones', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (var v = plan.currentVersion; v >= 1; v--) ActionChip(label: Text('v$v'), onPressed: v == plan.version ? null : () => onVersion!(v)),
          ]),
        ],
      ],
    ),
  );
}

class _NutritionGuidanceEditor extends StatefulWidget {
  final NutritionGuidancePlan? initial;
  const _NutritionGuidanceEditor({this.initial});
  @override
  State<_NutritionGuidanceEditor> createState() => _NutritionGuidanceEditorState();
}

class _NutritionGuidanceEditorState extends State<_NutritionGuidanceEditor> {
  late final TextEditingController title, overview, hydration, notes;
  late List<_MealDraft> meals;
  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    title = TextEditingController(text: p?.title ?? '');
    overview = TextEditingController(text: p?.overview ?? '');
    hydration = TextEditingController(text: p?.hydrationNotes ?? '');
    notes = TextEditingController(text: p?.generalNotes ?? '');
    meals = [for (final meal in p?.meals ?? const <NutritionGuidanceMeal>[]) _MealDraft.fromModel(meal)];
  }
  @override
  void dispose() {
    title.dispose(); overview.dispose(); hydration.dispose(); notes.dispose();
    for (final meal in meals) meal.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.initial == null ? 'Nueva guía' : 'Nueva versión'), actions: [TextButton(onPressed: _save, child: const Text('Guardar'))]),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), children: [
      const Text(NutritionGuidancePlan.defaultScopeNotice),
      const SizedBox(height: 16),
      TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
      const SizedBox(height: 12),
      TextField(controller: overview, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción general')),
      const SizedBox(height: 12),
      TextField(controller: hydration, maxLines: 2, decoration: const InputDecoration(labelText: 'Hidratación')),
      const SizedBox(height: 12),
      TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notas generales')),
      const SizedBox(height: 20),
      Text('Comidas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      for (var i = 0; i < meals.length; i++) _MealEditor(
        key: ValueKey(meals[i]), draft: meals[i],
        onRemove: () => setState(() { final removed = meals.removeAt(i); removed.dispose(); }),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: meals.length >= 20 ? null : () => setState(() => meals.add(_MealDraft())),
        icon: const Icon(Icons.add_rounded), label: const Text('Añadir comida'),
      ),
    ]),
  );

  void _save() {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Añade un título.')));
      return;
    }
    final models = <NutritionGuidanceMeal>[];
    for (var i = 0; i < meals.length; i++) {
      final m = meals[i];
      if (m.name.text.trim().isEmpty) continue;
      models.add(NutritionGuidanceMeal(
        position: i, name: m.name.text, timingLabel: m.timing.text, notes: m.notes.text,
        items: [for (var j = 0; j < m.items.length; j++) if (m.items[j].food.text.trim().isNotEmpty)
          NutritionGuidanceItem(position: j, foodExample: m.items[j].food.text, servingNote: m.items[j].serving.text)],
      ));
    }
    Navigator.of(context).pop(_GuidanceDraft(
      title: title.text, overview: overview.text, hydration: hydration.text, notes: notes.text, meals: models,
    ));
  }
}

class _MealEditor extends StatefulWidget {
  final _MealDraft draft;
  final VoidCallback onRemove;
  const _MealEditor({super.key, required this.draft, required this.onRemove});
  @override
  State<_MealEditor> createState() => _MealEditorState();
}
class _MealEditorState extends State<_MealEditor> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Card(margin: const EdgeInsets.only(top: 12), child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: d.name, decoration: const InputDecoration(labelText: 'Comida'))),
          IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline)),
        ]),
        TextField(controller: d.timing, decoration: const InputDecoration(labelText: 'Horario opcional')),
        TextField(controller: d.notes, decoration: const InputDecoration(labelText: 'Notas')),
        for (var i = 0; i < d.items.length; i++) Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(children: [
              TextField(controller: d.items[i].food, decoration: const InputDecoration(labelText: 'Alimento / ejemplo')),
              TextField(controller: d.items[i].serving, decoration: const InputDecoration(labelText: 'Porción / nota')),
            ])),
            IconButton(onPressed: () => setState(() { final removed = d.items.removeAt(i); removed.dispose(); }), icon: const Icon(Icons.remove_circle_outline)),
          ]),
        ),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: d.items.length >= 50 ? null : () => setState(() => d.items.add(_ItemDraft())),
          icon: const Icon(Icons.add_rounded), label: const Text('Añadir alimento'),
        )),
      ]),
    ));
  }
}

class _MealDraft {
  final TextEditingController name, timing, notes;
  final List<_ItemDraft> items;
  _MealDraft() : name = TextEditingController(), timing = TextEditingController(), notes = TextEditingController(), items = <_ItemDraft>[];
  _MealDraft.fromModel(NutritionGuidanceMeal meal)
      : name = TextEditingController(text: meal.name), timing = TextEditingController(text: meal.timingLabel),
        notes = TextEditingController(text: meal.notes), items = [for (final item in meal.items) _ItemDraft.fromModel(item)];
  void dispose() { name.dispose(); timing.dispose(); notes.dispose(); for (final item in items) item.dispose(); }
}
class _ItemDraft {
  final TextEditingController food, serving;
  _ItemDraft() : food = TextEditingController(), serving = TextEditingController();
  _ItemDraft.fromModel(NutritionGuidanceItem item) : food = TextEditingController(text: item.foodExample), serving = TextEditingController(text: item.servingNote);
  void dispose() { food.dispose(); serving.dispose(); }
}
class _GuidanceDraft {
  final String title, overview, hydration, notes;
  final List<NutritionGuidanceMeal> meals;
  const _GuidanceDraft({required this.title, required this.overview, required this.hydration, required this.notes, required this.meals});
}
class _InfoCard extends StatelessWidget {
  final String title, text;
  const _InfoCard({required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(text),
    ]),
  ));
}
