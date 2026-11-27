import 'package:gym_tracker/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared native layout policy. Keep real platform insets available to routes;
/// never shrink the entire Navigator for the home indicator/navigation buttons.
class MobileContentFrame extends StatelessWidget {
  const MobileContentFrame({
    required this.child,
    super.key,
    this.maxWidth = 600,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: MobileSystemBars.style(Theme.of(context).brightness),
      child: ColoredBox(
        color: AppColors.of(context).background,
        child: Center(
          child: SafeArea(
            bottom: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// The four main tabs keep their existing reserved bottom region. Apply this
/// below the Navigator, not around it, so pushed routes retain real insets.
class PrimaryTabSafeArea extends StatelessWidget {
  const PrimaryTabSafeArea({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false, left: false, right: false, child: child,
  );
}

/// Scroll content may paint behind the system navigation area while its last
/// control can still scroll completely above it. Keyboard insets remain owned
/// by Scaffold; padding.bottom is zero when the keyboard covers the area.
abstract final class SecondaryScreenInsets {
  static EdgeInsets scrollPadding(BuildContext context, EdgeInsets base) =>
      base.copyWith(bottom: base.bottom + MediaQuery.paddingOf(context).bottom);
}

/// Android may add its native contrast scrim in three-button mode. Do not
/// disable that protection, hide controls or assume a fixed navigation height.
abstract final class MobileSystemBars {
  static SystemUiOverlayStyle style(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: true,
    );
  }
}
