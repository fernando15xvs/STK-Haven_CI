import 'package:core/core/constants/curated_exercise_catalog.dart';
import 'package:core/features/exercises/application/exercise_library_filter.dart';
import 'package:flutter/material.dart';

/// Browsing state only. Does not change workouts, favorites, or stored exercises.
class AdvancedExerciseFilterSelection {
  final ExerciseMovementCategory? movementCategory;
  final ExerciseMechanics? mechanics;
  final String difficulty;
  final bool bodyweightOnly;

  const AdvancedExerciseFilterSelection({
    this.movementCategory,
    this.mechanics,
    this.difficulty = ExerciseLibraryFilter.allOption,
    this.bodyweightOnly = false,
  });

  int get activeCount =>
      (movementCategory == null ? 0 : 1) +
      (mechanics == null ? 0 : 1) +
      (difficulty == ExerciseLibraryFilter.allOption ? 0 : 1) +
      (bodyweightOnly ? 1 : 0);
}

class AdvancedExerciseFilterSheet extends StatefulWidget {
  const AdvancedExerciseFilterSheet({
    super.key,
    required this.initialSelection,
  });

  final AdvancedExerciseFilterSelection initialSelection;

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

  @override
  void initState() {
    super.initState();
    _movement = widget.initialSelection.movementCategory;
    _mechanics = widget.initialSelection.mechanics;
    _difficulty = widget.initialSelection.difficulty;
    _bodyweightOnly = widget.initialSelection.bodyweightOnly;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Filtros avanzados',
                    style: Theme.of(context).textTheme.titleLarge),
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
                CheckboxListTile(
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
                Row(
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
                          AdvancedExerciseFilterSelection(
                            movementCategory: _movement,
                            mechanics: _mechanics,
                            difficulty: _difficulty,
                            bodyweightOnly: _bodyweightOnly,
                          ),
                        ),
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
