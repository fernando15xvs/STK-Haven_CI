import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:flutter/material.dart';

/// Opens only the selected recent session; does not render all historical sets.
class RecentWorkoutDetails {
  const RecentWorkoutDetails._();

  static Future<void> show(
    BuildContext context,
    WorkoutSession session,
    WeightUnit unit,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              Text(
                session.routineNameSnapshot.isEmpty
                    ? 'Entrenamiento libre'
                    : session.routineNameSnapshot,
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                MaterialLocalizations.of(sheetContext)
                    .formatMediumDate(session.startedAt),
              ),
              Text('Duración: ${session.durationSeconds ~/ 60} min'),
              if (session.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(session.notes),
              ],
              const SizedBox(height: 16),
              for (final exercise in session.exercises)
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: session.exercises.length <= 2,
                    title: Text(exercise.exerciseNameSnapshot),
                    subtitle: Text(
                      '${exercise.sets.where((s) => s.completed).length} '
                      'de ${exercise.sets.length} series completadas',
                    ),
                    children: [
                      for (var index = 0; index < exercise.sets.length; index++)
                        ListTile(
                          dense: true,
                          title: Text(
                            '${exercise.sets[index].setType.label} ${index + 1}',
                          ),
                          subtitle: Text(
                            '${WeightConverter.formatWeight(exercise.sets[index].performanceWeight, unit)}'
                            ' · ${exercise.sets[index].performanceReps} reps'
                            '${exercise.sets[index].performanceRir == null ? '' : ' · RIR ${exercise.sets[index].performanceRir}'}'
                            '${exercise.sets[index].completed ? '' : ' · sin completar'}',
                          ),
                        ),
                      if (exercise.notes.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(exercise.notes),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
