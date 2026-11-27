import 'package:gym_tracker/core/layout/mobile_content_frame.dart';
import 'package:flutter/material.dart';
import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'package:core/core/constants/curated_exercise_catalog.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/features/exercises/application/exercise_demonstration_library.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/exercise_png_pilot_library.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/exercise_demonstration_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/features/exercises/application/custom_exercise_service.dart';
import 'package:core/features/exercises/application/exercise_library_filter.dart';
import 'package:core/features/exercises/application/providers/exercise_provider.dart';
import 'package:core/features/exercises/application/providers/exercise_favorites_provider.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';
import 'package:core/features/workout/application/workout_history_index.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/custom_exercise_editor_page.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_detail_page.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/advanced_exercise_filter_sheet.dart';

class ExerciseLibraryPage extends ConsumerStatefulWidget {
  final bool isSelectionMode;
  final bool allowMultiple;

  const ExerciseLibraryPage({
    super.key, this.isSelectionMode = false, this.allowMultiple = false,
  }) : assert(!allowMultiple || isSelectionMode);

  @override
  ConsumerState<ExerciseLibraryPage> createState() =>
      _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends ConsumerState<ExerciseLibraryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedMuscle = ExerciseLibraryFilter.allOption;
  bool _favoritesOnly = false;
  AdvancedExerciseFilterSelection _advanced = const AdvancedExerciseFilterSelection();
  ExerciseLibrarySort _sort = ExerciseLibrarySort.relevance;
  final _selected = <String, Exercise>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const _muscles = [
    'Todos',
    'Pecho',
    'Espalda',
    'Piernas',
    'Hombros',
    'Brazos',
    'Core',
  ];

  Future<void> _chooseAdvancedFilters(List<String> equipmentOptions) async {
    final result = await showModalBottomSheet<AdvancedExerciseFilterSelection>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: AdvancedExerciseFilterSheet(
          initialSelection: _advanced, equipmentOptions: equipmentOptions,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _advanced = result;
      if (result.anatomyId != null) {
        _selectedMuscle = ExerciseLibraryFilter.allOption;
      }
    });
  }

  void _select(Exercise exercise) {
    if (widget.allowMultiple) {
      setState(() => _selected[exercise.id] = exercise);
    } else {
      Navigator.of(context).pop(exercise);
    }
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedMuscle = ExerciseLibraryFilter.allOption;
      _favoritesOnly = false;
      _advanced = const AdvancedExerciseFilterSelection();
      _sort = ExerciseLibrarySort.relevance;
    });
  }

  Future<void> _previewAndSelect(Exercise exercise) async {
    final history = ref.read(workoutHistoryIndexProvider);
    final settings = ref.read(settingsProvider);
    final memory = ExercisePerformanceMemory.latestForExerciseInIndex(history, exercise.id);
    final lastSet = memory?.latestRepresentativeSet;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                exercise.name,
                style: Theme.of(sheetContext).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('exercise_selection_preview'),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (lastSet != null) ...[
                      Text('Último rendimiento',
                          style: Theme.of(sheetContext).textTheme.labelLarge),
                      Text('${FitnessFormatter.formatWeight(lastSet.performanceWeight, settings.weightUnit)} × ${lastSet.performanceReps}${lastSet.performanceRir == null ? '' : ' · RIR ${lastSet.performanceRir}'}'),
                      if (memory != null)
                        Text('${memory.routineName.trim().isEmpty ? 'Entrenamiento libre' : memory.routineName} · ${memory.performedAt.day}/${memory.performedAt.month}/${memory.performedAt.year}',
                            style: Theme.of(sheetContext).textTheme.bodySmall),
                      const SizedBox(height: 12),
                    ],
                    ExerciseDemonstrationCard(
                      exercise: exercise,
                      compact: true,
                      reduceMotion: settings.reduceMotion,
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('exercise_preview_cancel'),
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('Volver'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('exercise_preview_add'),
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: const Text('Añadir'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    _select(exercise);
  }

  Future<void> _openCustomEditor([Exercise? exercise]) async {
    final result = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => CustomExerciseEditorPage(exercise: exercise)),
    );
    if (!mounted || result == null) return;
    if (widget.isSelectionMode) _select(result);
  }

  Future<void> _editFromDetail(Exercise exercise) async {
    final result = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => CustomExerciseEditorPage(exercise: exercise)),
    );
    if (mounted && result != null) Navigator.of(context).pop();
  }

  String _facetLabel(ExerciseLibraryFacet facet) => switch (facet) {
    ExerciseLibraryFacet.equipment => _advanced.equipment,
    ExerciseLibraryFacet.laterality => switch (_advanced.laterality) {
      ExerciseLateralityFilter.unilateral => 'Unilateral',
      ExerciseLateralityFilter.bilateral => 'Bilateral',
      ExerciseLateralityFilter.unspecified => 'No especificada',
      ExerciseLateralityFilter.all => 'Ejecución',
    },
    ExerciseLibraryFacet.anatomy =>
      MuscleTaxonomyV1.byId[_advanced.anatomyId]?.labelEs ?? 'Anatomía',
    ExerciseLibraryFacet.movement => _advanced.movementCategory!.labelEs,
    ExerciseLibraryFacet.mechanics => _advanced.mechanics!.labelEs,
    ExerciseLibraryFacet.difficulty => _advanced.difficulty,
    ExerciseLibraryFacet.bodyweight => 'Peso corporal',
    ExerciseLibraryFacet.custom => 'Personalizados',
    ExerciseLibraryFacet.secondary => 'Músculos secundarios',
  };

  String _sortLabel(ExerciseLibrarySort sort) => switch (sort) {
    ExerciseLibrarySort.relevance => 'Relevancia',
    ExerciseLibrarySort.alphabetical => 'Alfabético',
    ExerciseLibrarySort.recent => 'Usados recientemente',
    ExerciseLibrarySort.mostUsed => 'Más utilizados',
  };

  Widget _thumbnail(Exercise exercise) {
    final colors = AppColors.of(context);
    final media = ExerciseDemonstrationLibrary.mediaFor(exercise);
    final pilot = PngPilotLibrary.forId(exercise.id);
    final asset = pilot != null
        ? pilot.imageAt(0)
        : media?.format == ExerciseMediaFormat.poster ? media!.assetPath : null;
    final fallback = Icon(Icons.fitness_center, size: 22, color: colors.textSecondary);
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: asset == null ? fallback : Image.asset(
        asset, fit: BoxFit.contain, cacheWidth: 96,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final allExercises = ref.watch(exerciseListProvider);
    final favoriteIds = ref.watch(exerciseFavoriteIdsProvider);
    final historyIndex = ref.watch(workoutHistoryIndexProvider);
    final weightUnit = ref.watch(settingsProvider.select((s) => s.weightUnit));
    final equipmentOptions = ExerciseLibraryFilter.equipmentOptions(allExercises);
    final filtered = ExerciseLibraryFilter.apply(
      exercises: allExercises,
      query: _searchQuery,
      muscle: _selectedMuscle,
      anatomyId: _advanced.anatomyId,
      equipment: _advanced.equipment,
      laterality: _advanced.laterality,
      movementCategory: _advanced.movementCategory,
      mechanics: _advanced.mechanics,
      difficulty: _advanced.difficulty,
      bodyweightOnly: _advanced.bodyweightOnly,
      customOnly: _advanced.customOnly,
      includeSecondary: _advanced.includeSecondary,
      favoriteIds: favoriteIds,
      favoritesOnly: _favoritesOnly,
      sort: _sort,
      historyIndex: historyIndex,
    );
    final facets = _advanced.activeFacets;
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    Widget chip(String label, bool selected, VoidCallback onTap,
        {IconData? icon}) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: icon == null ? null : Icon(icon, size: 17,
            color: selected ? colors.onPrimary : colors.textSecondary),
        label: Text(label),
        labelStyle: AppTypography.labelMedium.copyWith(
          color: selected ? colors.onPrimary : colors.textSecondary,
        ),
        selected: selected, showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: colors.primary, backgroundColor: colors.surfaceHigh,
        side: BorderSide.none,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? 'Seleccionar ejercicio' : 'Biblioteca',
          style: AppTypography.headlineMedium, maxLines: 1,
          overflow: TextOverflow.ellipsis),
        elevation: 0, backgroundColor: colors.background,
        actions: [
          IconButton(
            tooltip: 'Crear ejercicio personalizado',
            onPressed: _openCustomEditor,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Expanded(child: TextField(
                    key: const Key('library_search'),
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar ejercicio...',
                      hintStyle: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
                      prefixIcon: Icon(Icons.search, color: colors.textSecondary),
                      suffixIcon: _searchQuery.isEmpty ? null : IconButton(
                        tooltip: 'Borrar búsqueda',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                      filled: true, fillColor: colors.surfaceHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  )),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('open_advanced_exercise_filters'),
                    tooltip: 'Filtros (${facets.length} activos)',
                    style: IconButton.styleFrom(
                      backgroundColor: colors.primary, foregroundColor: colors.onPrimary,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _chooseAdvancedFilters(equipmentOptions);
                    },
                    icon: Badge(
                      isLabelVisible: facets.isNotEmpty,
                      label: Text('${facets.length}'),
                      child: const Icon(Icons.tune),
                    ),
                  ),
                ],
              ),
            ),
            if (!typing)
              SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                chip('Favoritos', _favoritesOnly,
                    () => setState(() => _favoritesOnly = !_favoritesOnly),
                    icon: _favoritesOnly ? Icons.star : Icons.star_border),
                for (final muscle in _muscles)
                  chip(muscle, _advanced.anatomyId == null && _selectedMuscle == muscle,
                    () => setState(() {
                      _selectedMuscle = muscle;
                      _advanced = _advanced.without(ExerciseLibraryFacet.anatomy);
                    })),
              ]),
            ),
            if (!typing && facets.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  for (final facet in facets)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        key: ValueKey('library_active_${facet.name}'),
                        label: Text(_facetLabel(facet)),
                        onDeleted: () => setState(() => _advanced = _advanced.without(facet)),
                      ),
                    ),
                ]),
              ),
            if (!typing)
              Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: Text(
                  '${filtered.length} ejercicios',
                  style: AppTypography.labelMedium.copyWith(color: colors.textSecondary),
                )),
                PopupMenuButton<ExerciseLibrarySort>(
                  key: const Key('library_sort'),
                  tooltip: 'Ordenar: ${_sortLabel(_sort)}',
                  initialValue: _sort,
                  icon: Icon(Icons.sort, color: colors.primary),
                  onSelected: (sort) => setState(() => _sort = sort),
                  itemBuilder: (_) => [
                    for (final sort in ExerciseLibrarySort.values)
                      PopupMenuItem(value: sort, child: Text(_sortLabel(sort))),
                  ],
                ),
              ]),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.search_off, size: 36, color: colors.textSecondary),
                          const SizedBox(height: 8),
                          Text(_favoritesOnly
                              ? 'No hay favoritos con estos filtros'
                              : 'No se encontraron ejercicios',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          TextButton(onPressed: _resetFilters,
                              child: const Text('Limpiar búsqueda y filtros')),
                        ]),
                      ),
                    )
                  : ListView.separated(
                      key: const Key('library_results'),
                      padding: SecondaryScreenInsets.scrollPadding(context,
                          const EdgeInsets.fromLTRB(16, 0, 16, 24)),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Divider(
                          height: 1, color: colors.surfaceBorder),
                      itemBuilder: (context, index) {
                        final exercise = filtered[index];
                        final isFavorite = favoriteIds.contains(exercise.id);
                        final isCustom = CustomExerciseService.isCustom(exercise);
                        final chosen = _selected.containsKey(exercise.id);
                        final lastSet = ExercisePerformanceMemory
                            .latestForExerciseInIndex(historyIndex, exercise.id)
                            ?.latestRepresentativeSet;
                        final lastPerformance = lastSet == null ? null
                            : '${FitnessFormatter.formatWeight(lastSet.performanceWeight, weightUnit)} × ${lastSet.performanceReps}${lastSet.performanceRir == null ? '' : ' · RIR ${lastSet.performanceRir}'}';
                        return Material(
                          color: colors.background,
                          child: InkWell(
                            key: ValueKey('library_exercise_${exercise.id}'),
                            onTap: () {
                              if (widget.isSelectionMode) {
                                if (chosen) {
                                  setState(() => _selected.remove(exercise.id));
                                } else {
                                  _previewAndSelect(exercise);
                                }
                              } else {
                                Navigator.push(context, MaterialPageRoute<void>(
                                  builder: (_) => ExerciseDetailPage(
                                    exercise: exercise,
                                    onEdit: isCustom ? () => _editFromDetail(exercise) : null,
                                  ),
                                ));
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                                _thumbnail(exercise),
                                const SizedBox(width: 10),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(exercise.name, style: AppTypography.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600, color: colors.textPrimary)),
                                    const SizedBox(height: 3),
                                    Text('${exercise.muscleGroup} · ${exercise.equipment.isEmpty ? 'Libre' : exercise.equipment}',
                                      style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
                                    if (isCustom)
                                      Text('Personalizado', style: AppTypography.labelSmall.copyWith(
                                          color: colors.textSecondary)),
                                    if (lastPerformance != null)
                                      Text(lastPerformance, style: AppTypography.bodySmall.copyWith(
                                          color: colors.primary)),
                                  ],
                                )),
                                IconButton(
                                  tooltip: isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
                                  onPressed: () => ref.read(exerciseFavoriteIdsProvider.notifier)
                                      .toggleFavorite(exercise.id),
                                  icon: Icon(isFavorite ? Icons.star : Icons.star_border,
                                      color: isFavorite ? colors.gold : colors.textSecondary),
                                ),
                                Icon(widget.isSelectionMode
                                    ? chosen ? Icons.check_circle : Icons.add_circle_outline
                                    : Icons.chevron_right,
                                    color: widget.isSelectionMode ? colors.primary : colors.textSecondary,
                                    size: 22),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.allowMultiple ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton(
            key: const Key('library_confirm_multiple'),
            onPressed: _selected.isEmpty ? null : () =>
                Navigator.of(context).pop(List<Exercise>.unmodifiable(_selected.values)),
            child: Text('Añadir seleccionados (${_selected.length})'),
          ),
        ),
      ) : null,
    );
  }
}
