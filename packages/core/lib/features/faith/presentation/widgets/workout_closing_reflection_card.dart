import 'package:core/domain/models/verse.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
import 'package:core/features/faith/data/contextual_passage_catalog.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/application/workout_summary_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ClosingMoment { completed, returning, incomplete }

/// Classification refers to completed working sets and previous sessions, not
/// assumptions about the person's effort or motivation.
ClosingMoment classifyClosingMoment(
  WorkoutSummarySnapshot summary,
  WorkoutSession current,
  Iterable<WorkoutSession> history,
) {
  if (!summary.isComplete) return ClosingMoment.incomplete;
  final earlier = history.where((item) =>
      item.id != current.id && item.finishedAt.isBefore(current.startedAt)).toList()
    ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
  if (earlier.isNotEmpty &&
      current.startedAt.difference(earlier.first.finishedAt).inDays >= 14) {
    return ClosingMoment.returning;
  }
  return ClosingMoment.completed;
}

/// Rendered only after ending a session: never an exercise-time interruption.
class WorkoutClosingReflectionCard extends ConsumerStatefulWidget {
  final WorkoutSession session;
  final WorkoutSummarySnapshot summary;

  const WorkoutClosingReflectionCard({
    super.key,
    required this.session,
    required this.summary,
  });

  @override
  ConsumerState<WorkoutClosingReflectionCard> createState() =>
      _WorkoutClosingReflectionCardState();
}

class _WorkoutClosingReflectionCardState
    extends ConsumerState<WorkoutClosingReflectionCard> {
  Future<Verse?>? _verseFuture;
  bool _questionVisible = false;

  @override
  Widget build(BuildContext context) {
    final init = ref.watch(bibleInitProvider);
    if (!init.isReady) return const SizedBox.shrink();

    final moment = classifyClosingMoment(widget.summary, widget.session,
        ref.watch(workoutHistoryProvider));
    _verseFuture ??= ContextualPassageCatalog.workout(
      ref.read(bibleRepositoryProvider),
      sessionId: widget.session.id,
      theme: switch (moment) {
        ClosingMoment.completed => 'completed',
        ClosingMoment.returning => 'return',
        ClosingMoment.incomplete => 'incomplete',
      },
    );
    return FutureBuilder<Verse?>(
      future: _verseFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return snapshot.connectionState == ConnectionState.waiting
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                )
              : const SizedBox.shrink();
        }
        final verse = snapshot.data!;
        final title = switch (moment) {
          ClosingMoment.completed => 'Constancia y gratitud',
          ClosingMoment.returning => 'Un nuevo comienzo',
          ClosingMoment.incomplete => 'Lo que hiciste también cuenta',
        };
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Pasaje bíblico · Reina-Valera 1909',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                SelectableText('“${verse.text}”',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45)),
                const SizedBox(height: 6),
                Text(verse.reference,
                    style: Theme.of(context).textTheme.labelLarge),
                const Divider(height: 24),
                Text('Reflexión para este momento (no forma parte de la Biblia)',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Text(ContextualPassageCatalog.closingThoughtFor(verse)),
                if (verse.explanation?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text('Contexto: ${verse.explanation}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                if (verse.reflectionQuestion?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => setState(() => _questionVisible = !_questionVisible),
                    child: Text(_questionVisible ? 'Ocultar pregunta' : 'Una pregunta para reflexionar (opcional)'),
                  ),
                  if (_questionVisible)
                    Text(verse.reflectionQuestion!,
                        style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
