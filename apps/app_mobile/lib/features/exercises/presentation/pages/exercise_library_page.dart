import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/features/exercises/application/custom_exercise_service.dart';
import 'package:core/features/exercises/application/exercise_library_filter.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/exercises/presentation/providers/exercise_favorites_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';
import 'package:core/features/workout/application/workout_history_index.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/custom_exercise_editor_page.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_detail_page.dart';

class ExerciseLibraryPage extends ConsumerStatefulWidget {
  final bool isSelectionMode;

  const ExerciseLibraryPage({super.key, this.isSelectionMode = false});

  @override
  ConsumerState<ExerciseLibraryPage> createState() =>
      _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends ConsumerState<ExerciseLibraryPage> {
  String _searchQuery = '';
  String _selectedMuscle = ExerciseLibraryFilter.allOption;
  String _selectedEquipment = ExerciseLibraryFilter.allOption;
  ExerciseLateralityFilter _laterality = ExerciseLateralityFilter.all;
  bool _favoritesOnly = false;

  static const _muscles = [
    'Todos',
    'Pecho',
    'Espalda',
    'Piernas',
    'Hombros',
    'Brazos',
    'Core',
  ];

  Future<void> _openCustomEditor([dynamic exercise]) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomExerciseEditorPage(exercise: exercise),
      ),
    );
    if (!mounted || result == null) return;
    if (widget.isSelectionMode) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final allExercises = ref.watch(exerciseListProvider);
    final favoriteIds = ref.watch(exerciseFavoriteIdsProvider);
    final historyIndex = ref.watch(workoutHistoryIndexProvider);
    final weightUnit = ref.watch(
      settingsProvider.select((settings) => settings.weightUnit),
    );
    final equipmentOptions =
        ExerciseLibraryFilter.equipmentOptions(allExercises);
    final filteredExercises = ExerciseLibraryFilter.apply(
      exercises: allExercises,
      query: _searchQuery,
      muscle: _selectedMuscle,
      equipment: _selectedEquipment,
      laterality: _laterality,
      favoriteIds: favoriteIds,
      favoritesOnly: _favoritesOnly,
    );
    final memoryById = ExercisePerformanceMemory.latestForExercisesInIndex(
      historyIndex,
      filteredExercises.map((exercise) => exercise.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSelectionMode ? 'Seleccionar Ejercicio' : 'Biblioteca',
          style: AppTypography.headlineMedium,
        ),
        elevation: 0,
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            tooltip: 'Crear ejercicio personalizado',
            onPressed: _openCustomEditor,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar ejercicio...',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textDisabled,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _muscles.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(
                        _favoritesOnly ? Icons.star : Icons.star_border,
                        size: 17,
                        color: _favoritesOnly
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                      label: const Text('Favoritos'),
                      selected: _favoritesOnly,
                      showCheckmark: false,
                      onSelected: (selected) =>
                          setState(() => _favoritesOnly = selected),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceHigh,
                      side: BorderSide.none,
                    ),
                  );
                }
                final muscle = _muscles[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(muscle),
                    selected: _selectedMuscle == muscle,
                    showCheckmark: false,
                    onSelected: (_) =>
                        setState(() => _selectedMuscle = muscle),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceHigh,
                    side: BorderSide.none,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        equipmentOptions.contains(_selectedEquipment)
                            ? _selectedEquipment
                            : ExerciseLibraryFilter.allOption,
                    decoration: const InputDecoration(
                      labelText: 'Equipo',
                      isDense: true,
                    ),
                    items: equipmentOptions
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(
                      () => _selectedEquipment =
                          value ?? ExerciseLibraryFilter.allOption,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<ExerciseLateralityFilter>(
                    initialValue: _laterality,
                    decoration: const InputDecoration(
                      labelText: 'Ejecución',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ExerciseLateralityFilter.all,
                        child: Text('Todos'),
                      ),
                      DropdownMenuItem(
                        value: ExerciseLateralityFilter.unilateral,
                        child: Text('Unilateral'),
                      ),
                      DropdownMenuItem(
                        value: ExerciseLateralityFilter.bilateral,
                        child: Text('Bilateral'),
                      ),
                    ],
                    onChanged: (value) => setState(
                      () => _laterality =
                          value ?? ExerciseLateralityFilter.all,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: filteredExercises.isEmpty
                ? Center(
                    child: Text(
                      _favoritesOnly
                          ? 'Aún no tienes favoritos con estos filtros'
                          : 'No se encontraron ejercicios',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ).copyWith(bottom: 100),
                    itemCount: filteredExercises.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exercise = filteredExercises[index];
                      final isFavorite = favoriteIds.contains(exercise.id);
                      final isUnilateral =
                          ExerciseLibraryFilter.isUnilateral(exercise);
                      final isCustom = CustomExerciseService.isCustom(exercise);
                      final memory = memoryById[exercise.id];
                      final lastSet = memory?.latestRepresentativeSet;
                      final lastPerformance = lastSet == null
                          ? null
                          : '${FitnessFormatter.formatWeight(lastSet.performanceWeight, weightUnit)} × ${lastSet.performanceReps}${lastSet.performanceRir == null ? '' : ' @RIR ${lastSet.performanceRir}'}';
                      return PremiumCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () {
                          if (widget.isSelectionMode) {
                            Navigator.pop(context, exercise);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ExerciseDetailPage(exercise: exercise),
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.fitness_center,
                                color: AppColors.textSecondary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          exercise.name,
                                          style: AppTypography.headlineMedium
                                              .copyWith(
                                            color: AppColors.textPrimary,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      if (isCustom)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Personalizado',
                                            style: AppTypography.labelSmall
                                                .copyWith(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${exercise.muscleGroup} • ${exercise.equipment.isEmpty ? 'Libre' : exercise.equipment}${isUnilateral ? ' • Unilateral' : ''}',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (lastPerformance != null) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      'Última: $lastPerformance · ${memory!.routineName.trim().isEmpty ? 'Entrenamiento libre' : memory.routineName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isCustom && !widget.isSelectionMode)
                              IconButton(
                                tooltip: 'Editar ejercicio',
                                onPressed: () => _openCustomEditor(exercise),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            IconButton(
                              tooltip: isFavorite
                                  ? 'Quitar de favoritos'
                                  : 'Añadir a favoritos',
                              onPressed: () => ref
                                  .read(exerciseFavoriteIdsProvider.notifier)
                                  .toggleFavorite(exercise.id),
                              icon: Icon(
                                isFavorite ? Icons.star : Icons.star_border,
                                color: isFavorite
                                    ? AppColors.gold
                                    : AppColors.textSecondary,
                              ),
                            ),
                            Icon(
                              widget.isSelectionMode
                                  ? Icons.add_circle
                                  : Icons.chevron_right,
                              color: widget.isSelectionMode
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: widget.isSelectionMode ? 28 : 24,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
