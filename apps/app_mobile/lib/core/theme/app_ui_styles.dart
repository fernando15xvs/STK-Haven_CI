import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:core/domain/models/appearance_settings.dart';

/// Mobile-only geometry tokens; one tree of widgets for every visual style.
/// Accessibility tap targets remain at least 48 dp in every variant.
@immutable
class AppUiTokens extends ThemeExtension<AppUiTokens> {
  final double cardRadius;
  final double buttonRadius;
  final double inputRadius;
  final double cardPadding;
  final double sectionGap;
  final double pageHorizontalPadding;
  final double borderWidth;

  const AppUiTokens({
    required this.cardRadius,
    required this.buttonRadius,
    required this.inputRadius,
    required this.cardPadding,
    required this.sectionGap,
    required this.pageHorizontalPadding,
    required this.borderWidth,
  });

  factory AppUiTokens.from(AppUiStyle style) => switch (style) {
    AppUiStyle.classic => const AppUiTokens(
      cardRadius: 20, buttonRadius: 14, inputRadius: 14,
      cardPadding: 16, sectionGap: 24, pageHorizontalPadding: 16,
      borderWidth: 1,
    ),
    AppUiStyle.minimalist => const AppUiTokens(
      cardRadius: 12, buttonRadius: 12, inputRadius: 12,
      cardPadding: 18, sectionGap: 28, pageHorizontalPadding: 20,
      borderWidth: 0.8,
    ),
    AppUiStyle.compact => const AppUiTokens(
      cardRadius: 14, buttonRadius: 12, inputRadius: 10,
      cardPadding: 12, sectionGap: 16, pageHorizontalPadding: 12,
      borderWidth: 1,
    ),
  };

  static AppUiTokens of(BuildContext context) =>
      Theme.of(context).extension<AppUiTokens>() ??
      AppUiTokens.from(AppUiStyle.classic);

  @override
  AppUiTokens copyWith({
    double? cardRadius,
    double? buttonRadius,
    double? inputRadius,
    double? cardPadding,
    double? sectionGap,
    double? pageHorizontalPadding,
    double? borderWidth,
  }) => AppUiTokens(
    cardRadius: cardRadius ?? this.cardRadius,
    buttonRadius: buttonRadius ?? this.buttonRadius,
    inputRadius: inputRadius ?? this.inputRadius,
    cardPadding: cardPadding ?? this.cardPadding,
    sectionGap: sectionGap ?? this.sectionGap,
    pageHorizontalPadding: pageHorizontalPadding ?? this.pageHorizontalPadding,
    borderWidth: borderWidth ?? this.borderWidth,
  );

  @override
  AppUiTokens lerp(covariant AppUiTokens? other, double t) {
    if (other == null) return this;
    double mix(double first, double second) =>
        lerpDouble(first, second, t)!;
    return AppUiTokens(
      cardRadius: mix(cardRadius, other.cardRadius),
      buttonRadius: mix(buttonRadius, other.buttonRadius),
      inputRadius: mix(inputRadius, other.inputRadius),
      cardPadding: mix(cardPadding, other.cardPadding),
      sectionGap: mix(sectionGap, other.sectionGap),
      pageHorizontalPadding: mix(pageHorizontalPadding, other.pageHorizontalPadding),
      borderWidth: mix(borderWidth, other.borderWidth),
    );
  }
}
