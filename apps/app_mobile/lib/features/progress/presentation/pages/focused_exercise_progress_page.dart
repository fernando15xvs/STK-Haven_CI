import 'package:core/domain/models/exercise.dart';
import 'package:core/features/progress/presentation/pages/progress_intelligence_page.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_history_page.dart';

/// Uses the same analysis panel as Progreso > Ejercicios; no copied PR/chart
/// calculations. The route has a back button and cannot open itself via
/// 'Técnica', avoiding circular navigation from ExerciseDetailPage.
class FocusedExerciseProgressPage extends StatelessWidget {
  const FocusedExerciseProgressPage({
    super.key,
    required this.exercise,
  });

  final Exercise exercise;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            'Rendimiento · ${exercise.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headlineSmall,
          ),
        ),
        body: ProgressExercisesPanel(
          initialExerciseId: exercise.id,
          onOpenHistory: (item) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ExerciseHistoryPage(exercise: item),
            ),
          ),
        ),
      );
}
