import 'package:core/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Internal review surface. Receives a decoded candidate, never registers media
/// or bundles unapproved assets in the application.
class VisualPilotPreview extends StatefulWidget {
  const VisualPilotPreview({
    super.key,
    required this.composition,
    required this.exerciseName,
    this.progress,
  });

  final LottieComposition composition;
  final String exerciseName;
  // Explicit frame inspection overrides playback, including reduced motion.
  final double? progress;

  @override
  State<VisualPilotPreview> createState() => _VisualPilotPreviewState();
}

class _VisualPilotPreviewState extends State<VisualPilotPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.composition.duration,
  );
  bool _playing = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(VisualPilotPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.composition.duration;
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.progress != null || reduce || !_playing) {
      _controller.stop();
      if (widget.progress != null || reduce) {
        _controller.value = widget.progress?.clamp(0.0, 1.0) ?? .5;
      }
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final outline = dark ? const Color(0xFF9AA9BC) : const Color(0xFF263345);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${widget.exerciseName}. Candidato visual sin aprobar.',
          image: true,
          child: RepaintBoundary(
            key: const Key('pilot_canvas'),
            child: ColoredBox(
              color: palette.surface,
              child: Lottie(
                composition: widget.composition,
                controller: _controller,
                width: 512,
                height: 512,
                fit: BoxFit.contain,
                frameRate: FrameRate.composition,
                delegates: LottieDelegates(values: [
                  ValueDelegate.color(const ['**', 'color_kit'],
                      value: palette.primary),
                  ValueDelegate.color(const ['**', 'color_kitShade'],
                      value: Color.alphaBlend(
                          Colors.black.withValues(alpha: .25), palette.primary)),
                  ValueDelegate.color(const ['**', 'outline'], value: outline),
                  ValueDelegate.color(const ['**', 'color_floor'], value: outline),
                  ValueDelegate.color(const ['**', 'color_shorts'],
                      value: dark ? const Color(0xFF596B83) : const Color(0xFF263345)),
                  ValueDelegate.color(const ['**', 'color_hair'],
                      value: dark ? const Color(0xFF596B83) : const Color(0xFF25303E)),
                  ValueDelegate.color(const ['**', 'color_plate'],
                      value: dark ? const Color(0xFF596B83) : const Color(0xFF34445A)),
                ]),
              ),
            ),
          ),
        ),
        if (widget.progress == null && !MediaQuery.disableAnimationsOf(context))
          TextButton(
            key: const Key('pilot_playback'),
            onPressed: () => setState(() {
              _playing = !_playing;
              _sync();
            }),
            child: Text(_playing ? 'Pausar' : 'Reproducir'),
          ),
      ],
    );
  }
}
