import 'dart:async';

import 'package:core/core/config/storage_namespace.dart';
import 'package:core/core/config/supabase_config.dart';
import 'package:core/database/hive/hive_database.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/layout/web_layout.dart';
import 'core/navigation/web_browser_history_bridge.dart';
import 'core/notifications/web_platform_notification_service.dart';
import 'features/onboarding/presentation/onboarding_page_web.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StorageNamespace.configureSharedPreferences();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await HiveDatabase.init();

  runApp(
    const ProviderScope(
      child: WebApp(),
    ),
  );
}

class WebApp extends ConsumerStatefulWidget {
  const WebApp({super.key});

  @override
  ConsumerState<WebApp> createState() => _WebAppState();
}

class _WebAppState extends ConsumerState<WebApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final WebBrowserHistoryBridge _historyBridge = WebBrowserHistoryBridge();

  bool _bibleInitSchedulePending = false;
  bool _bibleInitStarted = false;

  @override
  void initState() {
    super.initState();
    _historyBridge.attach(_navigatorKey);
  }

  void _syncBibleInitialization(bool faithEnabled) {
    if (!faithEnabled ||
        _bibleInitStarted ||
        _bibleInitSchedulePending) {
      return;
    }

    _bibleInitSchedulePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bibleInitSchedulePending = false;
      if (!mounted || _bibleInitStarted) return;

      final stillEnabled =
          ref.read(userExperienceProfileProvider).value?.faithEnabled == true;
      if (!stillEnabled) return;

      _bibleInitStarted = true;
      ref.read(bibleInitProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    ref.listen(activeWorkoutProvider, (previous, next) {
      final naturallyFinishedRest =
          previous?.isResting == true &&
          previous!.restTimerSeconds <= 1 &&
          !next.isResting;
      if (naturallyFinishedRest && settings.timerSoundEnabled) {
        unawaited(WebPlatformNotificationService.playAlarmTone());
      }
    });
    final experienceProfile = ref.watch(userExperienceProfileProvider);
    _syncBibleInitialization(
      experienceProfile.value?.faithEnabled == true,
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: <NavigatorObserver>[_historyBridge],
      debugShowCheckedModeBanner: false,
      title: 'STK Haven',
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final savings = settings.performanceMode == PerformanceMode.savings;
        return MediaQuery(
          data: media.copyWith(
            disableAnimations:
                settings.reduceMotion || savings || media.disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: settings.hasCompletedOnboarding
          ? const WebLayout()
          : const WebOnboardingPage(),
    );
  }
}
