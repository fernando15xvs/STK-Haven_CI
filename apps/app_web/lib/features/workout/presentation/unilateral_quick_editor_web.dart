import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';

class UnilateralQuickEditorWeb extends ConsumerStatefulWidget {
  const UnilateralQuickEditorWeb({super.key});

  @override
  ConsumerState<UnilateralQuickEditorWeb> createState() =>
      _UnilateralQuickEditorWebState();
}

class _UnilateralQuickEditorWebState
    extends ConsumerState<UnilateralQuickEditorWeb> {
  final _leftWeight = TextEditingController();
  final _leftReps = TextEditingController();
  final _leftRir = TextEditingController();
  final _rightWeight = TextEditingController();
  final _rightReps = TextEditingController();
  final _rightRir = TextEditingController();
  String? _boundKey;

  @override
  void dispose() {
    _leftWeight.dispose();
    _leftReps.dispose();
    _leftRir.dispose();
    _rightWeight.dispose();
    _rightReps.dispose();
    _rightRir.dispose();
    super.dispose();
  }

  String _number(double value) => value == 0
      ? ''
      : value % 1 == 0
          ? '${value.toInt()}'
          : value.toStringAsFixed(1);

  void _bind(WorkoutSet set, WeightUnit unit, String key) {
    if (_boundKey == key) return;
    _boundKey = key;
    _leftWeight.text = _number(
      WeightConverter.displayWeight(
        set.weightForSide(WorkoutSide.left),
        unit,
      ),
    );
    _leftReps.text = set.repsForSide(WorkoutSide.left) == 0
        ? ''
        : '${set.repsForSide(WorkoutSide.left)}';
    _leftRir.text = set.rirForSide(WorkoutSide.left)?.toString() ?? '';
    _rightWeight.text = _number(
      WeightConverter.displayWeight(
        set.weightForSide(WorkoutSide.right),
        unit,
      ),
    );
    _rightReps.text = set.repsForSide(WorkoutSide.right) == 0
        ? ''
        : '${set.repsForSide(WorkoutSide.right)}';
    _rightRir.text = set.rirForSide(WorkoutSide.right)?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeWorkoutProvider.select((state) => state.session));
    final settings = ref.watch(settingsProvider);
    if (session == null) return const SizedBox.shrink();

    int? exerciseIndex;
    int? setIndex;
    WorkoutExercise? exercise;
    WorkoutSet? set;
    for (var e = 0; e < session.exercises.length; e++) {
      final candidate = session.exercises[e];
      if (!candidate.unilateral) continue;
      for (var s = 0; s < candidate.sets.length; s++) {
        if (!candidate.sets[s].completed) {
          exerciseIndex = e;
          setIndex = s;
          exercise = candidate;
          set = candidate.sets[s];
          break;
        }
      }
      if (set != null) break;
    }

    if (exerciseIndex == null || setIndex == null || exercise == null || set == null) {
      return const SizedBox.shrink();
    }

    final key = '${session.id}:${exercise.exerciseId}:$setIndex:${set.leftCompleted}:${set.rightCompleted}';
    _bind(set, settings.weightUnit, key);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Material(
        elevation: settings.performanceMode == PerformanceMode.savings ? 0 : 10,
        borderRadius: BorderRadius.circular(18),
        color: AppColors.surface,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.compare_arrows, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unilateral Pro · ${exercise.exerciseNameSnapshot} · Serie ${setIndex + 1}',
                      style: AppTypography.headlineSmall,
                    ),
                  ),
                  Text(
                    settings.unilateralSameWeightByDefault
                        ? 'Mismo peso'
                        : 'Peso independiente',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SideColumn(
                      title: 'IZQUIERDA',
                      completed: set.leftCompleted,
                      weight: _leftWeight,
                      reps: _leftReps,
                      rir: _leftRir,
                      unit: settings.weightUnit,
                      rirEnabled: settings.isRirEnabled &&
                          set.setType == WorkoutSetType.working,
                      onCommit: () => _commitSide(
                        exerciseIndex: exerciseIndex!,
                        setIndex: setIndex!,
                        set: set!,
                        side: WorkoutSide.left,
                        settings: settings,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SideColumn(
                      title: 'DERECHA',
                      completed: set.rightCompleted,
                      weight: _rightWeight,
                      reps: _rightReps,
                      rir: _rightRir,
                      unit: settings.weightUnit,
                      rirEnabled: settings.isRirEnabled &&
                          set.setType == WorkoutSetType.working,
                      onCommit: () => _commitSide(
                        exerciseIndex: exerciseIndex!,
                        setIndex: setIndex!,
                        set: set!,
                        side: WorkoutSide.right,
                        settings: settings,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                set.sideRestSeconds <= 0
                    ? 'Sin descanso automático entre lados.'
                    : 'Al completar el primer lado, el descanso entre lados usa ${set.sideRestSeconds}s. El descanso posterior a la serie sigue siendo independiente.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _commitSide({
    required int exerciseIndex,
    required int setIndex,
    required WorkoutSet set,
    required WorkoutSide side,
    required SettingsState settings,
  }) {
    final left = side == WorkoutSide.left;
    final alreadyCompleted = set.completedForSide(side);
    if (alreadyCompleted) {
      ref.read(activeWorkoutProvider.notifier).toggleUnilateralSide(
            exerciseIndex,
            setIndex,
            left: left,
          );
      return;
    }

    final weightText = left ? _leftWeight.text : _rightWeight.text;
    final repsText = left ? _leftReps.text : _rightReps.text;
    final rirText = left ? _leftRir.text : _rightRir.text;
    final displayWeight = double.tryParse(weightText.replaceAll(',', '.')) ?? 0;
    final weight = WeightConverter.toCanonicalKg(displayWeight, settings.weightUnit);
    final reps = int.tryParse(repsText) ?? 0;
    final rir = int.tryParse(rirText);

    WorkoutSet draft;
    if (left) {
      draft = set.copyWith(
        weight: weight,
        reps: reps,
        rir: rir,
        clearRir: rir == null,
        leftWeight: weight,
        leftReps: reps,
        leftRir: rir,
        clearLeftRir: rir == null,
        rightWeight: settings.unilateralSameWeightByDefault ? weight : null,
      );
      if (settings.unilateralSameWeightByDefault) {
        _rightWeight.text = _number(displayWeight);
      }
    } else {
      draft = set.copyWith(
        weight: weight,
        reps: reps,
        rir: rir,
        clearRir: rir == null,
        rightWeight: weight,
        rightReps: reps,
        rightRir: rir,
        clearRightRir: rir == null,
        leftWeight: settings.unilateralSameWeightByDefault ? weight : null,
      );
      if (settings.unilateralSameWeightByDefault) {
        _leftWeight.text = _number(displayWeight);
      }
    }

    final notifier = ref.read(activeWorkoutProvider.notifier);
    notifier.updateSet(exerciseIndex, setIndex, draft);
    notifier.toggleUnilateralSide(
      exerciseIndex,
      setIndex,
      left: left,
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({
    required this.title,
    required this.completed,
    required this.weight,
    required this.reps,
    required this.rir,
    required this.unit,
    required this.rirEnabled,
    required this.onCommit,
  });

  final String title;
  final bool completed;
  final TextEditingController weight;
  final TextEditingController reps;
  final TextEditingController rir;
  final WeightUnit unit;
  final bool rirEnabled;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: completed ? AppColors.successFaded : AppColors.surfaceHigh,
        borderRadius: AppRadius.md_,
        border: Border.all(
          color: completed ? AppColors.success : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: weight,
                  enabled: !completed,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Peso (${unit.label})'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: reps,
                  enabled: !completed,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                ),
              ),
              if (rirEnabled) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: rir,
                    enabled: !completed,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'RIR'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onCommit,
            style: FilledButton.styleFrom(
              backgroundColor: completed ? AppColors.success : null,
            ),
            icon: Icon(completed ? Icons.undo_rounded : Icons.check_rounded),
            label: Text(completed ? 'Desmarcar lado' : 'Completar lado'),
          ),
        ],
      ),
    );
  }
}
