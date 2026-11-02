import 'dart:math' as math;

/// Offline-only 3D camera controls for anatomical GLB authoring previews.
///
/// This is UI state, not part of a master GLB or the production exercise UI.
class GlbCameraPose {
  const GlbCameraPose({this.yaw=0,this.elevation=0,this.zoom=1});

  static const double minElevation=-.75;
  static const double maxElevation=.85;
  static const double minZoom=.65;
  static const double maxZoom=1.6;
  static const double radiansPerHorizontalPixel=.006;
  static const double radiansPerVerticalPixel=.004;

  final double yaw;
  final double elevation;
  /// Distance multiplier: smaller zoom values bring the camera closer.
  final double zoom;

  static double _wrap(double angle) {
    final revolution=2*math.pi;
    return ((angle+math.pi)%revolution+revolution)%revolution-math.pi;
  }

  GlbCameraPose drag(double deltaX,double deltaY) {
    if(!deltaX.isFinite||!deltaY.isFinite) {
      throw const FormatException('Non-finite camera gesture');
    }
    return GlbCameraPose(
      yaw:_wrap(yaw+deltaX*radiansPerHorizontalPixel),
      elevation:(elevation-deltaY*radiansPerVerticalPixel)
          .clamp(minElevation,maxElevation),
      zoom:zoom,
    );
  }

  GlbCameraPose scale(double scale,{required double initialZoom}) {
    if(!scale.isFinite||scale<=0||!initialZoom.isFinite||
        initialZoom<=0) {
      throw const FormatException('Invalid pinch zoom');
    }
    return GlbCameraPose(
      yaw:yaw,
      elevation:elevation,
      zoom:(initialZoom/scale).clamp(minZoom,maxZoom),
    );
  }

  GlbCameraPose zoomButton(bool closer) => GlbCameraPose(
    yaw:yaw,elevation:elevation,
    zoom:(zoom*(closer ? 0.85 : 1.15)).clamp(minZoom,maxZoom),
  );

  bool get isDefault=>yaw==0&&elevation==0&&zoom==1;
}
