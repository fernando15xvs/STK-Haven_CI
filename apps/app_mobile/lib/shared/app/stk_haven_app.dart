import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/mobile_content_frame.dart';
import '../../core/theme/app_theme.dart';
import '../../splash/splash_screen.dart';

/// Shared Flutter application shell for Android and iOS.
///
/// Platform-specific startup work lives in the dedicated Android/iOS
/// entrypoints; this widget only owns shared UI/lifecycle behavior.
class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(workoutTimerProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final performanceMode = ref.watch(
      settingsProvider.select((settings) => settings.performanceMode),
    );
    final reduceMotionSetting = ref.watch(
      settingsProvider.select((settings) => settings.reduceMotion),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final savings = performanceMode == PerformanceMode.savings;
        final reduceMotion =
            reduceMotionSetting || savings || media.disableAnimations;
        final content = child ?? const SizedBox.shrink();
        return MediaQuery(
          data: media.copyWith(disableAnimations: reduceMotion),
          child: MobileContentFrame(child: content),
        );
      },
      home: const SplashScreen(),
    );
  }
}
