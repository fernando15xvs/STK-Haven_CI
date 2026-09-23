import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/domain/models/personal_record.dart';
import 'package:core/domain/models/workout_analysis.dart';
import 'package:core/domain/models/progression_suggestion.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/workout_summary_snapshot.dart';

import '../../../core/theme/app_colors.dart';

class WorkoutSummaryPageWeb extends ConsumerWidget {
  final WorkoutAnalysisResult analysisResult;

  const WorkoutSummaryPageWeb({super.key, required this.analysisResult});

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final unit = settings.weightUnit;
    final session = analysisResult.session;
    final summary = WorkoutSummarySnapshot.fromSession(session);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Resumen del entrenamiento'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.done),
              label: const Text('Listo'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 100),
              children: [
                _SessionOverviewCardWeb(
                  summary: summary,
                  routineName: session.routineNameSnapshot,
                  duration: _formatDuration(analysisResult.durationSeconds),
                  volume: FitnessFormatter.formatVolume(
                    analysisResult.totalVolume,
                    unit,
                  ),
                ),
                if (summary.exercises.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _ExerciseMapWeb(summary: summary),
                ],
                if (analysisResult.personalRecords.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _Section(
                    title: '${analysisResult.personalRecords.length} récord${analysisResult.personalRecords.length == 1 ? '' : 's'} personal${analysisResult.personalRecords.length == 1 ? '' : 'es'}',
                    icon: Icons.emoji_events_outlined,
                    iconColor: AppColors.gold,
                    child: Column(
                      children: analysisResult.personalRecords.asMap().entries.map((entry) {
                        final pr = entry.value;
                        return Column(
                          children: [
                            if (entry.key > 0) const Divider(height: 1),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(pr.exerciseNameSnapshot, style: AppTypography.headlineSmall),
                              subtitle: Text(_prLabel(pr.type), style: AppTypography.bodySmall.copyWith(color: AppColors.gold)),
                              trailing: Text(
                                FitnessFormatter.formatPRValue(pr.newValue, pr.type, unit),
                                style: AppTypography.monoMedium.copyWith(color: AppColors.primary),
                              ),
                            ),
                          ],
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ],
                if (analysisResult.comparison != null) ...[
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Cambios registrados frente a la sesión anterior',
                    icon: Icons.compare_arrows,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comparación con la sesión anterior de esta misma rutina. Las diferencias son descriptivas.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ComparisonRow(
                          label: 'Volumen',
                          value: _percent(
                            analysisResult.comparison!.volumeDifferencePercent,
                          ),
                        ),
                        const Divider(height: 1),
                        _ComparisonRow(
                          label: 'Series',
                          value: _signed(
                            analysisResult.comparison!.setsDifference,
                          ),
                        ),
                        const Divider(height: 1),
                        _ComparisonRow(
                          label: 'Duración',
                          value: '${analysisResult.comparison!.durationDifferenceSeconds >= 0 ? '+' : ''}${analysisResult.comparison!.durationDifferenceSeconds ~/ 60} min',
                        ),
                      ],
                    ),
                  ),
                ],
                if (analysisResult.exerciseComparisons.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Cambio por ejercicio',
                    icon: Icons.insights_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cada movimiento se compara con su última ejecución global por exerciseId, aunque haya ocurrido en otra rutina.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ExerciseComparisonGridWeb(
                          comparisons: analysisResult.exerciseComparisons,
                          unit: unit,
                        ),
                      ],
                    ),
                  ),
                ],
                if (analysisResult.progressionSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Referencias para la próxima sesión',
                    icon: Icons.trending_up,
                    child: Column(
                      children: analysisResult.progressionSuggestions.asMap().entries.map((entry) {
                        final suggestion = entry.value;
                        return Column(
                          children: [
                            if (entry.key > 0) const Divider(height: 1),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.insights_outlined,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                suggestion.exerciseName,
                                style: AppTypography.headlineSmall,
                              ),
                              subtitle: _ProgressionSummaryContentWeb(
                                suggestion: suggestion,
                                unit: unit,
                              ),
                            ),
                          ],
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ],
                if (analysisResult.deloadSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Ajuste opcional',
                    icon: Icons.info_outline,
                    iconColor: AppColors.warning,
                    child: Column(
                      children: analysisResult.deloadSuggestions.asMap().entries.map((entry) {
                        final suggestion = entry.value;
                        return Column(
                          children: [
                            if (entry.key > 0) const Divider(height: 1),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.south_rounded,
                                color: AppColors.warning,
                              ),
                              title: Text(
                                suggestion.exerciseName,
                                style: AppTypography.headlineSmall,
                              ),
                              subtitle: _ProgressionSummaryContentWeb(
                                suggestion: suggestion,
                                unit: unit,
                              ),
                            ),
                          ],
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ],
                if (settings.showDailyVerse) ...[
                  const SizedBox(height: 20),
                  _FaithMessage(),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver a rutinas'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _prLabel(PRType type) {
    switch (type) {
      case PRType.maxWeight:
        return 'Mayor peso registrado';
      case PRType.estimated1RM:
        return 'Nuevo 1RM estimado';
      case PRType.bestSetVolume:
        return 'Mayor volumen en una serie';
    }
  }

  String _percent(double value) => '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
  String _signed(int value) => '${value > 0 ? '+' : ''}$value';
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTypography.headlineLarge),
                Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _Section({required this.title, required this.icon, required this.child, this.iconColor = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title.toUpperCase(), style: AppTypography.labelLarge)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String value;

  const _ComparisonRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = value.startsWith('0');
    final color =
        neutral ? AppColors.textSecondary : AppColors.info;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTypography.bodyMedium),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.sm_,
            ),
            child: Text(
              value,
              style: AppTypography.monoMedium.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseComparisonGridWeb extends StatelessWidget {
  const _ExerciseComparisonGridWeb({
    required this.comparisons,
    required this.unit,
  });

  final List<ExercisePerformanceComparison> comparisons;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 720;
        final cardWidth = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: comparisons
              .map(
                (comparison) => SizedBox(
                  width: cardWidth,
                  child: _ExerciseComparisonCardWeb(
                    comparison: comparison,
                    unit: unit,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ExerciseComparisonCardWeb extends StatelessWidget {
  const _ExerciseComparisonCardWeb({
    required this.comparison,
    required this.unit,
  });

  final ExercisePerformanceComparison comparison;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final previousDate = comparison.previousPerformedAt.toLocal();
    final dateLabel =
        '${previousDate.day.toString().padLeft(2, '0')}/${previousDate.month.toString().padLeft(2, '0')}';
    final routine = comparison.previousRoutineName.trim().isEmpty
        ? 'Entrenamiento libre'
        : comparison.previousRoutineName.trim();
    final volumeDelta = comparison.volumeDifferencePercent;
    final weightDelta = comparison.bestWeightDifference;
    final setsDelta = comparison.workingSetsDifference;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.md_,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comparison.exerciseName, style: AppTypography.headlineSmall),
          const SizedBox(height: 3),
          Text(
            'Última vez $dateLabel · $routine',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _DeltaChipWeb(
                text: volumeDelta == null
                    ? 'Volumen · sin base'
                    : 'Volumen · ${volumeDelta >= 0 ? '+' : ''}${volumeDelta.toStringAsFixed(1)}%',
              ),
              _DeltaChipWeb(
                text: weightDelta == 0
                    ? 'Peso · sin cambio'
                    : 'Peso · ${weightDelta > 0 ? '+' : ''}${FitnessFormatter.formatWeight(weightDelta, unit)}',
              ),
              _DeltaChipWeb(
                text: setsDelta == 0
                    ? 'Series · sin cambio'
                    : 'Series · ${setsDelta > 0 ? '+' : ''}$setsDelta',
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${FitnessFormatter.formatVolume(comparison.previousVolume, unit)} → ${FitnessFormatter.formatVolume(comparison.currentVolume, unit)} registrados',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaChipWeb extends StatelessWidget {
  const _DeltaChipWeb({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: AppRadius.sm_,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(color: AppColors.info),
      ),
    );
  }
}

class _FaithMessage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verse = ref.watch(randomVerseProvider);
    return _Section(
      title: 'Fortaleza',
      icon: Icons.auto_awesome_outlined,
      child: verse.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => Text('No se pudo cargar el mensaje en este momento.', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
        data: (value) {
          if (value == null) {
            return Text('Tu entrenamiento quedó guardado correctamente.', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('“${value.text}”', style: AppTypography.bodyLarge.copyWith(fontStyle: FontStyle.italic, height: 1.55)),
              const SizedBox(height: 8),
              Text(value.reference, style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressionSummaryContentWeb extends StatelessWidget {
  final ProgressionSuggestion suggestion;
  final WeightUnit unit;

  const _ProgressionSummaryContentWeb({
    required this.suggestion,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final color = _summaryProgressionColorWeb(suggestion);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FitnessFormatter.progressionTitle(suggestion),
            style: AppTypography.labelLarge.copyWith(color: color),
          ),
          const SizedBox(height: 3),
          Text(
            FitnessFormatter.progressionExplanation(suggestion),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (suggestion.type != ProgressionType.insufficientData) ...[
            const SizedBox(height: 4),
            Text(
              'Referencia: ${FitnessFormatter.formatProgressionTarget(suggestion.suggestedWeightKg, suggestion.suggestedRepsMin, suggestion.suggestedRepsMax, unit)}',
              style: AppTypography.bodyMedium.copyWith(color: color),
            ),
          ],
          const SizedBox(height: 3),
          Text(
            FitnessFormatter.progressionEvidence(suggestion),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            FitnessFormatter.progressionSafetyNote,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

Color _summaryProgressionColorWeb(ProgressionSuggestion suggestion) {
  if (suggestion.reason == ProgressionReason.recoveryCaution ||
      suggestion.reason == ProgressionReason.effortTooHigh) {
    return AppColors.warning;
  }
  return switch (suggestion.type) {
    ProgressionType.increase => AppColors.success,
    ProgressionType.maintain => AppColors.info,
    ProgressionType.deload => AppColors.warning,
    ProgressionType.insufficientData => AppColors.textSecondary,
  };
}

class _SessionOverviewCardWeb extends StatelessWidget {
  final WorkoutSummarySnapshot summary;
  final String routineName;
  final String duration;
  final String volume;

  const _SessionOverviewCardWeb({
    required this.summary,
    required this.routineName,
    required this.duration,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    final color = summary.isComplete ? AppColors.success : AppColors.info;
    final displayName =
        routineName.trim().isEmpty ? 'Entrenamiento libre' : routineName;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xl_,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final overview = Row(
            children: [
              SizedBox(
                width: 94,
                height: 94,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: summary.completionRatio,
                      strokeWidth: 8,
                      backgroundColor: AppColors.surfaceBorder,
                      color: color,
                    ),
                    Text(
                      '${summary.completionPercent}%',
                      style: AppTypography.monoMedium.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SESIÓN REGISTRADA',
                      style: AppTypography.labelLarge.copyWith(color: color),
                    ),
                    const SizedBox(height: 5),
                    Text(displayName, style: AppTypography.displaySmall),
                    const SizedBox(height: 5),
                    Text(
                      _sessionCompletionMessageWeb(summary),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final metrics = [
            _MetricCard(
              label: 'Tiempo registrado',
              value: duration,
              icon: Icons.timer_outlined,
            ),
            _MetricCard(
              label: 'Series de trabajo',
              value:
                  '${summary.completedWorkingSets}/${summary.plannedWorkingSets}',
              icon: Icons.layers_outlined,
            ),
            _MetricCard(
              label: 'Volumen registrado',
              value: volume,
              icon: Icons.monitor_weight_outlined,
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              overview,
              const SizedBox(height: 20),
              if (compact)
                Column(
                  children: metrics
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: item,
                        ),
                      )
                      .toList(growable: false),
                )
              else
                Row(
                  children: metrics
                      .map(
                        (item) => Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5),
                            child: item,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              if (summary.averageRir != null) ...[
                const SizedBox(height: 10),
                Text(
                  'RIR medio registrado: ${summary.averageRir!.toStringAsFixed(1)} · ${summary.rirLoggedSets} series',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'El tiempo y el volumen describen lo registrado; no califican por sí solos la calidad de la sesión.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseMapWeb extends StatelessWidget {
  final WorkoutSummarySnapshot summary;

  const _ExerciseMapWeb({required this.summary});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Mapa de la sesión',
      icon: Icons.view_list_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 680;
          final width = twoColumns
              ? (constraints.maxWidth - 10) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: summary.exercises.map((exercise) {
              final color =
                  exercise.isComplete ? AppColors.success : AppColors.info;
              return Container(
                width: width,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: AppRadius.md_,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise.exerciseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headlineSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${exercise.completedWorkingSets}/${exercise.plannedWorkingSets}',
                          style: AppTypography.labelMedium.copyWith(
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: exercise.completionRatio,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(99),
                      backgroundColor: AppColors.surfaceBorder,
                      color: color,
                    ),
                  ],
                ),
              );
            }).toList(growable: false),
          );
        },
      ),
    );
  }
}

String _sessionCompletionMessageWeb(WorkoutSummarySnapshot summary) {
  if (summary.plannedWorkingSets == 0) {
    return 'La sesión quedó guardada sin series de trabajo registradas.';
  }
  if (summary.isComplete) {
    return 'Se registraron todas las series de trabajo planificadas.';
  }
  return 'El resumen refleja únicamente las series que se completaron.';
}
