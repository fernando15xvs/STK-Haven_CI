import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_tracker/core/layout/mobile_content_frame.dart';

/// The image receives viewport constraints rather than its intrinsic size.
class ProfilePhotoViewer extends StatefulWidget {
  const ProfilePhotoViewer({super.key, required this.photo, this.heroTag});
  final ImageProvider<Object> photo;
  final Object? heroTag;
  @override
  State<ProfilePhotoViewer> createState() => _ProfilePhotoViewerState();
}

class _ProfilePhotoViewerState extends State<ProfilePhotoViewer> {
  final _transform = TransformationController();
  Offset _doubleTap = Offset.zero;
  Offset _dragStart = Offset.zero;
  Offset _dragDelta = Offset.zero;
  bool _singleFinger = false;
  bool _closing = false;

  bool get _atBaseScale => _transform.value.getMaxScaleOnAxis() <= 1.01;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  void _toggleZoom() {
    if (!_atBaseScale) {
      _transform.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(-_doubleTap.dx * (scale - 1), -_doubleTap.dy * (scale - 1), 0);
  }

  void _startDrag(ScaleStartDetails details) {
    _singleFinger = _atBaseScale && details.pointerCount == 1;
    _dragStart = details.focalPoint;
    _dragDelta = Offset.zero;
  }

  void _updateDrag(ScaleUpdateDetails details) {
    if (details.pointerCount != 1 || !_atBaseScale) _singleFinger = false;
    if (_singleFinger) _dragDelta = details.focalPoint - _dragStart;
  }

  void _endDrag(ScaleEndDetails details) {
    if (_singleFinger && _atBaseScale &&
        _dragDelta.dy > 90 && _dragDelta.dy > _dragDelta.dx.abs() * 1.5) {
      _close();
    }
    _singleFinger = false;
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: MobileSystemBars.style(Brightness.dark),
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        LayoutBuilder(builder: (context, constraints) {
          Widget image = Image(
            key: const ValueKey('profile_fullscreen_photo'),
            image: widget.photo,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
            ),
          );
          if (widget.heroTag != null) image = Hero(tag: widget.heroTag!, child: image);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (details) => _doubleTap = details.localPosition,
            onDoubleTap: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1, maxScale: 5,
              onInteractionStart: _startDrag,
              onInteractionUpdate: _updateDrag,
              onInteractionEnd: _endDrag,
              child: SizedBox(width: constraints.maxWidth, height: constraints.maxHeight, child: image),
            ),
          );
        }),
        Positioned(top: 0, left: 0, child: SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton(
            tooltip: 'Cerrar foto', onPressed: _close,
            style: IconButton.styleFrom(foregroundColor: Colors.white,
              backgroundColor: Colors.black54, minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.close),
          ),
        ))),
      ]),
    ),
  );
}
