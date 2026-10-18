import 'package:core/domain/models/exercise.dart';
import 'package:core/features/exercises/application/exercise_demonstration_library.dart';
import 'package:flutter/material.dart';

/// Shows only exercise-ID-specific verified media. A GIF for a similar but
/// different movement is never substituted. Works fully offline without media.
class ExerciseDemonstrationCard extends StatefulWidget {
  final Exercise exercise;
  final bool compact;
  final bool reduceMotion;

  const ExerciseDemonstrationCard({
    super.key,
    required this.exercise,
    this.compact = false,
    this.reduceMotion = false,
  });

  @override
  State<ExerciseDemonstrationCard> createState() =>
      _ExerciseDemonstrationCardState();
}

class _ExerciseDemonstrationCardState
    extends State<ExerciseDemonstrationCard> {
  bool _play = true;

  @override
  Widget build(BuildContext context) {
    final guide = ExerciseDemonstrationLibrary.guideFor(widget.exercise);
    final media = ExerciseDemonstrationLibrary.mediaFor(widget.exercise);
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        widget.reduceMotion;
    final showGif = media != null &&
        media.format == ExerciseMediaFormat.gif &&
        !reduceMotion &&
        _play;

    Widget placeholder(String message) => Container(
          key: const Key('exercise_media_fallback'),
          constraints: BoxConstraints(
            minHeight: widget.compact ? 124 : 160,
          ),
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fitness_center_outlined, size: 34),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        );

    final mediaWidget = media == null
        ? placeholder('Animación específica todavía no disponible. '
            'Consulta la guía técnica de este ejercicio.')
        : showGif || media.format == ExerciseMediaFormat.poster
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  media.assetPath,
                  key: const Key('exercise_verified_media'),
                  height: widget.compact ? 160 : 208,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => placeholder(
                    'El recurso no pudo abrirse. La guía técnica '
                    'sigue disponible sin conexión.',
                  ),
                ),
              )
            : placeholder(
                reduceMotion
                    ? 'Movimiento reducido: no se reproduce la animación.'
                    : 'Animación detenida. Activa Reproducir para verla.',
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'CÓMO REALIZAR EL EJERCICIO',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        mediaWidget,
        if (media != null) ...[
          const SizedBox(height: 6),
          Text(
            'Material: ${media.attribution}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (media.format == ExerciseMediaFormat.gif && !reduceMotion)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('exercise_toggle_animation'),
                onPressed: () => setState(() => _play = !_play),
                icon: Icon(_play ? Icons.pause_circle_outline :
                    Icons.play_circle_outline),
                label: Text(_play ? 'Pausar animación' : 'Reproducir animación'),
              ),
            ),
        ],
        const SizedBox(height: 14),
        if (guide != null) ...[
          _step(context, '1. Preparación', guide.setup),
          _step(context, '2. Ejecución', guide.movement),
          _step(context, '3. Evita estos errores', guide.safety),
        ] else if (widget.exercise.instructions.trim().isNotEmpty)
          _step(context, 'Instrucciones guardadas',
              widget.exercise.instructions.trim())
        else
          const Text('Todavía no hay una guía verificada de este ejercicio. '
              'No se asignará la técnica de otro movimiento.'),
        const SizedBox(height: 6),
        Text(
          'Guía general orientativa. Detén el movimiento si aparece dolor '
          'y ajusta el ejercicio a tu movilidad y experiencia.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _step(BuildContext context, String heading, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}
