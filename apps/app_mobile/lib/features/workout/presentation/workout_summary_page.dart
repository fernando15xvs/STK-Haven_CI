import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/primary_button.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/domain/models/personal_record.dart';
import 'package:core/domain/models/workout_analysis.dart';
import 'package:core/domain/models/progression_suggestion.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/workout_summary_snapshot.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/core/theme/components/section_heading.dart';
import 'package:gym_tracker/features/workout/presentation/widgets/exercise_comparison_summary.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';

class WorkoutSummaryPage extends ConsumerStatefulWidget {
  final WorkoutAnalysisResult analysisResult;

  const WorkoutSummaryPage({super.key, required this.analysisResult});

  @override
  ConsumerState<WorkoutSummaryPage> createState() => _WorkoutSummaryPageState();
}

class _WorkoutSummaryPageState extends ConsumerState<WorkoutSummaryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slidePRsAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
    );
    _slidePRsAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward();

    // Haptic feedback for PRs — heavy impact reserved for achievements
    if (widget.analysisResult.personalRecords.isNotEmpty) {
      final vibrationEnabled = ref.read(settingsProvider).vibrationEnabled;
      if (vibrationEnabled) {
        HapticFeedback.heavyImpact();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(settingsProvider).showDailyVerse) {
        _showDevocionalModal(context);
      }
    });
  }

  void _showDevocionalModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DevocionalModal();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) =>
      '${seconds ~/ 60}m ${seconds % 60}s';

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final session = widget.analysisResult.session;
    final unit = settings.weightUnit;
    final summary = WorkoutSummarySnapshot.fromSession(session);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverSafeArea(
                sliver: SliverPadding(
                  padding: AppSpacing.pagePadding,
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.xxl),

              // ── 1. Visual session overview ─────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: _SessionOverviewCard(
                  summary: summary,
                  routineName: session.routineNameSnapshot,
                  duration: _formatDuration(
                    widget.analysisResult.durationSeconds,
                  ),
                  volume: FitnessFormatter.formatVolume(
                    widget.analysisResult.totalVolume,
                    unit,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ── 2. Exercise completion map ──────────────────────────────
              if (summary.exercises.isNotEmpty) ...[
                const SectionHeading(title: 'MAPA DE LA SESIÓN'),
                const SizedBox(height: AppSpacing.sm),
                PremiumCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: summary.exercises.asMap().entries.map((entry) {
                      return Column(
                        children: [
                          if (entry.key > 0) const Divider(height: 1),
                          _ExerciseCompletionRow(
                            exercise: entry.value,
                          ),
                        ],
                      );
                    }).toList(growable: false),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],

              // ── 3. Personal Records — slide-up animation ────────────────
              if (widget.analysisResult.personalRecords.isNotEmpty) ...[
                SlideTransition(
                  position: _slidePRsAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emoji_events, color: AppColors.gold, size: 20),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${widget.analysisResult.personalRecords.length} RÉCORDS',
                              style: AppTypography.labelLarge.copyWith(color: AppColors.gold),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PremiumCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: widget.analysisResult.personalRecords.asMap().entries.map((entry) {
                              final i = entry.key;
                              final pr = entry.value;
                              return Column(
                                children: [
                                  if (i > 0) const Divider(),
                                  ListTile(
                                    title: Text(pr.exerciseNameSnapshot, style: AppTypography.bodyLarge),
                                    subtitle: Text(
                                      _prTypeLabel(pr.type),
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.gold),
                                    ),
                                    trailing: Text(
                                      FitnessFormatter.formatPRValue(pr.newValue, pr.type, unit),
                                      style: AppTypography.monoMedium.copyWith(color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],

              // ── 4. Routine-scoped session comparison ────────────────────
              if (widget.analysisResult.comparison != null) ...[
                const SectionHeading(title: 'CAMBIOS REGISTRADOS'),
                const SizedBox(height: AppSpacing.sm),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Frente a la sesión anterior de esta rutina. Son diferencias descriptivas, no una puntuación.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ComparisonRow(
                        label: 'Volumen',
                        diffPercent: widget.analysisResult.comparison!.volumeDifferencePercent,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ComparisonRow(
                        label: 'Series',
                        diffRaw: widget.analysisResult.comparison!.setsDifference,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ComparisonRow(
                        label: 'Duración',
                        diffRaw: widget.analysisResult.comparison!.durationDifferenceSeconds ~/ 60,
                        isTime: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],

              // ── 5. Global exercise comparison ───────────────────────────
              if (widget.analysisResult.exerciseComparisons.isNotEmpty) ...[
                const SectionHeading(title: 'CAMBIO POR EJERCICIO'),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Cada ejercicio se compara con su última ejecución global por ID, aunque haya ocurrido en otra rutina.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                PremiumCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: widget.analysisResult.exerciseComparisons
                        .asMap()
                        .entries
                        .map((entry) => Column(
                              children: [
                                if (entry.key > 0) const Divider(height: 1),
                                ExerciseComparisonSummary(
                                  comparison: entry.value,
                                  unit: unit,
                                ),
                              ],
                            ))
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],

              // ── 6. Next Steps ───────────────────────────────────────────
              if (widget.analysisResult.progressionSuggestions.isNotEmpty) ...[
                const SectionHeading(title: 'PRÓXIMAS REFERENCIAS'),
                const SizedBox(height: AppSpacing.sm),
                PremiumCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: widget.analysisResult.progressionSuggestions.asMap().entries.map((entry) {
                      final i = entry.key;
                      final sug = entry.value;
                      return Column(
                        children: [
                          if (i > 0) const Divider(),
                          ListTile(
                            leading: const Icon(
                              Icons.insights_outlined,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              sug.exerciseName,
                              style: AppTypography.bodyLarge,
                            ),
                            subtitle: _ProgressionSummaryContent(
                              suggestion: sug,
                              unit: unit,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],

              // ── 7. Deload Suggestions ───────────────────────────────────
              if (widget.analysisResult.deloadSuggestions.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    const SectionHeading(title: 'AJUSTE OPCIONAL', color: AppColors.warning),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                PremiumCard(
                  backgroundColor: AppColors.warning.withValues(alpha: 0.08),
                  borderColor: AppColors.warning.withValues(alpha: 0.28),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: widget.analysisResult.deloadSuggestions.asMap().entries.map((entry) {
                      final i = entry.key;
                      final sug = entry.value;
                      return Column(
                        children: [
                          if (i > 0) const Divider(color: Colors.transparent, height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.south_rounded,
                              color: AppColors.warning,
                            ),
                            title: Text(
                              sug.exerciseName,
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                            subtitle: _ProgressionSummaryContent(
                              suggestion: sug,
                              unit: unit,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],

              const SizedBox(height: 100),
            ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    ],
  ),
  floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PrimaryButton(
          label: 'FINALIZAR',
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  String _prTypeLabel(PRType type) {
    switch (type) {
      case PRType.maxWeight:
        return 'Mayor peso histórico';
      case PRType.estimated1RM:
        return 'Nuevo 1RM estimado';
      case PRType.bestSetVolume:
        return 'Mayor volumen en serie';
    }
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.headlineLarge),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.labelSmall),
      ],
    );
  }
}

class _DevocionalModal extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(randomVerseProvider);
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(Icons.church, color: AppColors.primary, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('¡Buen Trabajo!', style: AppTypography.headlineLarge.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Un mensaje para tu espíritu',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            
            PremiumCard(
              child: stateAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => const Text('Error al cargar'),
                data: (verse) {
                  if (verse == null) return const Text('Sin contenido');
                  return Column(
                    children: [
                      Text(
                        '“${verse.text}”',
                        style: AppTypography.bodyLarge.copyWith(fontStyle: FontStyle.italic, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        verse.reference,
                        style: AppTypography.labelLarge.copyWith(color: AppColors.primary),
                      ),
                    ],
                  );
                },
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'CERRAR',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final double? diffPercent;
  final int? diffRaw;
  final bool isTime;

  const _ComparisonRow({
    required this.label,
    this.diffPercent,
    this.diffRaw,
    this.isTime = false,
  });

  @override
  Widget build(BuildContext context) {
    String text = '';
    var isNeutral = false;

    if (diffPercent != null) {
      isNeutral = diffPercent == 0;
      text =
          '${diffPercent! > 0 ? '+' : ''}${diffPercent!.toStringAsFixed(1)}%';
    } else if (diffRaw != null) {
      isNeutral = diffRaw == 0;
      text =
          '${diffRaw! > 0 ? '+' : ''}$diffRaw ${isTime ? 'min' : ''}';
    }

    final color =
        isNeutral ? AppColors.textSecondary : AppColors.info;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.sm_,
          ),
          child: Text(
            text.trim(),
            style: AppTypography.monoMedium.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}


class _ProgressionSummaryContent extends StatelessWidget {
  final ProgressionSuggestion suggestion;
  final WeightUnit unit;

  const _ProgressionSummaryContent({
    required this.suggestion,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final color = _summaryProgressionColor(suggestion);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FitnessFormatter.progressionTitle(suggestion),
            style: AppTypography.labelMedium.copyWith(color: color),
          ),
          const SizedBox(height: 3),
          Text(
            FitnessFormatter.progressionExplanation(suggestion),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (suggestion.type != ProgressionType.insufficientData) ...[
            const SizedBox(height: 4),
            Text(
              'Referencia: ${FitnessFormatter.formatProgressionTarget(suggestion.suggestedWeightKg, suggestion.suggestedRepsMin, suggestion.suggestedRepsMax, unit)}',
              style: AppTypography.bodySmall.copyWith(color: color),
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
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

Color _summaryProgressionColor(ProgressionSuggestion suggestion) {
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


class _SessionOverviewCard extends StatelessWidget {
  final WorkoutSummarySnapshot summary;
  final String routineName;
  final String duration;
  final String volume;

  const _SessionOverviewCard({
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

    return PremiumCard(
      borderColor: color.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 82,
                height: 82,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: summary.completionRatio,
                      strokeWidth: 7,
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
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SESIÓN REGISTRADA',
                      style: AppTypography.labelMedium.copyWith(color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(displayName, style: AppTypography.headlineLarge),
                    const SizedBox(height: 4),
                    Text(
                      _sessionCompletionMessage(summary),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _Metric(label: 'TIEMPO', value: duration)),
              Expanded(
                child: _Metric(
                  label: 'SERIES',
                  value:
                      '${summary.completedWorkingSets}/${summary.plannedWorkingSets}',
                ),
              ),
              Expanded(
                child: _Metric(label: 'VOLUMEN REG.', value: volume),
              ),
            ],
          ),
          if (summary.averageRir != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryFaded,
                borderRadius: AppRadius.sm_,
              ),
              child: Text(
                'RIR medio registrado: ${summary.averageRir!.toStringAsFixed(1)} · ${summary.rirLoggedSets} series',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'El tiempo y el volumen describen lo registrado; no califican por sí solos la calidad de la sesión.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textDisabled,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCompletionRow extends StatelessWidget {
  final WorkoutExerciseSummary exercise;

  const _ExerciseCompletionRow({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final color =
        exercise.isComplete ? AppColors.success : AppColors.info;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
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
                  style: AppTypography.bodyLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${exercise.completedWorkingSets}/${exercise.plannedWorkingSets} series',
                style: AppTypography.labelSmall.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: exercise.completionRatio,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppColors.surfaceBorder,
            color: color,
          ),
        ],
      ),
    );
  }
}

String _sessionCompletionMessage(WorkoutSummarySnapshot summary) {
  if (summary.plannedWorkingSets == 0) {
    return 'La sesión quedó guardada sin series de trabajo registradas.';
  }
  if (summary.isComplete) {
    return 'Se registraron todas las series de trabajo planificadas.';
  }
  return 'El resumen refleja únicamente las series que se completaron.';
}
