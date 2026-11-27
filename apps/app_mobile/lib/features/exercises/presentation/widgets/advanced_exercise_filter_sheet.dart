import 'package:core/core/constants/curated_exercise_catalog.dart';
import 'package:core/features/exercises/application/exercise_library_filter.dart';
import 'package:flutter/material.dart';

import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'muscle_hierarchy_picker.dart';

export 'package:core/features/exercises/application/exercise_library_filter.dart'
    show AdvancedExerciseFilterSelection;

class AdvancedExerciseFilterSheet extends StatefulWidget {
  const AdvancedExerciseFilterSheet({
    super.key,
    required this.initialSelection,
    this.equipmentOptions,
  });

  final AdvancedExerciseFilterSelection initialSelection;
  final List<String>? equipmentOptions;

  @override
  State<AdvancedExerciseFilterSheet> createState() =>
      _AdvancedExerciseFilterSheetState();
}

class _AdvancedExerciseFilterSheetState
    extends State<AdvancedExerciseFilterSheet> {
  late ExerciseMovementCategory? _movement;
  late ExerciseMechanics? _mechanics;
  late String _difficulty;
  late bool _bodyweightOnly;
  late String _equipment;
  late ExerciseLateralityFilter _laterality;
  String? _anatomyId;
  late bool _customOnly;
  late bool _includeSecondary;
  bool get _unified => widget.equipmentOptions != null;

  @override
  void initState() {
    super.initState();
    _load(widget.initialSelection);
  }

  void _load(AdvancedExerciseFilterSelection selection) {
    _movement = selection.movementCategory;
    _mechanics = selection.mechanics;
    _difficulty = selection.difficulty;
    _bodyweightOnly = selection.bodyweightOnly;
    _equipment = widget.equipmentOptions == null || widget.equipmentOptions!.contains(selection.equipment)
        ? selection.equipment : ExerciseLibraryFilter.allOption;
    _laterality = selection.laterality;
    _anatomyId = selection.anatomyId;
    _customOnly = selection.customOnly;
    _includeSecondary = selection.includeSecondary;
  }

  Future<void> _chooseAnatomy() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85, child: MuscleHierarchyPicker(),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _anatomyId = result.isEmpty ? null : result);
  }

  AdvancedExerciseFilterSelection get _selection =>
      AdvancedExerciseFilterSelection(
        equipment: _equipment, laterality: _laterality,
        anatomyId: _anatomyId, movementCategory: _movement,
        mechanics: _mechanics, difficulty: _difficulty,
        bodyweightOnly: !_unified && _bodyweightOnly, customOnly: _customOnly,
        includeSecondary: _includeSecondary,
      );

  @override
  Widget build(BuildContext context) {
    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                Text(_unified ? 'Filtros' : 'Filtros avanzados',
                    style: Theme.of(context).textTheme.titleLarge),
                if (_unified) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('library_equipment'),
                    isExpanded: true,
                    initialValue: widget.equipmentOptions!.contains(_equipment)
                        ? _equipment : ExerciseLibraryFilter.allOption,
                    decoration: const InputDecoration(labelText: 'Equipo',
                        border: OutlineInputBorder(), isDense: true),
                    items: [
                      for (final item in widget.equipmentOptions!)
                        DropdownMenuItem(value: item, child: Text(item,
                            overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (value) => setState(() =>
                        _equipment = value ?? ExerciseLibraryFilter.allOption),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ExerciseLateralityFilter>(
                    key: const Key('library_laterality'),
                    isExpanded: true, initialValue: _laterality,
                    decoration: const InputDecoration(labelText: 'Ejecución',
                        border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: ExerciseLateralityFilter.all,
                          child: Text('Todos')),
                      DropdownMenuItem(value: ExerciseLateralityFilter.unilateral,
                          child: Text('Unilateral')),
                      DropdownMenuItem(value: ExerciseLateralityFilter.bilateral,
                          child: Text('Bilateral')),
                      DropdownMenuItem(value: ExerciseLateralityFilter.unspecified,
                          child: Text('No especificada')),
                    ],
                    onChanged: (value) => setState(() =>
                        _laterality = value ?? ExerciseLateralityFilter.all),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('anatomy_picker_open'),
                    onPressed: _chooseAnatomy,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: Text(_anatomyId == null
                        ? 'Explorar músculos por región'
                        : MuscleTaxonomyV1.byId[_anatomyId]?.labelEs ?? 'Anatomía'),
                  ),
                  if (_anatomyId != null)
                    TextButton(
                      key: const Key('anatomy_picker_reset'),
                      onPressed: () => setState(() => _anatomyId = null),
                      child: const Text('Quitar filtro anatómico'),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir músculos secundarios'),
                    value: _includeSecondary,
                    onChanged: (value) => setState(() =>
                        _includeSecondary = value ?? false),
                  ),
                  CheckboxListTile(
                    key: const Key('facet_custom'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo personalizados'),
                    value: _customOnly,
                    onChanged: (value) => setState(() => _customOnly = value ?? false),
                  ),
                  const Divider(),
                  Text('Filtros avanzados', style: Theme.of(context).textTheme.titleMedium),
                ],
                const SizedBox(height: 6),
                const Text(
                  'Patrón, mecánica y nivel son orientativos. '
                  'Los ejercicios antiguos y personalizados sin estos datos '
                  'siguen en la biblioteca general, pero no aparecerán al '
                  'activar un filtro que requiera clasificación.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ExerciseMovementCategory?>(
                  key: const Key('facet_movement'),
                  initialValue: _movement,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Patrón de movimiento',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<ExerciseMovementCategory?>(
                      value: null, child: Text('Todos los patrones'),
                    ),
                    for (final pattern in ExerciseMovementCategory.values)
                      DropdownMenuItem<ExerciseMovementCategory?>(
                        value: pattern,
                        child: Text(
                          pattern.labelEs,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _movement = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ExerciseMechanics?>(
                  key: const Key('facet_mechanics'),
                  initialValue: _mechanics,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de trabajo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<ExerciseMechanics?>(
                      value: null, child: Text('Todos los tipos'),
                    ),
                    for (final item in ExerciseMechanics.values)
                      DropdownMenuItem<ExerciseMechanics?>(
                        value: item, child: Text(item.labelEs),
                      ),
                  ],
                  onChanged: (value) => setState(() => _mechanics = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('facet_difficulty'),
                  initialValue: _difficulty,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Nivel técnico orientativo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ExerciseLibraryFilter.allOption,
                      child: Text('Todos los niveles'),
                    ),
                    DropdownMenuItem(
                      value: 'Principiante',
                      child: Text('Principiante'),
                    ),
                    DropdownMenuItem(
                      value: 'Intermedio',
                      child: Text('Intermedio'),
                    ),
                    DropdownMenuItem(
                      value: 'Avanzado',
                      child: Text('Avanzado'),
                    ),
                  ],
                  onChanged: (value) => setState(() =>
                      _difficulty = value ?? ExerciseLibraryFilter.allOption),
                ),
                if (!_unified) CheckboxListTile(
                  key: const Key('facet_bodyweight'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Solo ejercicios con peso corporal'),
                  subtitle: const Text('Sin pesas, máquinas ni bandas'),
                  value: _bodyweightOnly,
                  onChanged: (checked) =>
                      setState(() => _bodyweightOnly = checked ?? false),
                ),
                const SizedBox(height: 12),
      ],
    );
    final actions = Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('facet_clear'),
                        onPressed: () => Navigator.pop(
                          context, const AdvancedExerciseFilterSelection(),
                        ),
                        child: const Text('Limpiar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const Key('facet_apply'),
                        onPressed: () => Navigator.pop(
                          context,
                          _selection,
                        ),
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: _unified ? Column(
          children: [
            Expanded(child: SingleChildScrollView(child: fields)),
            const SizedBox(height: 8),
            actions,
          ],
        ) : SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
              children: [fields, actions]),
        ),
      ),
    );
  }
}
