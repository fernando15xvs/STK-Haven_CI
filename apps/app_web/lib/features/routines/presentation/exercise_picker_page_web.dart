import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/features/exercises/application/custom_exercise_service.dart';
import 'package:core/features/exercises/application/exercise_library_filter.dart';
import 'package:core/features/exercises/presentation/providers/exercise_favorites_provider.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';
import 'package:core/features/workout/application/workout_history_index.dart';

import '../../../core/theme/app_colors.dart';
import 'custom_exercise_dialog_web.dart';

class ExercisePickerPageWeb extends ConsumerStatefulWidget {
  const ExercisePickerPageWeb({super.key});

  @override
  ConsumerState<ExercisePickerPageWeb> createState() =>
      _ExercisePickerPageWebState();
}

class _ExercisePickerPageWebState
    extends ConsumerState<ExercisePickerPageWeb> {
  String _query = '';
  String _muscle = ExerciseLibraryFilter.allOption;
  String _equipment = ExerciseLibraryFilter.allOption;
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

  Future<void> _createCustom() async {
    final created = await showCustomExerciseDialogWeb(context, ref);
    if (!mounted || created == null) return;
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exerciseListProvider);
    final favoriteIds = ref.watch(exerciseFavoriteIdsProvider);
    final historyIndex = ref.watch(workoutHistoryIndexProvider);
    final weightUnit = ref.watch(
      settingsProvider.select((settings) => settings.weightUnit),
    );
    final equipmentOptions = ExerciseLibraryFilter.equipmentOptions(exercises);
    final filtered = ExerciseLibraryFilter.apply(
      exercises: exercises,
      query: _query,
      muscle: _muscle,
      equipment: _equipment,
      laterality: _laterality,
      favoriteIds: favoriteIds,
      favoritesOnly: _favoritesOnly,
    );
    final memoryById = ExercisePerformanceMemory.latestForExercisesInIndex(
      historyIndex,
      filtered.map((exercise) => exercise.id),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Seleccionar ejercicio'),
        actions: [
          TextButton.icon(
            onPressed: _createCustom,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Nuevo ejercicio'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: TextField(
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Buscar ejercicio...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemBuilder: (_, index) {
                      if (index == 0) {
                        return FilterChip(
                          avatar: Icon(
                            _favoritesOnly ? Icons.star : Icons.star_border,
                            size: 17,
                          ),
                          label: const Text('Favoritos'),
                          selected: _favoritesOnly,
                          showCheckmark: false,
                          onSelected: (selected) =>
                              setState(() => _favoritesOnly = selected),
                        );
                      }

                      final item = _muscles[index - 1];
                      return FilterChip(
                        label: Text(item),
                        selected: _muscle == item,
                        onSelected: (_) => setState(() => _muscle = item),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemCount: _muscles.length + 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 240,
                        child: DropdownButtonFormField<String>(
                          initialValue: equipmentOptions.contains(_equipment)
                              ? _equipment
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
                            () => _equipment =
                                value ?? ExerciseLibraryFilter.allOption,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child:
                            DropdownButtonFormField<ExerciseLateralityFilter>(
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
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            _favoritesOnly
                                ? 'Aún no tienes favoritos con estos filtros'
                                : 'No se encontraron ejercicios',
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 900
                                ? 3
                                : constraints.maxWidth >= 600
                                    ? 2
                                    : 1;
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: columns == 1 ? 3.45 : 2.15,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final exercise = filtered[index];
                                final isFavorite =
                                    favoriteIds.contains(exercise.id);
                                final isUnilateral =
                                    ExerciseLibraryFilter.isUnilateral(exercise);
                                final isCustom =
                                    CustomExerciseService.isCustom(exercise);
                                final memory = memoryById[exercise.id];
                                final lastSet = memory?.latestRepresentativeSet;
                                final lastPerformance = lastSet == null
                                    ? null
                                    : '${FitnessFormatter.formatWeight(lastSet.performanceWeight, weightUnit)} × ${lastSet.performanceReps}${lastSet.performanceRir == null ? '' : ' @RIR ${lastSet.performanceRir}'}';
                                return Material(
                                  color: AppColors.surface,
                                  borderRadius: AppRadius.md_,
                                  child: InkWell(
                                    onTap: () =>
                                        Navigator.of(context).pop(exercise),
                                    borderRadius: AppRadius.md_,
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        borderRadius: AppRadius.md_,
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius: AppRadius.sm_,
                                            ),
                                            child: const Icon(
                                              Icons.fitness_center,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        exercise.name,
                                                        style: AppTypography
                                                            .headlineSmall,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    if (isCustom)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                          left: 6,
                                                        ),
                                                        child: Icon(
                                                          Icons.person_outline,
                                                          size: 16,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${exercise.muscleGroup} · ${exercise.equipment.isEmpty ? 'Libre' : exercise.equipment}${isUnilateral ? ' · Unilateral' : ''}',
                                                  style: AppTypography.bodySmall
                                                      .copyWith(
                                                    color: AppColors
                                                        .textSecondary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (lastPerformance != null) ...[
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    'Última: $lastPerformance · ${memory!.routineName.trim().isEmpty ? 'Entrenamiento libre' : memory.routineName}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: AppTypography.bodySmall
                                                        .copyWith(
                                                      color:
                                                          AppColors.primary,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (isCustom)
                                            IconButton(
                                              tooltip: 'Editar ejercicio',
                                              onPressed: () =>
                                                  showCustomExerciseDialogWeb(
                                                context,
                                                ref,
                                                exercise: exercise,
                                              ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                          IconButton(
                                            tooltip: isFavorite
                                                ? 'Quitar de favoritos'
                                                : 'Añadir a favoritos',
                                            onPressed: () => ref
                                                .read(
                                                  exerciseFavoriteIdsProvider
                                                      .notifier,
                                                )
                                                .toggleFavorite(exercise.id),
                                            icon: Icon(
                                              isFavorite
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: isFavorite
                                                  ? AppColors.gold
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.add_circle,
                                            color: AppColors.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
