import 'package:core/core/config/supabase_config.dart';
import 'package:core/database/hive/hive_database.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/layout/web_layout.dart';
import 'features/onboarding/presentation/onboarding_page_web.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  bool _bibleInitSchedulePending = false;
  bool _bibleInitStarted = false;

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
    final experienceProfile = ref.watch(userExperienceProfileProvider);
    _syncBibleInitialization(
      experienceProfile.value?.faithEnabled == true,
    );

    return MaterialApp(
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
