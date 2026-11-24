import 'package:flutter/material.dart';

/// Compose the user's appearance preference with the platform text scaler.
/// Do not approximate nonlinear accessibility scaling by a single ratio.
TextScaler combineAppTextScale(TextScaler platform, double userScale) {
  if (userScale == 1) return platform;
  return _AppTextScaler(platform, userScale);
}

class _AppTextScaler extends TextScaler {
  const _AppTextScaler(this.platform, this.userScale);

  final TextScaler platform;
  final double userScale;

  @override
  double scale(double fontSize) => platform.scale(fontSize) * userScale;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is _AppTextScaler &&
      other.platform == platform &&
      other.userScale == userScale;

  @override
  int get hashCode => Object.hash(platform, userScale);
}
