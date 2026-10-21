import 'package:core/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'rigged_anatomy_engine.dart';

/// Standalone INTERNAL mobile QA widget; never registered in exercise catalogue.
/// A procedural 3D articulated model, not the approved final anatomical sculpt.
class RiggedAnatomyPreview3d extends StatefulWidget {
  const RiggedAnatomyPreview3d({
    super.key,
    required this.exercise,
    this.progress,
    this.dimension = 360,
  });
  final Exercise3d exercise;
  final double? progress;
  final double dimension;
  @override
  State<RiggedAnatomyPreview3d> createState() => _RiggedAnatomyPreview3dState();
}
class _RiggedAnatomyPreview3dState extends State<RiggedAnatomyPreview3d>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));
  bool _playing = true;
  double _orbit = 0;
  @override
  void initState() {
    super.initState();
    _clock.repeat();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }
  @override
  void didUpdateWidget(covariant RiggedAnatomyPreview3d old) {
    super.didUpdateWidget(old);
    _sync();
  }
  void _sync() {
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (widget.progress != null || reduced || !_playing) {
      _clock.stop();
      if (widget.progress != null || reduced) {
        _clock.value = widget.progress?.clamp(0.0, 1.0) ?? .35;
      }
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }
  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        label: widget.exercise.title +
            '. Vista anatómica tridimensional experimental sin aprobar.',
        image: true,
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _orbit = (_orbit + details.delta.dx * .007).clamp(-.85, .85);
            });
          },
          child: RepaintBoundary(
            key: const Key('anatomical_3d_canvas'),
            child: SizedBox(
              width: widget.dimension,
              height: widget.dimension,
              child: AnimatedBuilder(animation: _clock, builder: (context, _) {
                return CustomPaint(
                  painter: MeshPainter3d(
                    exercise: widget.exercise,
                    progress: widget.progress ?? _clock.value,
                    accent: palette.primary,
                    background: palette.surface,
                    dark: dark,
                    orbit: _orbit,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      if (widget.progress == null && !MediaQuery.disableAnimationsOf(context))
        TextButton(
          key: const Key('anatomical_3d_play_pause'),
          onPressed: () {
            setState(() {
              _playing = !_playing;
              _sync();
            });
          },
          child: Text(_playing ? 'Pausar' : 'Reproducir'),
        ),
    ]);
  }
}
