import 'package:gym_tracker/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared native layout policy. Keep real platform insets available to routes;
/// never shrink the entire Navigator for the home indicator/navigation buttons.
class MobileContentFrame extends StatefulWidget {
  const MobileContentFrame({
    required this.child,
    super.key,
    this.maxWidth = 600,
  });

  final Widget child;
  final double maxWidth;

  /// Color the physical status area for a private media route without
  /// changing Navigator geometry or the safe areas of underlying tabs.
  static Future<T?> pushDarkMediaRoute<T>(BuildContext context, PageRoute<T> route) async {
    final frame = context.findAncestorStateOfType<_MobileContentFrameState>();
    final navigator = Navigator.of(context);
    frame?._beginDarkMedia();
    try {
      final result = await navigator.push<T>(route);
      await route.completed;
      return result;
    } finally {
      frame?._endDarkMedia();
    }
  }

  @override
  State<MobileContentFrame> createState() => _MobileContentFrameState();
}

class _MobileContentFrameState extends State<MobileContentFrame> {
  int _darkMediaDepth = 0;

  void _beginDarkMedia() {
    if (mounted) setState(() => _darkMediaDepth++);
  }

  void _endDarkMedia() {
    if (mounted && _darkMediaDepth > 0) setState(() => _darkMediaDepth--);
  }

  @override
  Widget build(BuildContext context) {
    final darkMedia = _darkMediaDepth > 0;
    final style = MobileSystemBars.style(Theme.of(context).brightness);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: ColoredBox(
        color: darkMedia ? Colors.black : AppColors.of(context).background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: SafeArea(
                bottom: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widget.maxWidth),
                  child: SizedBox(width: double.infinity, child: widget.child),
                ),
              ),
            ),
            if (darkMedia && MediaQuery.paddingOf(context).top > 0)
              Positioned(
                top: 0, left: 0, right: 0,
                height: MediaQuery.paddingOf(context).top,
                child: IgnorePointer(
                  child: AnnotatedRegion<SystemUiOverlayStyle>(
                    value: MobileSystemBars.style(Brightness.dark),
                    child: const ColoredBox(
                      key: ValueKey('mobile_dark_media_status_area'),
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
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
